# nix-config

One flake, two machines:

- **WSL** — NixOS (host `nixos`, user `marcus`). Repo at `~/nix-config`,
  symlinked to `/etc/nixos` (that path is what bare `nixos-rebuild` looks
  for — the symlink name is fixed, the repo location isn't).
- **MacBook Air** — nix-darwin on Determinate Nix (host `Marcuss-MacBook-Air`,
  user `marcussanchez`). Repo at `~/nix-config`, symlinked to
  `/etc/nix-darwin`, so bare `darwin-rebuild` finds it.

## Layout

```
flake.nix                  Inputs + both host wirings
hosts/
  wsl/default.nix          WSL host: hostname, stateVersion
  mac/default.nix          Mac host: hostname, platform, stateVersion
modules/common/            Shared system layer (options must exist on both platforms)
  packages.nix             Dev toolchains for every machine (go, rustup,
                           zig+zls, node, buf, python+uv, nix LSP, ...)
  claude-code.nix          Claude Code (claude-code-nix overlay)
modules/nixos/             WSL system layer (one concern per file)
  default.nix              Aggregator — imports ../common + everything below
  nix.nix                  Nix settings, GC, auto-upgrade
  packages.nix             Linux-only: build essentials the mac gets from Xcode CLT
  nix-ld.nix               Run unpatched dynamic binaries on NixOS
  users.nix                User accounts + login shell
  wsl.nix                  NixOS-WSL integration
  home-manager.nix         HM bridge → home/marcus/wsl.nix
modules/darwin/            Mac system layer
  default.nix              Aggregator — imports ../common + everything below
  nix.nix                  nix.enable = false — Determinate Nix owns the daemon
  homebrew.nix             Declarative brew: GUI casks + few formulae, cleanup=zap
  users.nix                marcussanchez + primaryUser
  macos.nix                macOS defaults; Touch ID for sudo
  fonts.nix                JetBrainsMono Nerd Font
  home-manager.nix         HM bridge → home/marcus/mac.nix
home/marcus/               Home Manager (per-user) modules
  default.nix              Shared core — imports the concern files below
  wsl.nix                  WSL entry: identity + toolchains.nix
  mac.nix                  Mac entry: identity + ghostty/nix.nix + rustup bootstrap
  packages.nix             Standalone user tools
  shell.nix                zsh + oh-my-zsh, zoxide, atuin, direnv, npm prefix
  neovim.nix               Neovim (stable); clones marcussanchez/neovim-config
                           to ~/.config/nvim on first activation, ff-only
                           pulls it on later ones when the tree is clean
                           (stays a normal mutable git checkout, not
                           nix-managed)
  git.nix                  Git identity + gh
  catppuccin.nix           Catppuccin Mocha theming
  ghostty.nix              [mac] Ghostty config (app itself is a brew cask)
  nix.nix                  [mac] user-level GC launchd agent
  toolchains.nix           [wsl] ~/.toolchains/go real-dir GOROOT copy for
                           Windows IDEs (\\wsl$ can't traverse symlinks);
                           rustup toolchain auto-repair on glibc bumps
templates/devshell/        Per-project dev shell scaffold (both platforms)
```

Two nixpkgs inputs on purpose: Linux rides `nixos-unstable`, the mac rides
`nixpkgs-unstable` (same trunk; darwin binary caches populate there first).
One `nix flake update` moves both machines.

## Common operations

```sh
# WSL                              # Mac
nh os switch                       nh darwin switch
nh os switch -u                    nh darwin switch -u
sudo nixos-rebuild switch          sudo darwin-rebuild switch

# Both
nix fmt                            # format all nix files
nix flake check                    # validate before switching
nix flake init -t /etc/nixos       # scaffold a project dev shell (mac: -t ~/nix-config)
```

On WSL, auto-upgrade rebuilds weekly from pushed main on GitHub (never the
local working tree, so uncommitted WIP can't get activated) and GC runs daily
(both timers catch up after downtime). The mac has no autoUpgrade — update
via `nh darwin switch -u`; user-level GC runs weekly as a launchd agent.
To see what a rebuild changed: the diff `nh` prints on either machine, or
`nvd diff /run/booted-system /run/current-system` on WSL /
`nvd diff $(ls -d1v /nix/var/nix/profiles/system-*-link | tail -2)` on the mac
(no booted-system there — nix-darwin doesn't own the boot).

Each machine can *evaluate* (not build) the other's config — do this after
touching shared files:

```sh
# from WSL:
nix eval --raw '/etc/nixos#darwinConfigurations."Marcuss-MacBook-Air".system.drvPath'
# from the mac:
nix eval --raw '/etc/nix-darwin#nixosConfigurations.nixos.config.system.build.toplevel.drvPath'
```

## Per-project dev shells

Project-specific tools belong in the project, not in this config. Scaffold
a dev shell in any repo:

```sh
nix flake init -t /etc/nixos   # drops flake.nix + .envrc (works on both machines)
direnv allow                   # opt in once; auto-loads on cd from then on
```

Add the project's tools to `packages` in its flake.nix; the shell loads on
`cd` in and unloads on `cd` out (`use flake` via direnv, cached by
nix-direnv). If a project needs real services (postgres, redis) running
per-project, reach for devenv.sh in that repo instead — same idea,
batteries included.

## Bootstrapping a new WSL machine

A fresh instance boots as the stock `nixos` user; the first rebuild creates
`marcus`, so there's one restart in the middle.

**On Windows** — download the latest `nixos.wsl` from
[NixOS-WSL releases](https://github.com/nix-community/NixOS-WSL/releases), then:

```powershell
# (pick a different --name if this PC already has a NixOS instance)
wsl --install --from-file nixos.wsl --name nixos
wsl -d nixos
```

**Inside, as the default `nixos` user:**

```sh
# The stock image has flakes disabled, so the first two commands pass the
# feature flags explicitly (an env var would be stripped by sudo). After
# the first switch the config enables flakes permanently.
sudo nix --extra-experimental-features 'nix-command flakes' run nixpkgs#git -- clone https://github.com/MarcusSanchez/nix-config.git /tmp/nixos-config
sudo nixos-rebuild switch --option experimental-features 'nix-command flakes' --flake /tmp/nixos-config#nixos

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
```

**First login as marcus** — the neovim config is already cloned to
`~/.config/nvim` by the Home Manager bootstrap, and rust installed itself
via the activation hook; what's left is per-machine state:

1. `gh auth login` (gh is the git credential helper — needed to push)
2. Open `nvim` once so lazy.nvim installs plugins from `lazy-lock.json`
3. `atuin login` if syncing shell history

## Bootstrapping a new Mac

```sh
# 1. Install Homebrew — it also installs the Xcode Command Line Tools,
#    which provide the git used below (a fresh Mac has neither). nix-darwin
#    drives brew declaratively but never installs it.
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install Determinate Nix (needs sudo) — then OPEN A NEW TERMINAL,
#    nix is not on PATH in the shell that ran the installer
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm

# 3. Clone the config
git clone https://github.com/MarcusSanchez/nix-config.git ~/nix-config

# 4. First activation (bootstraps darwin-rebuild itself; this is also where
#    brew installs everything declared in homebrew.nix)
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/nix-config

# 5. Symlink so bare `sudo darwin-rebuild switch` works — the analog of
#    the WSL machine keeping its config at /etc/nixos
sudo ln -s ~/nix-config /etc/nix-darwin
```

Determinate Nix owns the daemon, so nix-darwin runs with `nix.enable = false`;
daemon tweaks go in /etc/nix/nix.custom.conf. Then the same per-machine
state as WSL: `gh auth login`, open `nvim`, `atuin login`.

Leave `home.stateVersion` at `"25.05"` and darwin's `system.stateVersion`
at `6` even on newer installs — they are compatibility markers, not the
running version.

## Adding things

- A CLI tool for both machines → `modules/common/packages.nix` (or
  `home/marcus/packages.nix` if it's user-scoped)
- A Linux-only or mac-only system package → that platform's `packages.nix`
  (darwin currently has none — create the file if one appears)
- A GUI app on the mac → a cask in `modules/darwin/homebrew.nix`
  (`cleanup = "zap"`: anything not declared gets uninstalled)
- A new concern → new file in `modules/common/`, `modules/nixos/`, or
  `modules/darwin/` (common only if its options exist on both platforms),
  then add it to that directory's `default.nix` aggregator
- Shared user config → concern file in `home/marcus/` + import in
  `home/marcus/default.nix`; platform-only user config → import it from
  `wsl.nix` or `mac.nix` instead
