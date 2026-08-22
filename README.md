# nix-config

One flake, every machine. Each NixOS box resolves its own config **by
hostname** — `nixos-rebuild --flake /etc/nixos` with no `#attr` builds
`nixosConfigurations.<hostname>`, so the flake attribute and
`networking.hostName` have to stay equal.

| host | machine | user | repo symlinked to |
|---|---|---|---|
| `naut-box`, `framework-dt`, `office-one`, `office-two` | WSL, headless — one config, one instance per PC | `marcus` | `/etc/nixos` |
| `naut-dt` | bare-metal desktop, dual-boot beside the PC that hosts `naut-box` | `marcus` | `/etc/nixos` |
| `tuf-laptop` | bare-metal laptop, same desktop stack as `naut-dt` | `marcus` | `/etc/nixos` |
| `macbook-air` | nix-darwin, Determinate Nix | `marcussanchez` | `/etc/nix-darwin` |
| `mac-mini` | nix-darwin, Determinate Nix; trusted sops machine | `marcus` | `/etc/nix-darwin` |

The repo lives at `~/nix-config` everywhere; the symlink is what bare
`nixos-rebuild` / `darwin-rebuild` look for. Everything below is
bootstrapping — how a machine goes from nothing to a working member of
the fleet. Day-to-day reference lives in the file headers and CLAUDE.md.

## Bootstrapping a WSL machine

Every box installs identically, and the distro keeps its default Windows-side
name, `NixOS` — that name is only Windows' handle (`wsl -d`, `wsl -t`,
`\\wsl$\NixOS`) and NixOS never sees it. What decides what the box *becomes*
is the flake attribute on the first rebuild: the config sets the hostname
from it via `/etc/wsl.conf`. (Pass `--name` only if a PC ever hosts a second
distro — WSL refuses duplicates.)

Every WSL attribute yields the same box — the shared toolchains and
shell, a terminal into the fleet. Pick the attribute matching the PC
(any attribute in `flake.nix` works; a new PC means adding a line
there first).

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
# configuration.nix, which is unused once the flake is the source of truth.
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

**Prerequisite — Xcode Command Line Tools, verified BEFORE anything else.**
The first activation runs `brew bundle`, and bottles (gcc among them) refuse
to install without the CLT; that failure aborts activation halfway, *before*
Home Manager runs, which presents as "the switch worked but no dotfiles
appeared". `xcode-select --install` is the happy path — but on a fresh macOS
release it can report the software "is not currently available from the
update server". Two ways out of that: install the pending macOS point update
first (it refreshes the catalog; the CLT install works right after), or
download the CLT installer directly from developer.apple.com/download/all.
Done when `xcode-select -p` prints `/Library/Developer/CommandLineTools`.

Two blocks with a **mandatory new terminal between them** — that gap is the one
thing a paste-the-whole-section run gets wrong. Each block starts with
`setopt interactive_comments` because a fresh mac's zsh errors on pasted
`#` lines without it; with it, each block can be copied blindly.

```sh
setopt interactive_comments

# Install Homebrew (brew itself — nix-darwin drives it declaratively but
# never installs it)
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
setopt interactive_comments

# Which Mac this is — its entry in flake.nix (the one edit before pasting)
attr=mac-mini   # or macbook-air

# Clone the config — git comes via nix, so nothing needs preinstalling
nix run nixpkgs#git -- clone https://github.com/MarcusSanchez/nix-config.git ~/nix-config

# First activation (bootstraps darwin-rebuild itself; this is also where brew
# installs everything declared in homebrew.nix, so it's slow).
# The #attr is needed exactly once: bare resolution goes by LocalHostName,
# which Apple autogenerates on a fresh mac — this switch is what sets the
# hostname, and bare `sudo darwin-rebuild switch` works from then on.
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/nix-config#$attr

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

Same expected `cannot read keyfile` error as on WSL, and the same fix: for
an ordinary box, run [Placing the key](#placing-the-key); for a Mac joining
the trusted tier, follow
[Enrolling a trusted machine](#enrolling-a-trusted-machine) instead
(`age:place` refuses on trusted machines by design). Then
`nh darwin switch` again. After that the only thing left is opening `nvim`
once — `gh`, `flyctl` and `atuin` all come up authenticated.

## Secrets

Only the bootstrap-facing half lives here: how a new box gets its age
key. (Credentials are age-encrypted in `secrets/`, which is why the repo
can be public; sops-nix decrypts them into `/run/secrets/` at every
activation, and each tool is pointed at its file. Two tiers: every
machine opens `secrets.yaml` via a key; only the trusted machines' own
keys open `super.yaml`.)

> **The key must exist before the switch that installs secrets.** sops-nix
> treats a missing `/var/lib/sops-nix/key.txt` as fatal rather than falling
> back, so secret installation aborts with `cannot read keyfile`. That's the
> harmless error both bootstrap sections mention — on a fresh box, the switch
> that fails is the one that installs `rbw` so you can fetch the key at all.

### Placing the key

This is the whole of onboarding an ordinary/temporary machine — nothing to paste
into `.sops.yaml`, no `updatekeys`, no second machine involved. On a
trusted machine it refuses (placing the master would overwrite the
unbacked-up machine key). The repo's bin/ commands are on PATH
fleet-wide (modules/common/bin.nix), so as one command:

```sh
age:place    # logs into Bitwarden if needed (your master password),
             # fetches the key, places the machine copy AND the editing
             # copy, re-locks the vault (it holds the super recovery key —
             # an armed ordinary box must not be a bridge across the tiers),
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

### Enrolling a trusted machine

Trusted machines don't use `age:place` — each generates its own key and
becomes a named recipient. On the new machine:

```sh
age-keygen -o /tmp/machine.txt      # note the "Public key: age1..." line
sudo install -d -m 0700 /var/lib/sops-nix
sudo sh -c 'cat /tmp/machine.txt >> /var/lib/sops-nix/key.txt && chmod 0400 /var/lib/sops-nix/key.txt'
install -d -m 0700 ~/.config/sops/age
cat /tmp/machine.txt >> ~/.config/sops/age/keys.txt && chmod 600 ~/.config/sops/age/keys.txt
rm /tmp/machine.txt
```

Both copies matter: the root one is what activation decrypts with, the
user one is what `secrets:edit` reads — skip it and interactive sops
reports no key can open the file.

Then add the public key under `keys:` in `.sops.yaml` and to both creation
rules, add the hostname to the super gate's list in
`modules/common/secrets.nix` (gate and recipients must always match — a
host on the gate without a key aborts its whole secrets install), and
re-encrypt:

```sh
sops updatekeys secrets/secrets.yaml
sops updatekeys secrets/super.yaml   # must run where an EXISTING recipient
                                     # lives (the other trusted box, or the
                                     # buried key) — the new key can't open
                                     # the file it isn't yet a recipient of
```

Commit, push, switch.

## Tailscale on a new PC

Only relevant if that box will be a tailnet node. `hosts/wsl` imports
`modules/wsl/networking.nix`, so every WSL host is
one unless you drop the import. (The bare-metal hosts need none of this
section: the tailscale block in `modules/nixos/networking.nix` covers
them — bare metal is always its own node — and everything below about Windows
is WSL-specific. Enrolment is the same `sudo tailscale up` everywhere.)

**Windows: mirrored networking is preferred.** This is a Windows-side
file the repo can't manage, and it's per-PC rather than per-distro:

```powershell
@"
[wsl2]
networkingMode=mirrored
"@ | Set-Content $env:USERPROFILE\.wslconfig
wsl --shutdown
```

Order doesn't matter — before or after installing the distro, it just needs
the `wsl --shutdown` to take effect.

The MagicDNS fix in `modules/wsl/networking.nix` points resolved at `10.255.255.254`,
a resolver that only exists in mirrored mode — without it, DNS falls
back to `1.1.1.1`/`8.8.8.8`, so the internet works and LAN and tailnet
names quietly don't. (Current WSL gives NAT mode a healthy 1500 MTU too,
and NAT is what the office boxes run — but NAT changes where the
Windows host lives on the network; see the bridge unit in `modules/wsl/networking.nix`
for the consequence.)

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
`modules/wsl/networking.nix` import from its host module. Also don't run Tailscale on the
Windows side while a distro has it — the traffic gets encapsulated twice.
