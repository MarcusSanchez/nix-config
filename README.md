# nixos-config

Flake-based NixOS configuration for a single WSL machine (host `nixos`, user `marcus`).

The repo lives at `~/nixos-config`; `/etc/nixos` is a symlink to it, so both
`nixos-rebuild` and `system.autoUpgrade` find it without extra flags.

## Layout

```
flake.nix                  Inputs + host wiring
hosts/
  wsl/default.nix          Host-specific: hostname, stateVersion
modules/nixos/             System-level modules (one concern per file)
  default.nix              Aggregator — imports everything below
  nix.nix                  Nix settings, GC, auto-upgrade
  packages.nix             System dev toolchains (go, rust, zig+zls, node, ...)
  nix-ld.nix               Run unpatched dynamic binaries on NixOS
  users.nix                User accounts + login shell
  wsl.nix                  NixOS-WSL integration
  home-manager.nix         Bridges Home Manager; points at home/marcus
  claude-code.nix          Claude Code (claude-code-nix overlay)
home/marcus/               Home Manager (per-user) modules
  default.nix              Entry point — identity, stateVersion, imports
  packages.nix             Standalone user tools
  shell.nix                zsh + oh-my-zsh, zoxide, atuin
  neovim.nix               Neovim (stable); clones marcussanchez/neovim-config
                           to ~/.config/nvim on first activation (stays a
                           normal mutable git checkout, not nix-managed)
  git.nix                  Git identity + gh
  catppuccin.nix           Catppuccin Mocha theming
```

## Common operations

```sh
# Apply the configuration
sudo nixos-rebuild switch --flake /etc/nixos

# Update all inputs, then apply
nix flake update
sudo nixos-rebuild switch --flake /etc/nixos

# Format all nix files
nix fmt

# Sanity-check without switching
nix flake check
```

Auto-upgrade rebuilds this flake weekly against its lockfile; inputs only
move when you run `nix flake update`. Garbage collection runs daily and
keeps the last 10 days.

## Bootstrapping a new machine

A fresh instance boots as the stock `nixos` user; the first rebuild creates
`marcus`, so there's one restart in the middle.

**On Windows** — download the latest `nixos.wsl` from
[NixOS-WSL releases](https://github.com/nix-community/NixOS-WSL/releases), then:

```powershell
wsl --install --from-file nixos.wsl --name <instance-name>
wsl -d <instance-name>
```

**Inside, as the default `nixos` user:**

```sh
sudo nix run nixpkgs#git -- clone https://github.com/MarcusSanchez/nixos.git /tmp/nixos-config
sudo nixos-rebuild switch --flake /tmp/nixos-config#nixos

# Move the repo home and recreate the /etc/nixos symlink (not managed by
# the config; autoUpgrade depends on it)
sudo mv /tmp/nixos-config /home/marcus/nixos-config
sudo chown -R marcus:users /home/marcus/nixos-config
sudo ln -sfn /home/marcus/nixos-config /etc/nixos
exit
```

If the tarball predates flakes being enabled by default, prefix the rebuild
with `NIX_CONFIG="experimental-features = nix-command flakes"`.

**On Windows again:**

```powershell
wsl -t <instance-name>   # restart so wsl.defaultUser takes effect
wsl -d <instance-name>   # lands as marcus
```

**First login as marcus** — the neovim config is already cloned to
`~/.config/nvim` by the Home Manager bootstrap; what's left is per-machine
state:

1. `gh auth login` (gh is the git credential helper — needed to push)
2. Open `nvim` once so lazy.nvim installs plugins from `lazy-lock.json`
3. `atuin login` if syncing shell history

Leave both `stateVersion`s at `"25.05"` even on a newer install — they are
compatibility markers, not the running version.

## Adding things

- A system package → `modules/nixos/packages.nix`
- A user CLI tool → `home/marcus/packages.nix`
- A new concern (e.g. docker, postgres) → new file in `modules/nixos/`,
  then add it to `modules/nixos/default.nix`
- A second host → new directory under `hosts/`, new entry in `flake.nix`,
  reusing `modules/nixos` and picking per-host modules as needed
