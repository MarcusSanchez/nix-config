# nix-config

One flake, every machine. Each NixOS box resolves its own config **by
hostname** — `nixos-rebuild --flake /etc/nixos` with no `#attr` builds
`nixosConfigurations.<hostname>`, so the flake attribute and
`networking.hostName` have to stay equal.

| host | machine | user | repo symlinked to |
|---|---|---|---|
| `bedroom-wsl` | WSL, dev | `marcus` | `/etc/nixos` |
| `nixos-lite`, `office-lite-wsl-1`, `office-lite-wsl-2` | WSL, headless — one config, one instance per PC | `marcus` | `/etc/nixos` |
| `tuf-nixos` | bare-metal laptop — niri + DankMaterialShell | `marcus` | `/etc/nixos` |
| `bedroom-nixos` | bare-metal desktop, dual-boot with the PC hosting `bedroom-wsl` — prepared, not yet installed | `marcus` | `/etc/nixos` |
| `macbook-air` | nix-darwin, Determinate Nix | `marcussanchez` | `/etc/nix-darwin` |

The repo lives at `~/nix-config` everywhere; the symlink is what bare
`nixos-rebuild` / `darwin-rebuild` look for.

## Layout

```
home/
  marcus/                Home Manager — common/ + wsl/ + mac/ + desktop/,
                         with wsl.nix / wsl-lite.nix / mac.nix / desktop.nix
                         as entry points
hosts/                   per-host values only — mac/, wsl/, wsl-lite/, tuf/
                         (tuf also carries its hardware + nvidia facts)
modules/
  common/                shared system layer (all platforms)
  darwin/                mac system layer
  nixos/                 shared Linux core — every NixOS host
  wsl/                   WSL flavor (Windows integration, autoUpgrade)
  desktop/               bare-metal flavor (boot/niri/DMS session)
secrets/
  secrets.yaml           credentials, age-encrypted (safe to push)
.sops.yaml               which age keys can decrypt
bin/                     repo scripts: secrets:edit, secrets:status,
                         age:place, secrets:drop, config:check — on
                         PATH inside the repo after `direnv allow`
flake.nix                inputs + all host wirings
```

One concern per file, and a file does nothing until it's in its directory's
`default.nix`. Every file opens with a comment explaining itself.

## Common operations

**WSL**

```sh
nh os switch                  # apply
nh os switch -u               # apply + update inputs
nvd diff /run/booted-system /run/current-system
```

**TUF laptop**

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
| `nixos-lite`, `office-lite-wsl-*` | headless: same toolchains and shell, minus that sync. Any attribute in `flake.nix` works — add a line there first |

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

## Dual-boot install (bedroom PC → bedroom-nixos)

The host is prepared: `hosts/bedroom-nixos/` exists with the RTX 5080
nvidia config and a **placeholder** `hardware-configuration.nix` the
install replaces. Windows and `bedroom-wsl` are untouched throughout —
same machine, two flake hosts, only ever one running.

1. **Windows**: Disk Management → shrink `C:` by 1 TB (1,048,576 MB).
   Leave the freed space unallocated.
2. **Disable Secure Boot in the firmware first** — the NixOS ISO is
   unsigned and won't boot under it. (It gets re-enabled at the end, via
   lanzaboote — see "Enable Secure Boot" below. BitLocker is off on this
   machine today; if that ever changes, suspend it before any firmware
   Secure Boot change or Windows demands the recovery key.) Then boot
   the ISO from USB (firmware boot menu). Partition **only the freed
   space**: a 1 GiB FAT32 partition flagged `esp` — NixOS's own ESP,
   sized for early-KMS initrds; *never touch Windows' ~100 MB one* —
   and the rest ext4.
3. Mount root at `/mnt`, the new ESP at `/mnt/boot`, then:

```sh
sudo nixos-generate-config --root /mnt
git clone https://github.com/MarcusSanchez/nix-config /mnt/home/marcus/nix-config
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/home/marcus/nix-config/hosts/bedroom-nixos/hardware-configuration.nix
# if the ISO's release isn't 26.05, set system.stateVersion in
# hosts/bedroom-nixos/default.nix to match it — then:
sudo nixos-install --flake /mnt/home/marcus/nix-config#bedroom-nixos
# marcus has no password yet and the greeter needs one:
sudo nixos-enter --root /mnt -- passwd marcus
```

4. Reboot into the greeter (pick NixOS's disk in the firmware boot menu;
   Windows stays on its own entry). First login, in a terminal:

```sh
sudo chown -R marcus:users ~/nix-config
sudo ln -sfn /home/marcus/nix-config /etc/nixos
cd ~/nix-config && git add hosts/bedroom-nixos/hardware-configuration.nix
git commit -m "bedroom-nixos: real hardware-configuration from install"
```

5. Enroll the machine key ([Enrolling a trusted machine](#enrolling-a-trusted-machine)
   — push the commit above together with the `.sops.yaml` change), switch,
   `secrets:status`, `sudo tailscale up --ssh`. Push needs gh, which needs
   secrets — so the commit rides until enrollment lands; that's fine.

### First login (what to expect)

- **Boot noise before enrollment is normal**: every activation reports the
  harmless `setupSecrets` failure until the machine key is enrolled and a
  switch runs — same story as every fresh box.
- **Monitors auto-place in connector order**, probably not your desk
  order: `niri msg outputs` for the names, then add an
  `output "DP-N" { position …; scale …; }` block per monitor in
  `niri.config.kdl` (the convention is commented right above the laptop's
  `eDP-1` block). Edits hot-reload — arrange interactively, and the
  drift auto-commits on the next switch.
- `direnv allow ~/nix-config` once, so `bin/` is on PATH.
- Open `nvim` once (plugins install on first run).
- **Deliberately imperative, minutes of hand work** (same list as the
  laptop): JetBrains IDEs via Toolbox, DMS wallpaper/avatar from the
  control center, `sudo tailscale up --ssh`.
- atuin needs no ceremony here — a fresh store syncs the account history
  straight down on the hook's first login (the laptop's key-mismatch
  dance was a migration artifact, not part of the pattern).
- **Group memberships (input/uinput for xremap) need a relogin** after
  the first proper switch — log out and back in once before judging
  broken keybinds.

### Enable Secure Boot (after everything above works)

Windows wants Secure Boot back on; lanzaboote signs the NixOS boot chain
so both live under it. The host file is prepared but **deliberately not
imported** — enabled without keys, the bootloader install fails. In order:

```sh
sudo sbctl create-keys       # keys land in /var/lib/sbctl, root-only
# uncomment ./lanzaboote.nix in hosts/bedroom-nixos/default.nix, then:
nh os switch                 # generations get signed as they're installed
sudo sbctl verify            # everything on the ESP must show ✓ signed
# commit + push the uncomment
```

Reboot into the firmware and put Secure Boot into **Setup Mode**. This
board is MSI: `Del` to enter, `F7` for Advanced, then Settings →
Advanced → Windows OS Configuration → Secure Boot; set **Secure Boot
Mode = Custom**, enter **Key Management**, and delete *only* the **PK
(Platform Key)**. Do NOT use "Delete all Secure Boot variables" or
"Restore Factory Keys" — the first drops the revocation database (dbx),
the second re-enrols the vendor keys and takes you back out of Setup
Mode. Boot back into NixOS and confirm with `bootctl status`, which
should read `Secure Boot: disabled (setup)`:

```sh
sudo sbctl enroll-keys --microsoft
```

`--microsoft` is **load-bearing**: it keeps Microsoft's certificates
enrolled, which is what lets Windows *and* the GPU's option ROM keep
booting. Never enroll without it on this machine. Then reboot, switch
Secure Boot to enabled/enforcing, and verify from both sides:
`bootctl status` says `Secure Boot: enabled (user)`, and Windows still
boots from the firmware menu.

## Secrets

Credentials live age-encrypted in `secrets/secrets.yaml` (in this repo), which
is why the repo can be public. sops-nix decrypts them at every activation and
every boot into `/run/secrets/`, and each tool is pointed at its file — so no
machine ever runs `gh auth login`. Only the *values* are encrypted; the keys
stay readable, so a diff shows *that* a credential changed without showing it.

**Two tiers, four keys.** Lite boxes share the roaming master key from
Bitwarden; the trusted machines each have their own, and only those open
`super.yaml`:

| file | holds | who can decrypt |
|---|---|---|
| `secrets/secrets.yaml` | gh token (low-scope), croc, atuin | every machine |
| `secrets/super.yaml` | fly token + future hot ones | bedroom-wsl, macbook-air |

| key | lives | opens |
|---|---|---|
| master | Bitwarden + each lite box (`age:place`) | `secrets.yaml` |
| bedroom-wsl, macbook-air | only that machine (no backup, on purpose) | both files |
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
- **buried** — the paper printout is the disaster path: if both trusted
  machines die at once, it re-keys `super.yaml`. Nothing unreissuable may
  ever live in `super.yaml` (atuin's E2E key stays in the lower tier,
  reachable via Bitwarden, for exactly this reason).

**Leaking a key is the real risk** — git history is permanent, so a leaked
key decrypts every version ever committed of the files it's a recipient of,
including credentials since rotated. Revoking a recipient never un-exposes
what it already read; the only remediation that works is rotating the
credential at the provider. Re-encrypting achieves nothing.

## Tailscale on a new PC

Only relevant if that box will be a tailnet node. Both `hosts/wsl` and
`hosts/wsl-lite` import `modules/nixos/tailscale.nix`, so every WSL host is
one unless you drop the import.

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
