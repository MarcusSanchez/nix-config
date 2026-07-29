# nix-config

One flake, three machines:

- **WSL** — NixOS (host `nixos`, user `marcus`). The dev machine. Repo at
  `~/nix-config`, symlinked to `/etc/nixos` (that path is what bare
  `nixos-rebuild` looks for — the symlink name is fixed, the repo location
  isn't).
- **WSL lite** — NixOS (host `nixos-lite`, same user). A headless second
  instance: same toolchains, but none of the Windows integration (no Zed /
  IdeaVim syncing). For pulling a repo down on some other PC and poking at
  it from a terminal. Same repo layout, its own clone.
- **MacBook Air** — nix-darwin on Determinate Nix (host `Marcuss-MacBook-Air`,
  user `marcussanchez`). Repo at `~/nix-config`, symlinked to
  `/etc/nix-darwin`, so bare `darwin-rebuild` finds it.

Each NixOS box picks its own config **by hostname**: `nixos-rebuild --flake
/etc/nixos` with no `#attr` builds `nixosConfigurations.<hostname>`, so the
attribute name and `networking.hostName` must stay equal. (`system.autoUpgrade`
and `NH_FLAKE` resolve the same way — if the two ever drift, the weekly timer
fails quietly.) The Windows-side WSL distro name is a separate identifier: it's
what `wsl -d <name>` takes, and NixOS never sees it.

## Layout

```
flake.nix                  Inputs + every host wiring
.sops.yaml                 Which age keys can decrypt secrets/
secrets/secrets.yaml       Credentials, age-encrypted (safe to push)
hosts/
  wsl/default.nix          WSL dev host: hostname, home entry point, stateVersion
  wsl-lite/default.nix     WSL headless host: same, different home entry point
  mac/default.nix          Mac host: hostname, platform, stateVersion
modules/common/            Shared system layer (options must exist on both platforms)
  packages.nix             Dev toolchains for every machine (go, rustup,
                           zig+zls, node, python+uv, nix LSP, sops, ...)
  claude-code.nix          Claude Code (claude-code-nix overlay)
modules/nixos/             WSL system layer (one concern per file)
  default.nix              Aggregator — imports ../common + everything below;
                           both WSL hosts use it unchanged
  nix.nix                  Nix settings, GC, auto-upgrade
  packages.nix             Linux-only: build essentials the mac gets from
                           Xcode CLT, + ghostty terminfo for ssh sessions
  nix-ld.nix               Run unpatched dynamic binaries on NixOS
  ssh.nix                  sshd on loopback — mainly for the host key, which
                           is this machine's sops identity
  secrets.nix              sops-nix (system module): decrypts secrets/ with
                           the host key into /run/secrets
  keyring.nix              gnome-keyring as the Secret Service (secretspec)
  tailscale.nix            NOT in the aggregator — imported by hosts/wsl only,
                           since one WSL distro per PC can be a tailnet node
  users.nix                User accounts + login shell
  wsl.nix                  NixOS-WSL integration
  home-manager.nix         HM bridge → each host's homeEntryPoint
modules/darwin/            Mac system layer
  default.nix              Aggregator — imports ../common + everything below
  nix.nix                  nix.enable = false — Determinate Nix owns the daemon
  ssh.nix                  Remote Login + the WSL box's authorized key
  secrets.nix              sops-nix (darwin module): same as the NixOS one,
                           mac paths and username
  homebrew.nix             Declarative brew: GUI casks + few formulae, cleanup=zap
  users.nix                marcussanchez + primaryUser
  macos.nix                macOS defaults; Touch ID for sudo
  fonts.nix                JetBrainsMono Nerd Font
  home-manager.nix         HM bridge → home/marcus/mac.nix
home/marcus/               Home Manager (per-user), same shape as modules/
  wsl.nix                  WSL dev entry: identity + common/ + all of wsl/
  wsl-lite.nix             Headless entry: same minus the Windows dotfile
                           syncing (see the file for why)
  mac.nix                  Mac entry: identity + common/ + mac/ imports
  common/                  Shared concern files (default.nix aggregates)
    packages.nix           Standalone user tools
    shell.nix              zsh + oh-my-zsh, zoxide, atuin, direnv, npm prefix
    neovim.nix             Neovim (stable); clones marcussanchez/neovim-config
                           to ~/.config/nvim on first activation, ff-only
                           pulls it on later ones when the tree is clean
                           (stays a normal mutable git checkout, not
                           nix-managed)
    git.nix                Git identity + gh
    catppuccin.nix         Catppuccin Mocha theming
    comma.nix              comma + prebuilt nix-index database
    secrets.nix            user-side wiring for /run/secrets: FLY_API_TOKEN
                           export + atuin's one-time login
    bitwarden.nix          rbw — Bitwarden from the terminal; where the
                           personal (editing) age key is backed up
    goroot.nix             ~/.toolchains/go -> the store, a stable GOROOT
                           path for JetBrains to point at
    dotfiles/              shared UI-managed configs, one flat dir:
                           zed.settings.json + zed.keymap.json (keymap
                           carries cmd- and ctrl- variants) and
                           .ideavimrc. WSL syncs copies via win-sync,
                           the mac symlinks
  wsl/
    windows.nix            windows.username option — the Windows account
                           owning the distro, set per machine in wsl.nix
    nix.nix                NH_FLAKE for bare `nh os switch`
    toolchains.nix         rustup toolchain auto-repair on glibc bumps
    win-sync.nix           two-way sync engine for Windows-side configs:
                           UI edits pull into the repo and auto-commit
                           (chore:) + push, repo edits push to Windows,
                           both-changed warns and writes nothing
    dotfiles.nix           common/dotfiles/ ↔ Windows via win-sync: Zed
                           (%APPDATA%\Zed) and .ideavimrc (%USERPROFILE%)
  mac/
    ghostty.nix            Ghostty config (app itself is a brew cask)
    nix.nix                user-level GC launchd agent + NH_FLAKE
    toolchains.nix         rustup first-run bootstrap
    manual.nix             HM's own manpages off — they warn on every eval
    dotfiles.nix           per-file symlinks into common/dotfiles/:
                           ~/.config/zed/{settings,keymap}.json, ~/.ideavimrc
    auto-commit.nix        commits + pushes common/dotfiles drift on
                           activation
```

Two nixpkgs inputs on purpose: Linux rides `nixos-unstable`, the mac rides
`nixpkgs-unstable` (same trunk; darwin binary caches populate there first).
One `nix flake update` moves every machine.

## Common operations

```sh
# WSL                              # Mac
nh os switch                       nh darwin switch
nh os switch -u                    nh darwin switch -u
sudo nixos-rebuild switch          sudo darwin-rebuild switch

# Both
nix fmt                            # format all nix files
nix flake check                    # validate before switching
```

On both WSL boxes, auto-upgrade rebuilds weekly from pushed main on GitHub
(never the local working tree, so uncommitted WIP can't get activated; each
box resolves its own attribute by hostname) and GC runs daily (both timers
catch up after downtime). So a push to main deploys to two machines. The mac
has no autoUpgrade — update
via `nh darwin switch -u`; user-level GC runs weekly as a launchd agent.
To see what a rebuild changed: the diff `nh` prints on either machine, or
`nvd diff /run/booted-system /run/current-system` on WSL /
`nvd diff $(ls -d1v /nix/var/nix/profiles/system-*-link | tail -2)` on the mac
(no booted-system there — nix-darwin doesn't own the boot).

Each machine can *evaluate* (not build) the others' configs — do this after
touching shared files. `nix flake check` already covers every
`nixosConfigurations` entry, so on WSL only the mac needs the explicit eval:

```sh
# from WSL:
nix eval --raw '/etc/nixos#darwinConfigurations."Marcuss-MacBook-Air".system.drvPath'
# from the mac (one per NixOS host):
nix eval --raw '/etc/nix-darwin#nixosConfigurations.nixos.config.system.build.toplevel.drvPath'
nix eval --raw '/etc/nix-darwin#nixosConfigurations.nixos-lite.config.system.build.toplevel.drvPath'
```

## Per-project dev shells

Project-specific tools belong in the project, not in this config. Use
devenv (installed on both machines): `devenv init` in that repo, add
`packages`/`languages.*`/`services.*` in the generated devenv.nix, and
either enter manually with `devenv shell` or auto-load on cd via direnv
(`eval "$(devenv direnvrc)"` + `use devenv` in its .envrc — in-place
env, no subshell, silenced the same way direnv itself is). Plain flake
devShells work the same way (`use flake` in an .envrc, cached by
nix-direnv).

## Bootstrapping a WSL machine

Both WSL boxes install the same way — the only thing that differs is **one
name**, used in three places (the `--name` you give WSL, the `#attr` in the
first rebuild, and the hostname the config then sets, which is what makes bare
`nixos-rebuild` resolve afterwards). Pick it up front:

| name | what you get |
|---|---|
| `nixos` | the dev machine — everything, including the Zed/IdeaVim two-way sync with the Windows side |
| `nixos-lite` | headless: the same toolchains and shell, minus that sync (and the `windows.username` it needs) |

A fresh instance boots as the stock `nixos` user; the first rebuild creates
`marcus`, so there's one restart in the middle.

> **Nothing to pre-place, and one expected error.** This machine generates its
> own SSH host key and decrypts with that, so no key is copied here. Until its
> public key is registered, the rebuild below prints
> `Activation script snippet 'setupSecrets' failed` — harmless: activation
> records it and carries on, so packages install and the host key gets
> created. Register it afterwards per [Secrets](#secrets) and rebuild again.

**On Windows** — download the latest `nixos.wsl` from
[NixOS-WSL releases](https://github.com/nix-community/NixOS-WSL/releases), then
run one of these (WSL refuses a `--name` that already exists on this PC):

```powershell
# the dev machine
wsl --install --from-file nixos.wsl --name nixos
wsl -d nixos

# ...or the headless one
wsl --install --from-file nixos.wsl --name nixos-lite
wsl -d nixos-lite
```

**Inside, as the default `nixos` user:**

```sh
CFG=nixos   # or nixos-lite — must match the --name above

# The stock image has flakes disabled, so the first two commands pass the
# feature flags explicitly (an env var would be stripped by sudo). After
# the first switch the config enables flakes permanently.
sudo nix --extra-experimental-features 'nix-command flakes' run nixpkgs#git -- clone https://github.com/MarcusSanchez/nix-config.git /tmp/nixos-config
sudo nixos-rebuild switch --option experimental-features 'nix-command flakes' --flake /tmp/nixos-config#$CFG

# Move the repo home and recreate the /etc/nixos symlink (not managed by
# the config; bare `nixos-rebuild` depends on it)
sudo mv /tmp/nixos-config /home/marcus/nix-config
sudo chown -R marcus:users /home/marcus/nix-config
sudo ln -sfn /home/marcus/nix-config /etc/nixos
exit
```

**On Windows again:**

```powershell
wsl -t nixos   # restart so wsl.defaultUser takes effect
wsl -d nixos   # lands as marcus

# ...or the headless one
wsl -t nixos-lite
wsl -d nixos-lite
```

**First login as marcus** — the neovim config is already cloned to
`~/.config/nvim` by the Home Manager bootstrap; `hostname` should now print the
name you chose, so bare `nh os switch` resolves the right config with no
`#name`. What's left is per-machine state:

1. Open `nvim` once so lazy.nvim installs plugins from `lazy-lock.json`

`gh` and `atuin` are already authenticated — sops-nix put their
credentials in place during activation. The one exception is
`fly auth login`: what flyctl issues is a session macaroon that
re-discharges and is replaced when the session ends, so a stored copy
goes stale rather than staying useful.

Rust installs itself via the activation hook on either box. The only thing
`nixos-lite` lacks is the Windows dotfile syncing — by design, since it's
meant to run somewhere that has no JetBrains or Zed on the other side of
`/mnt/c`.

## Bootstrapping a new Mac

Two blocks with a **mandatory new terminal between them** — that gap is the
one thing a paste-the-whole-section run gets wrong. Each block on its own can
be copied blindly.

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

# First activation (bootstraps darwin-rebuild itself; this is also where
# brew installs everything declared in homebrew.nix, so it's slow)
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/nix-config

# Symlink so bare `sudo darwin-rebuild switch` works — the analog of the
# WSL machines keeping their config at /etc/nixos
sudo ln -s ~/nix-config /etc/nix-darwin

# Wire in the claude-code + devenv binary caches. Manual on the mac: daemon
# config is Determinate's, not nix-darwin's (the WSL boxes get this
# declaratively in modules/nixos/nix.nix). Keys are public.
printf 'extra-substituters = https://claude-code.cachix.org https://devenv.cachix.org\nextra-trusted-public-keys = claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk= devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=\n' | sudo tee -a /etc/nix/nix.custom.conf
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```

Then open one more terminal — that activation replaced your login shell, and
Home Manager's session variables only land in a shell started after it. Determinate
Nix owns the daemon, so nix-darwin runs with `nix.enable = false`; daemon
tweaks go in /etc/nix/nix.custom.conf.

Until this mac's host key is registered, step 3 prints
`Activation script snippet 'setupSecrets' failed` — harmless: activation
records it and carries on. macOS generates `/etc/ssh/ssh_host_ed25519_key`
itself, so there's nothing to create; register it per [Secrets](#secrets)
and switch again. After that the only thing left is opening `nvim` once —
`gh`, `flyctl` and `atuin` all come up authenticated.

Leave `home.stateVersion` at `"25.05"` and darwin's `system.stateVersion`
at `6` even on newer installs — they are compatibility markers, not the
running version.

## Secrets

Credentials live age-encrypted in `secrets/secrets.yaml` (in this repo), which
is why the repo can be public. sops-nix decrypts them at every activation and
every boot into `/run/secrets/`, and each tool is pointed at its file — so no
machine ever runs `gh auth login`. Only the *values* are encrypted; the keys
stay readable, so a diff shows *that* a credential changed without showing it.

**Every machine decrypts using its own SSH host key**
(`/etc/ssh/ssh_host_ed25519_key`, which is why `modules/nixos/ssh.nix` runs
sshd). No private key is ever copied between machines. Two files control this,
both at the root of this repo:

| file | what it is |
|---|---|
| `~/nix-config/.sops.yaml` | the list of keys allowed to decrypt |
| `~/nix-config/secrets/secrets.yaml` | the encrypted credentials |

### Editing a credential

From anywhere inside the repo, on a machine that can already decrypt:

```sh
sops ~/nix-config/secrets/secrets.yaml
```

It opens the decrypted file in `$EDITOR` and re-encrypts when you save. Commit
and push as normal.

### Adding a new machine

**Step 1 — on the NEW machine**, once it's been through the bootstrap above,
print its age public key. It's a *public* key: safe to paste anywhere.

```sh
sudo cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
# -> age1abc123...
```

**Step 2 — on a machine that ALREADY decrypts** (any existing one), edit
`~/nix-config/.sops.yaml`. The new key goes in **two** places — define it under
`keys:`, then reference it under `creation_rules:`:

```yaml
keys:
  - &marcus age17fldh0l...          # your personal editing key
  - &nixos age1dqh47zg...
  - &mac age1nux0jf7...
  - &lite age1abc123...             # <- 1. add here, pick any name

creation_rules:
  - path_regex: secrets/[^/]+\.yaml$
    key_groups:
      - age:
          - *marcus
          - *nixos
          - *mac
          - *lite                   # <- 2. and reference it here
```

**Step 3 — same machine**, re-encrypt so the new key can open the file, then
push:

```sh
cd ~/nix-config
sops updatekeys secrets/secrets.yaml
git add -A && git commit -m "secrets: add <machine>" && git push
```

**Step 4 — back on the new machine:**

```sh
cd ~/nix-config && git pull
sudo nixos-rebuild switch --flake /etc/nixos     # or: nh darwin switch
```

Done. `gh`, `flyctl` and `atuin` are all authenticated — atuin logs itself in
during activation, so nothing is typed.

### The personal key

`~/.config/sops/age/keys.txt` is the identity that lets *you* run `sops` to
edit secrets. Machines never need it — they use their host keys. It's backed
up in Bitwarden (`rbw get -f notes "sops age key - nix-config (all machines)"`).

Losing it is cheap: you can add a new personal key from any machine that still
decrypts. **Leaking it is not** — git history is permanent, so anyone with it
can decrypt every version ever committed. That means revoking at GitHub/fly,
not re-encrypting.

## Adding things

- A CLI tool for both machines → `modules/common/packages.nix` (or
  `home/marcus/common/packages.nix` if it's user-scoped)
- A Linux-only or mac-only system package → that platform's `packages.nix`
  (darwin currently has none — create the file if one appears). Anything in
  `modules/nixos/` lands on *both* WSL hosts; per-host differences live in
  the home entry points (`home/marcus/wsl.nix` vs `wsl-lite.nix`)
- A GUI app on the mac → a cask in `modules/darwin/homebrew.nix`
  (`cleanup = "zap"`: anything not declared gets uninstalled)
- A new concern → new file in `modules/common/`, `modules/nixos/`, or
  `modules/darwin/` (common only if its options exist on both platforms),
  then add it to that directory's `default.nix` aggregator
- Shared user config → concern file in `home/marcus/common/` + import in
  its `default.nix`; platform-only user config → file in `home/marcus/wsl/`
  or `home/marcus/mac/`, imported from the `wsl.nix` / `mac.nix` entry point
