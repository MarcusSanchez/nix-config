# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flake-based NixOS configuration for a single WSL machine (host `nixos`, user `marcus`). The repo lives at `~/nixos-config`; `/etc/nixos` is a symlink to it, which is what `nixos-rebuild` and `system.autoUpgrade` (weekly, against the lockfile) rely on.

## Commands

```sh
sudo nixos-rebuild switch --flake /etc/nixos   # apply config (passwordless sudo works here)
nix flake check                                # validate before switching — always do this after edits
nix fmt                                        # format all nix files (nixfmt-tree)
nix flake update                               # bump all inputs (autoUpgrade never does this)
```

There are no tests; `nix flake check` (evaluation) plus a successful switch is the verification story.

## Architecture

Three layers, wired together in `flake.nix` via flake-parts. Flake inputs are passed everywhere as `specialArgs`/`extraSpecialArgs`, so any module can take `inputs` as an argument.

1. `hosts/wsl/default.nix` — the only entry in `flake.nix`. Holds host-specific values (hostname, `system.stateVersion`) and imports layer 2.
2. `modules/nixos/` — system-level, one concern per file. `default.nix` is the aggregator: **a new module does nothing until added to its imports list.** `home-manager.nix` bridges to layer 3 (Home Manager as NixOS module, `backupFileExtension = "hm-backup"`).
3. `home/marcus/` — per-user Home Manager modules, imported by `home/marcus/default.nix`.

Where things go: system package → `modules/nixos/packages.nix`; user CLI tool → `home/marcus/packages.nix`; new concern (docker, postgres, ...) → new file in `modules/nixos/` + aggregator entry.

## Constraints that are easy to violate

- **Never manage `~/.config/nvim` through Nix, and never re-enable `programs.neovim`.** It is marcus's own LazyVim fork (github.com/marcussanchez/neovim-config), a normal mutable git checkout — lazy.nvim writes `lazy-lock.json` and marcus commits/pushes from there. `programs.neovim` generates its own `init.lua` and symlinks it over the checkout, silently breaking the whole editor (this happened once; the fix was deliberate). `home/marcus/neovim.nix` installs the stable nixpkgs binary via `home.packages` and clone-bootstraps the config only if `~/.config/nvim` doesn't exist. (Marcus prefers stable over nightly; a nightly-overlay setup existed before commit ~2026-07 if ever needed again.)
- **Zig and ZLS must stay on matching versions or editor tooling breaks.** Both come from nixpkgs (`pkgs.zig` / `pkgs.zls` in `packages.nix`), which builds zls against its own zig, so they stay in lockstep automatically — don't source one of them from somewhere else. If a just-released Zig is ever needed before nixpkgs catches up, the old two-input overlay approach (mitchellh/zig-overlay + zigtools/zls pinned ref) is in git history at `modules/nixos/zig.nix` before commit ~2026-07.
- **`system.stateVersion` and `home.stateVersion` (both "25.05") must never change** — they are not "the version we're on".
- The zsh `initContent` in `home/marcus/shell.nix` is wrapped in `lib.mkOrder 1200` on purpose, so marcus's keybindings land after zoxide/atuin's shell hooks. Don't drop the ordering when editing it.
