# nix-config

One flake, every machine. Each NixOS box resolves its own config **by
hostname** — `nixos-rebuild --flake /etc/nixos` with no `#attr` builds
`nixosConfigurations.<hostname>`, so the flake attribute and
`networking.hostName` have to stay equal.

| host | machine | user | repo symlinked to |
|---|---|---|---|
| `bedroom-wsl` | WSL, dev | `marcus` | `/etc/nixos` |
| `framework-wsl`, `office-lite-wsl-1`, `office-lite-wsl-2` | WSL, headless — one config, one instance per PC | `marcus` | `/etc/nixos` |
| `tuf-nixos` | bare-metal laptop — niri + DankMaterialShell | `marcus` | `/etc/nixos` |
| `bedroom-nixos` | bare-metal desktop, dual-boot beside the PC that hosts `bedroom-wsl` | `marcus` | `/etc/nixos` |
| `macbook-air` | nix-darwin, Determinate Nix | `marcussanchez` | `/etc/nix-darwin` |

The repo lives at `~/nix-config` everywhere; the symlink is what bare
`nixos-rebuild` / `darwin-rebuild` look for.

## Layout

```
home/
  marcus/                Home Manager — common/ + wsl/ + darwin/ + desktop/,
                         with wsl.nix / wsl-lite.nix / darwin.nix / desktop.nix
                         as entry points
hosts/                   per-host values only. Naming rule: hardware
                         truth => dir named by exact hostname
                         (tuf-nixos/, bedroom-nixos/ — hardware config,
                         nvidia facts, lanzaboote); no hardware truth =>
                         shareable kind (wsl/, wsl-lite/, darwin/ — several
                         flake attrs may point at one dir)
modules/
  common/                shared system layer (all platforms)
  darwin/                mac system layer
  nixos/                 shared Linux core — every NixOS host
  wsl/                   WSL flavor (Windows integration, autoUpgrade)
  desktop/               bare-metal flavor (boot/niri/DMS session)
secrets/
  secrets.yaml           lower-tier credentials, age-encrypted (safe to push)
  super.yaml             trusted-machines-only tier (see Secrets)
.sops.yaml               which age keys can decrypt
bin/                     repo scripts: secrets:edit, secrets:status,
                         age:place, secrets:drop, config:check — on
                         PATH inside the repo after `direnv allow`
flake.nix                inputs + all host wirings
```

One purpose per file (a purpose may span several related options — see
modules/desktop/peripherals.nix — but never becomes a grab-bag), and a
file does nothing until it's in its directory's `default.nix`. Every file opens with a comment explaining itself. Naming
across layers: `common` = all platforms; OS names for OS cores (`nixos`,
`darwin`); flavor names for flavors (`wsl`, `desktop`); machines by exact
hostname.

## Common operations

**WSL**

```sh
nh os switch                  # apply
nh os switch -u               # apply + update inputs
nvd diff /run/booted-system /run/current-system
```

**Bare metal (tuf-nixos, bedroom-nixos)**

```sh
nh os switch                  # same as WSL — but NO autoUpgrade here:
nh os switch -u               # a desktop updates when you mean it to
sudo nixos-rebuild boot --flake /etc/nixos
                              # for greeter/display-manager changes:
                              # stage for next boot instead of yanking
                              # the live session out from under you
```

**Mac**

```sh
nh darwin switch
nh darwin switch -u
nvd diff $(ls -d1v /nix/var/nix/profiles/system-*-link | tail -2)
```

**Both**

```sh
config:check                  # fmt + lint + evaluate every host (the CI gate)
nix flake update              # bump inputs by hand (CI does it Sundays)
```

Every WSL box rebuilds weekly from pushed main, so one push deploys to all
of them. The mac doesn't — update it with a pull + switch. CI bumps
`flake.lock` Sundays (only if the full eval gate passes), so those weekly
rebuilds actually carry new packages; `-u` is for bumping by hand.

## Bootstrapping a WSL machine

Every box installs identically, and the distro keeps its default Windows-side
name, `NixOS` — that name is only Windows' handle (`wsl -d`, `wsl -t`,
`\\wsl$\NixOS`) and NixOS never sees it. What decides what the box *becomes*
is the flake attribute on the first rebuild: the config sets the hostname
from it via `/etc/wsl.conf`. (Pass `--name` only if a PC ever hosts a second
distro — WSL refuses duplicates.)

| flake attribute | what you get |
|---|---|
| `bedroom-wsl` | the dev machine — everything, including the Zed/IdeaVim sync with the Windows side |
| `framework-wsl`, `office-lite-wsl-*` | headless: same toolchains and shell, minus that sync. Any attribute in `flake.nix` works — add a line there first |

A fresh instance boots as the stock `nixos` user and the first rebuild creates
`marcus`, which is why there's a restart in the middle.

> **One expected error.** The rebuild ends with
> `sops-install-secrets: cannot read keyfile '/var/lib/sops-nix/key.txt': no
> such file or directory`, then `Failed to run activate script` and a non-zero
> exit — because the age key isn't on this box yet. Harmless: activation
> carries on past it (you'll see it go on to reload user units), so everything
> else installs, including the `rbw` you'll use to fetch that key. You place it
> at the end of this section, then switch once more.
>
> Expect the same error again if you run `nh os switch` after the restart but
> before placing the key. Same cause, nothing new.

**On Windows** — download the latest `nixos.wsl` from
[NixOS-WSL releases](https://github.com/nix-community/NixOS-WSL/releases):

```powershell
wsl --install --from-file nixos.wsl
wsl -d NixOS
```

**Inside, as the default `nixos` user:**

```sh
HOSTNAME=<host-name>   # any attribute in flake.nix

# The stock image has flakes disabled, so these two pass the feature flags
# explicitly (an env var would be stripped by sudo). After the first switch
# the config enables flakes permanently.
sudo nix --extra-experimental-features 'nix-command flakes' run nixpkgs#git -- clone https://github.com/MarcusSanchez/nix-config.git /tmp/nixos-config
sudo nixos-rebuild switch --option experimental-features 'nix-command flakes' --flake /tmp/nixos-config#$HOSTNAME

# Move the repo home and replace /etc/nixos with a symlink to it (not managed
# by the config; bare `nixos-rebuild` depends on it).
# The rm matters: /etc/nixos is a real directory on a fresh image, and
# `ln -s` into an existing directory silently creates the link *inside* it
# (/etc/nixos/nix-config) instead of replacing it. All it holds is the stock
# configuration.nix, which is unused once we build from the flake.
sudo mv /tmp/nixos-config /home/marcus/nix-config
sudo chown -R marcus:users /home/marcus/nix-config
sudo rm -rf /etc/nixos
sudo ln -s /home/marcus/nix-config /etc/nixos
ls -ld /etc/nixos    # must print a symlink, not a directory
exit
```

**On Windows again.** This restart is mandatory, and it's what applies both
`wsl.defaultUser` *and* the hostname — WSL reads `/etc/wsl.conf` only at
distro startup, so until now this box still calls itself `nixos` (the stock
image's hostname). Don't run a bare `nh os switch` before it: with the old
hostname it would resolve `nixosConfigurations.nixos`, which does not exist,
or worse a config meant for another box.

```powershell
wsl -t NixOS
wsl -d NixOS        # lands as marcus
```

**First login as marcus.** Check `hostname` before anything else — it must
print the name you chose, since that's what makes bare `nh os switch` resolve
with no `#name`.

Nothing is authenticated yet — the first switch couldn't decrypt secrets, so
`gh`, `flyctl` and `atuin` are all still logged out. Do
[Placing the key](#placing-the-key) now; it ends with a second `nh os switch`,
after which they're all authenticated.

Then the last step: open `nvim` once so lazy.nvim installs plugins from
`lazy-lock.json` — the config itself is already cloned to `~/.config/nvim`.

## Bootstrapping a new Mac

Two blocks with a **mandatory new terminal between them** — that gap is the one
thing a paste-the-whole-section run gets wrong. Each block on its own can be
copied blindly.

```sh
# Install Homebrew — it also installs the Xcode Command Line Tools, which
# provide the git used below (a fresh Mac has neither). nix-darwin drives
# brew declaratively but never installs it.
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Determinate Nix (needs sudo)
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
```

> ### ⛔ Open a new terminal before continuing
>
> The installer puts `nix` on `PATH` through a shell profile, but *this* shell
> read its profile before that existed — so `nix` is still "command not found"
> here, and the next block dies on it. Quit the terminal and open a fresh one.

```sh
# Clone the config
git clone https://github.com/MarcusSanchez/nix-config.git ~/nix-config

# First activation (bootstraps darwin-rebuild itself; this is also where brew
# installs everything declared in homebrew.nix, so it's slow).
# The #macbook-air is needed exactly once: bare resolution goes by
# LocalHostName, which Apple autogenerates on a fresh mac — this switch is
# what sets it to macbook-air, and bare works from then on.
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/nix-config#macbook-air

# Symlink so bare `sudo darwin-rebuild switch` works — the analog of the WSL
# machines keeping their config at /etc/nixos
sudo ln -s ~/nix-config /etc/nix-darwin

# Wire in the claude-code + devenv binary caches. Manual on the mac: daemon
# config is Determinate's, not nix-darwin's. Keys are public.
printf 'extra-substituters = https://claude-code.cachix.org https://devenv.cachix.org\nextra-trusted-public-keys = claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk= devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=\n' | sudo tee -a /etc/nix/nix.custom.conf
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```

Then open **one more terminal** — that activation replaced your login shell, and
Home Manager's session variables only land in a shell started after it.

Same expected `cannot read keyfile` error as on WSL, and the same fix: run
[Placing the key](#placing-the-key) to place the age key, then
`nh darwin switch` again. After that the only thing left is opening `nvim`
once — `gh`, `flyctl` and `atuin` all come up authenticated.

## Dual-boot install (bedroom PC -> bedroom-nixos)

Same physical machine as `bedroom-wsl`, two flake hosts, only ever one
running. **This install happened 2026-08-06**; the section stays as the
reinstall runbook. A reinstall regenerates the committed
`hardware-configuration.nix` (and means new disk UUIDs — commit the
regenerated file, step 6), and `hosts/bedroom-nixos/lanzaboote.nix`
must be commented out of the host's imports until its keys exist again
(its header explains).

> **The mistake this runbook exists to prevent.** The first attempt let
> the installer choose `/boot`, and it picked **Windows' ~200 MiB ESP** —
> so NixOS wrote its bootloader inside Windows' boot partition, which then
> could not hold even two generations (each is ~130 MB with the early-KMS
> nvidia initrd). Symptom: "the ESP is too small". The cure is to create a
> **dedicated 1 GiB ESP** and to *verify what is mounted at `/mnt/boot`
> before installing*. Never let the graphical installer partition: it
> auto-selects the existing ESP and writes its own `configuration.nix`
> instead of using this flake.

**1. Windows side.** Shrink `C:` by 1 TB (1,048,576 MB); leave the freed
space unallocated. **Turn Secure Boot off** in the firmware — the ISO is
unsigned and won't boot under it. (BitLocker must be *off or suspended*
before any firmware Secure Boot change, or Windows demands its recovery
key on the next boot. Windows Hello PINs are TPM-sealed against Secure
Boot state too, and *will* need re-creating afterwards — sign in with the
account password, then Settings -> Accounts -> Sign-in options.)

**2. Boot the ISO** (firmware boot menu) and partition by hand. Do not
open the graphical installer.

```sh
lsblk -f                                   # identify the disk and the free space
sudo parted /dev/nvme0n1 unit MiB print free
```

Create **both** partitions in the freed region — a 1 GiB ESP and ext4 for
the rest. Substitute the real MiB offsets from `print free`:

```sh
sudo parted -s -a optimal /dev/nvme0n1 mkpart NIXBOOT fat32 <FREE_START>MiB <FREE_START+1024>MiB
sudo parted -s /dev/nvme0n1 set <N> esp on
sudo parted -s -a optimal /dev/nvme0n1 mkpart nixos ext4 <FREE_START+1024>MiB <FREE_END>MiB
sudo partprobe /dev/nvme0n1
sudo parted /dev/nvme0n1 unit MiB print free    # confirm: 1024MiB partition, esp flag
```

Fractional-scale arithmetic bites here too: if a partition ends on a
fractional boundary, round the next start *up* a MiB, or parted silently
places it somewhere else.

**3. Format and mount — then check before installing.**

```sh
sudo mkfs.vfat -F 32 -n NIXBOOT /dev/nvme0n1p<ESP>
sudo mkfs.ext4 -F -L nixos /dev/nvme0n1p<ROOT>
sudo mount /dev/nvme0n1p<ROOT> /mnt
sudo mkdir -p /mnt/boot && sudo mount /dev/nvme0n1p<ESP> /mnt/boot

findmnt -no SOURCE,SIZE /mnt/boot     # MUST be the ~1G partition, NOT the 200M one
ls /mnt/boot                          # MUST be empty — if it holds EFI/Microsoft,
                                      # you mounted Windows' ESP. Unmount and fix.
```

**4. Install.** `--no-root-passwd` matters: without it `nixos-install`
stops at an interactive prompt, which hangs an unattended/ssh run.

```sh
sudo nixos-generate-config --root /mnt
git clone https://github.com/MarcusSanchez/nix-config /mnt/home/marcus/nix-config
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/home/marcus/nix-config/hosts/bedroom-nixos/hardware-configuration.nix
grep -A3 'fileSystems."/boot"' \
   /mnt/home/marcus/nix-config/hosts/bedroom-nixos/hardware-configuration.nix
                                      # sanity: that UUID is the NEW ESP
sudo nixos-install --no-root-passwd --flake /mnt/home/marcus/nix-config#bedroom-nixos
sudo nixos-enter --root /mnt -- bash -c 'echo marcus:<password> | chpasswd'
```

**5. Enrol the machine key before first boot** — saves a round trip, and
means secrets work on the very first switch. Generate on the box (never
copy a key between machines), then add `&bedroom-nixos` to `.sops.yaml`
and `sops updatekeys` **from a machine that is already a recipient**
(tuf-nixos, bedroom-wsl or the mac), and push:

```sh
sudo nix-shell -p age --run "age-keygen -o /tmp/machine.txt"   # note the public key
sudo install -d -m 0700 /mnt/var/lib/sops-nix
sudo sh -c 'cat /tmp/machine.txt >> /mnt/var/lib/sops-nix/key.txt'
sudo chmod 0400 /mnt/var/lib/sops-nix/key.txt
sudo install -d -m 0700 /mnt/home/marcus/.config/sops/age
sudo sh -c 'cat /tmp/machine.txt >> /mnt/home/marcus/.config/sops/age/keys.txt'
sudo chmod 0600 /mnt/home/marcus/.config/sops/age/keys.txt
sudo chown -R 1000:100 /mnt/home/marcus          # uid 1000 is marcus on the target
sudo rm -f /tmp/machine.txt
```

**6. First boot.** `/etc/nixos` is a real directory on a fresh install, so
`ln -s` into it silently creates the link *inside* it — remove it first:

```sh
sudo rm -rf /etc/nixos && sudo ln -s /home/marcus/nix-config /etc/nixos
ls -ld /etc/nixos                     # must print a symlink
cd ~/nix-config && git add hosts/bedroom-nixos/hardware-configuration.nix
git commit -m "bedroom-nixos: real hardware-configuration from install"
git pull --rebase                     # picks up the .sops.yaml enrolment
sudo nixos-rebuild switch --flake /etc/nixos
secrets:status                        # gh / atuin / fly all green
sudo tailscale up --ssh
git push
```

Expect on first boot: monitors auto-place in connector order (`niri msg
outputs`, then add `output` blocks to `niri.outputs.kdl` — they
hot-reload, so arrange interactively), and **group changes (input/uinput
for xremap) need one relogin**. A brand-new hostname also needs its
`home/marcus/common/dotfiles/niri.host.<hostname>.kdl` committed BEFORE
the first switch, or Home Manager links the niri config against a file
that doesn't exist.

### Secure Boot

**The shipped arrangement, live since 2026-08-06: both OSes run under
Secure Boot at once.** lanzaboote signs systemd-boot and every NixOS
generation with keys generated on the machine; the firmware enforces
under this machine's own PK with Microsoft's certificates retained, so
Windows and the GPU's option ROM keep booting, anti-cheat (Fortnite,
Valorant) sees Secure Boot on, and **nothing ever gets toggled in the
BIOS** — the F11 boot menu picks the OS, that's the whole dual-boot
ceremony. `bootctl status` reads `Secure Boot: enabled (user)`, and an
unsigned USB stick is refused at the firmware level (verified by hand —
the FQ0001 quirk below is cosmetic once Deny Execute is set).

One-time Windows-side cost, already paid: changing Secure Boot state
re-breaks the Windows Hello PIN (TPM-sealed against PCR 7) — sign in
with the account password and re-create it under Settings -> Accounts ->
Sign-in options. If BitLocker is ever enabled, suspend it *before* any
future Secure Boot change or Windows demands the recovery key.

The ceremony below is the reinstall runbook. `lanzaboote.nix` must stay
**commented out** of the host imports until keys exist on the machine —
enabled without them, the bootloader install fails and takes
`nixos-install` with it.

```sh
sudo nix-shell -p sbctl --run "sbctl create-keys"   # sbctl ships WITH lanzaboote,
                                                    # hence nix-shell for this first step
# uncomment ./lanzaboote.nix in hosts/bedroom-nixos/default.nix
sudo nixos-rebuild switch --flake /etc/nixos
sudo sbctl verify        # generations + systemd-boot signed. The KERNEL showing
                         # "not signed" is EXPECTED: lanzaboote's signed stub
                         # carries its SHA-256 (.linuxh/.initrdh) instead of
                         # embedding it — verified by reading the PE sections
```

**Getting the keys enrolled — the MSI finding that took two nights.**
Deleting only the PK does NOT give real Setup Mode on this board: the
firmware reports `SetupMode=1` but keeps `db`/`KEK` Microsoft-owned and
immutable, so `sbctl enroll-keys` fails with `permission denied` no
matter what Linux-side knob is turned (lockdown, immutable flags,
landlock — all red herrings). The route that works:

1. Firmware (`Del`, `F7` for Advanced, Settings -> Advanced -> Windows
   OS Configuration -> Secure Boot): **Mode = Custom**, Key Management,
   **"Delete all Secure Boot variables"** — accepting that this **drops
   the dbx revocation database** (deliberate; restored in step 5). This
   is true Setup Mode: no key variables at all.
2. Boot NixOS and enrol at runtime — it just works from real Setup Mode:
   ```sh
   sudo sbctl enroll-keys --microsoft
   ```
   `--microsoft` is **load-bearing**: it keeps Microsoft's certificates
   enrolled, which is what lets Windows and the GPU's option ROM keep
   booting. Never enroll without it on this machine.
3. **Image Execution Policy -> Deny Execute** (Fixed *and* Removable
   Media) where the firmware offers it. `sbctl status` reports this
   board as `FQ0001: defaults to executing on Secure Boot policy
   violation (CRITICAL)` — MSI's default runs binaries that fail
   verification. On firmware revisions without the setting, verify
   enforcement empirically: an unsigned installer USB must be refused.
4. **Secure Boot = Enabled**, save. Verify in NixOS: `bootctl status`
   -> `Secure Boot: enabled (user)`. Verify Windows still boots (its
   certs are enrolled), and re-create the Hello PIN once.
5. Restore the dbx: `fwupdmgr update` and pick the "UEFI dbx" device
   (`services.fwupd` in the desktop flavor exists for this), or apply
   Microsoft's signed `dbxupdate_x64.bin` via `fwupdtool install-blob`
   if LVFS refuses to match an empty dbx.

Leave the TPM alone through all of this; clearing it destroys Windows
Hello and any TPM-sealed BitLocker protector.

<details>
<summary>Fallback: enrolling from the firmware's file browser</summary>

If runtime enrolment ever regresses, keys can be exported and enrolled
from the BIOS instead:

```sh
sudo mkdir -p /boot/sbctl-keys && cd /boot/sbctl-keys
sudo sbctl enroll-keys --microsoft --export esl    # also: --export auth
```

In Key Management, enrol **db -> KEK -> PK, in that order** (PK last:
enrolling it exits Setup Mode). Browse to the NixOS ESP ->
`sbctl-keys/` -> `db.esl` etc. Several volumes look identical in that
browser; the NixOS one contains `sbctl-keys`, Windows' has
`EFI/Microsoft`.

</details>

**If you abandon Secure Boot partway**, put the board back the way
Windows expects: Key Management -> **Restore Factory Keys**, then
Secure Boot -> Enabled. NixOS then won't boot until you disable it
again — that's a firmware toggle, nothing is damaged.

## Secrets

Credentials live age-encrypted in `secrets/secrets.yaml` (in this repo), which
is why the repo can be public. sops-nix decrypts them at every activation and
every boot into `/run/secrets/`, and each tool is pointed at its file — so no
machine ever runs `gh auth login`. Only the *values* are encrypted; the keys
stay readable, so a diff shows *that* a credential changed without showing it.

**Two tiers, six keys.** Lite boxes share the roaming master key from
Bitwarden; the four trusted machines each have their own, and only those
open `super.yaml`:

| file | holds | who can decrypt |
|---|---|---|
| `secrets/secrets.yaml` | gh token (low-scope), croc, atuin | every machine |
| `secrets/super.yaml` | fly token + future hot ones | bedroom-wsl, macbook-air, tuf-nixos, bedroom-nixos |

| key | lives | opens |
|---|---|---|
| master | Bitwarden + each lite box (`age:place`) | `secrets.yaml` |
| bedroom-wsl, macbook-air, tuf-nixos, bedroom-nixos | only that machine (no backup, on purpose) | both files |
| buried | paper in a drawer, never on a machine | both files (emergencies) |

On every machine the active identity sits at `/var/lib/sops-nix/key.txt`
(root, 0400) with an editing copy at `~/.config/sops/age/keys.txt`;
`.sops.yaml` says which key opens what (master first, by convention —
`age:place` verifies against it).

### Editing a credential

Inside the repo (`direnv allow` once per machine puts `bin/` on PATH
whenever you're cd'd in; `./bin/<name>` works without it):

```sh
secrets:edit          # the lower tier (secrets.yaml)
secrets:edit super    # super.yaml — only works on a trusted machine
```

It opens the decrypted file in `$EDITOR` and re-encrypts when you save. Commit
and push as normal.

### Placing the key (lite boxes)

This is the whole of onboarding a lite/temporary machine — nothing to paste
into `.sops.yaml`, no `updatekeys`, no second machine involved. On a
trusted machine it refuses (same capability probe as `secrets:drop` —
placing the master would overwrite the unbacked-up machine key). As one
command (after `direnv allow ~/nix-config`):

```sh
age:place    # logs into Bitwarden if needed (your master password),
             # fetches the key, places the machine copy AND the editing
             # copy, re-locks the vault (it holds the super recovery key —
             # an armed lite box must not be a bridge across the tiers),
             # verifies against .sops.yaml, and tells you the next step
```

If `age:place` can't find the vault item, its name has drifted —
`rbw list | grep -i sops` gives the current one.

To confirm it worked, check the tools rather than the directory — atuin logs
itself in during activation, so nothing is typed:

```sh
secrets:status    # gh auth status + atuin status + fly auth whoami,
                  # with the fly token read straight from /run/secrets
```

`ls /run/secrets/` is *denied by design* (mode `751`, so nothing can enumerate
what secrets exist) and looks like a failure when it isn't.

### Dropping the key

The inverse of `age:place`, for handing off or de-privileging a box:

```sh
secrets:drop    # removes both key copies, /run/secrets (which also holds
                # sops-nix's own key copy + the rendered gh file), and the
                # sessions that would outlive them: atuin (+ its synced
                # history db) and ~/.fly. rbw is only locked, not logged
                # out — the vault stays, gated by your master password
```

Close any shells that were already open (they still hold `FLY_API_TOKEN` /
`CROC_SECRET` in their environment), and remember the box is still on the
tailnet — `sudo tailscale logout` if it should lose that too. Switches keep
working; they just report the harmless `setupSecrets` failure until
`age:place` re-arms the machine.

Re-arming a **lite box** is `age:place` + a switch — everything it's
entitled to comes back during activation, and new shells pick the exports
back up on their own. On a **trusted machine** `secrets:drop` refuses to
run (it probes whether the box's key opens `super.yaml` — no hostname
list to drift): the machine key it would destroy has no backup, so a drop
there is decommissioning. Doing that for real is manual: delete both key
files, remove the machine's recipient from `.sops.yaml`, and `updatekeys`
both secrets files from a surviving recipient.

> **The key must exist before the switch that installs secrets.** sops-nix
> treats a missing `/var/lib/sops-nix/key.txt` as fatal rather than falling
> back, so secret installation aborts with `cannot read keyfile`. That's the
> harmless error both bootstrap sections mention — on a fresh box, the switch
> that fails is the one that installs `rbw` so you can fetch the key at all.

### Enrolling a trusted machine

Trusted machines don't use `age:place` — each generates its own key and
becomes a named recipient. On the new machine:

```sh
age-keygen -o /tmp/machine.txt      # note the "Public key: age1..." line
sudo sh -c 'cat /tmp/machine.txt >> /var/lib/sops-nix/key.txt && chmod 0400 /var/lib/sops-nix/key.txt'
cat /tmp/machine.txt >> ~/.config/sops/age/keys.txt && rm /tmp/machine.txt
```

Then add the public key under `keys:` in `.sops.yaml` and to both creation
rules, and re-encrypt:

```sh
sops updatekeys secrets/secrets.yaml
sops updatekeys secrets/super.yaml   # must run where an EXISTING recipient
                                     # lives (the other trusted box, or the
                                     # buried key) — the new key can't open
                                     # the file it isn't yet a recipient of
```

Commit, push, switch.

### The keys themselves

- **master** — Bitwarden:
  `rbw get -f notes "sops age key - nix-config (all machines)"`. Opens the
  lower tier only; a lite box (or its thief) can never read the fly token.
- **machine keys** — exist only on their machine, unbacked-up on purpose:
  compromising the Bitwarden vault does not open `super.yaml`.
- **buried** — the paper printout is the disaster path: if all four
  trusted machines die at once, it re-keys `super.yaml`. Nothing unreissuable may
  ever live in `super.yaml` (atuin's E2E key stays in the lower tier,
  reachable via Bitwarden, for exactly this reason).

**Leaking a key is the real risk** — git history is permanent, so a leaked
key decrypts every version ever committed of the files it's a recipient of,
including credentials since rotated. Revoking a recipient never un-exposes
what it already read; the only remediation that works is rotating the
credential at the provider. Re-encrypting achieves nothing.

## Tailscale on a new PC

Only relevant if that box will be a tailnet node. Both `hosts/wsl` and
`hosts/wsl-lite` import `modules/wsl/tailscale.nix`, so every WSL host is
one unless you drop the import. (The bare-metal hosts need none of this
section: `modules/desktop/tailscale.nix` rides the flavor aggregator —
bare metal is always its own node — and everything below about Windows
is WSL-specific. Enrolment is the same `sudo tailscale up` everywhere.)

**Windows needs mirrored networking.** This is a Windows-side file the repo
can't manage, and it's per-PC rather than per-distro:

```powershell
@"
[wsl2]
networkingMode=mirrored
"@ | Set-Content $env:USERPROFILE\.wslconfig
wsl --shutdown
```

Order doesn't matter — before or after installing the distro, it just needs
the `wsl --shutdown` to take effect.

Two things break without it. NAT mode's MTU is 1280, which breaks SSH and TLS
while leaving `ping` working, so it looks like everything is fine until
nothing you actually use works. And the MagicDNS fix in `tailscale.nix` points
resolved at `10.255.255.254`, a resolver that only exists in mirrored mode —
without it, DNS falls back to `1.1.1.1`/`8.8.8.8`, so the internet works and
LAN and tailnet names quietly don't.

**Then enrol the box**, which is interactive and stores nothing in the repo:

```sh
sudo tailscale up --ssh
```

**The mac needs only this step.** Everything Windows-side above is
WSL-specific; on a fresh mac the daemon, its launchd job, and the
/etc/resolver/ts.net split-DNS hook all land with the first switch, and the
activation hook re-asserts `--ssh` on every rebuild. No reboot either — that
was only ever needed when migrating off the GUI app, whose network extension
lingers until restart.

**One node per PC.** Two WSL distros on one machine share a network namespace,
so two `tailscaled` would fight over `tailscale0`, UDP 41641 and the
`100.64.0.0/10` route. If a PC ever hosts two, the second one drops the
`tailscale.nix` import from its host module. Also don't run Tailscale on the
Windows side while a distro has it — the traffic gets encapsulated twice.
