# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flake-based Nix configuration for two machines: a WSL NixOS box (host `nixos`, user `marcus`) and a MacBook Air on nix-darwin + Determinate Nix (host `Marcuss-MacBook-Air`, user `marcussanchez`). On both machines the repo lives at `~/nix-config`; on WSL `/etc/nixos` is symlinked to it (what bare `nixos-rebuild` relies on), on the mac `/etc/nix-darwin` is. The GitHub repo is `MarcusSanchez/nix-config`; the weekly `system.autoUpgrade` on WSL builds from pushed main there, never from the working tree.

Claude Code sessions run on either machine (`uname` disambiguates). Each machine can build and activate only its own platform; the *other* platform's config can still be fully evaluated — do that after touching shared files, and flag cross-platform changes for marcus to activate on the other machine.

## Commands

```sh
# WSL only
sudo nixos-rebuild switch --flake /etc/nixos   # apply (passwordless sudo works)
nix eval --raw '/etc/nixos#darwinConfigurations."Marcuss-MacBook-Air".system.drvPath'
                                               # eval the mac system after touching darwin/ or home/

# Mac only
sudo darwin-rebuild switch                     # apply — sudo pops a Touch ID prompt that works
                                               # even from Claude's non-interactive shell; marcus
                                               # approves it by fingerprint
nix eval --raw '/etc/nix-darwin#nixosConfigurations.nixos.config.system.build.toplevel.drvPath'
                                               # eval the WSL system after touching nixos/ or home/

# Both
nix flake check                                # validate before switching — always do this after edits
nix fmt                                        # format all nix files (nixfmt-tree)
nix flake update                               # bump all inputs (autoUpgrade never does this)
```

There are no tests; `nix flake check` + the darwin eval + a successful switch is the verification story.

## Architecture

Three layers per platform, wired in `flake.nix`. Flake inputs are passed everywhere as `specialArgs`/`extraSpecialArgs`, so any module can take `inputs` as an argument. Two nixpkgs inputs on purpose: `nixpkgs` (nixos-unstable, Linux) and `nixpkgs-darwin` (nixpkgs-unstable, where darwin caches populate first) — don't collapse them.

1. `hosts/wsl/` and `hosts/mac/` — the entries in `flake.nix`. Host-specific values only (hostname, platform, `system.stateVersion`).
2. `modules/common/` (shared — only options that exist on both platforms), `modules/nixos/`, and `modules/darwin/` — system layer, one concern per file. Each platform aggregator imports `../common` plus its own files: **a new module does nothing until added to an imports list.** Each platform's `home-manager.nix` bridges to layer 3 (`backupFileExtension = "hm-backup"`).
3. `home/marcus/` — Home Manager. `default.nix` is the shared core; `wsl.nix` and `mac.nix` are the per-host entry points (identity + platform-only imports). The bridges import the entry points, never `default.nix` directly.

Where things go: CLI tool for both machines → `modules/common/packages.nix`, or `home/marcus/packages.nix` if user-scoped; Linux-only build tools → `modules/nixos/packages.nix`; mac GUI app → cask in `modules/darwin/homebrew.nix`; new concern → new file + aggregator entry in `common/` (both platforms) or the platform dir; shared user config → concern file imported from `home/marcus/default.nix`; platform-only user config → imported from `wsl.nix` or `mac.nix`.

## Constraints that are easy to violate

- **Never manage `~/.config/nvim` through Nix, and never re-enable `programs.neovim`.** It is marcus's own LazyVim fork (github.com/marcussanchez/neovim-config), a normal mutable git checkout — lazy.nvim writes `lazy-lock.json` and marcus commits/pushes from there. `programs.neovim` generates its own `init.lua` and symlinks it over the checkout, silently breaking the whole editor (this happened once; the fix was deliberate). `home/marcus/neovim.nix` installs the stable nixpkgs binary via `home.packages`, clone-bootstraps the config if `~/.config/nvim` doesn't exist, and otherwise ff-only pulls it during activation (only when the tree is clean — never touch that safety check). (Marcus prefers stable over nightly; a nightly-overlay setup existed before commit ~2026-07 if ever needed again.)
- **Zig and ZLS must stay on matching versions or editor tooling breaks.** Both come from nixpkgs (`pkgs.zig` / `pkgs.zls` in `modules/common/packages.nix`), which builds zls against its own zig, so they stay in lockstep automatically — don't source one of them from somewhere else. If a just-released Zig is ever needed before nixpkgs catches up, the old two-input overlay approach (mitchellh/zig-overlay + zigtools/zls pinned ref) is in git history at `modules/nixos/zig.nix` before commit ~2026-07.
- **Rust must come via rustup, not nixpkgs rustc/cargo — RustRover refuses standalone toolchains.** (Tried the nixpkgs route once, 2026-07, had to revert.) On WSL, rustup's downloaded binaries are patched against one specific store glibc and die with ENOENT after a glibc bump + GC; the activation hook in `home/marcus/toolchains.nix` reinstalls stable whenever glibc changes. On the mac there is no glibc problem — `home/marcus/mac.nix` has only a first-run bootstrap. JetBrains (running on Windows, browsing over `\\wsl$`) pins the `~/.toolchains/*` directories from `toolchains.nix` — these must stay *real dereferenced copies*, not symlinks, because the Windows file picker cannot traverse Linux symlinks.
- **On the mac, `nix.enable = false` is load-bearing** — Determinate Nix owns the daemon and nix-darwin refuses to build otherwise. Never set system-side `nix.settings`/`nix.gc`/`nix.optimise` in `modules/darwin/`; user-level GC lives in `home/marcus/nix.nix` (mac-only import) instead.
- **`homebrew.nix` has `cleanup = "zap"`**: any formula/cask/tap not declared there is uninstalled on the next mac rebuild. When marcus mentions installing a mac app, it must be declared or it will vanish.
- **The usernames differ per machine** — `marcus` on WSL, `marcussanchez` on the mac. The HM bridges and `users.nix` files encode this; don't "unify" them.
- **`home.stateVersion` ("25.05") and both `system.stateVersion`s ("25.05" on WSL, `6` on darwin) must never change** — they are not "the version we're on".
- The zsh `initContent` in `home/marcus/shell.nix` is wrapped in `lib.mkOrder 1200` on purpose, so marcus's keybindings land after zoxide/atuin's shell hooks. Don't drop the ordering when editing it.
