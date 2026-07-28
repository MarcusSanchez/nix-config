# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flake-based Nix configuration for three machines: a WSL NixOS dev box (host `nixos`, user `marcus`), a second headless WSL instance (host `nixos-lite`, same user — same toolchains, no Windows integration; meant for pulling a repo down on some other PC and working from a terminal), and a MacBook Air on nix-darwin + Determinate Nix (host `Marcuss-MacBook-Air`, user `marcussanchez`). On every machine the repo lives at `~/nix-config`; on WSL `/etc/nixos` is symlinked to it (what bare `nixos-rebuild` relies on), on the mac `/etc/nix-darwin` is. The GitHub repo is `MarcusSanchez/nix-config`; the weekly `system.autoUpgrade` on both WSL boxes builds from pushed main there, never from the working tree — so one push deploys to two machines.

**Each NixOS host resolves its config by hostname**: `nixos-rebuild --flake /etc/nixos` with no `#attr` builds `nixosConfigurations.<hostname>`, as do `system.autoUpgrade` and `NH_FLAKE`. The flake attribute and `networking.hostName` must therefore stay equal, or those fail quietly. The Windows-side WSL distro name (`wsl -d <name>`) is a separate identifier NixOS never sees.

Claude Code sessions run on any of them — `uname` separates darwin from Linux, `hostname` separates the two WSL boxes (`uname` alone cannot). Each machine can build and activate only its own platform; the *other* platform's config can still be fully evaluated — do that after touching shared files, and flag cross-platform changes for marcus to activate on the other machine.

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
nix eval --raw '/etc/nix-darwin#nixosConfigurations.nixos-lite.config.system.build.toplevel.drvPath'
                                               # eval the WSL systems after touching nixos/ or home/
                                               # (on WSL, `nix flake check` already covers both)

# Both
nix flake check                                # validate before switching — always do this after edits
nix fmt                                        # format all nix files (nixfmt-tree)
nix flake update                               # bump all inputs (autoUpgrade never does this)
```

There are no tests; `nix flake check` (which evaluates every `nixosConfigurations` entry, both WSL hosts included) + the darwin eval + a successful switch is the verification story.

## Architecture

Three layers per platform, wired in `flake.nix`. Flake inputs are passed everywhere as `specialArgs`/`extraSpecialArgs`, so any module can take `inputs` as an argument. Two nixpkgs inputs on purpose: `nixpkgs` (nixos-unstable, Linux) and `nixpkgs-darwin` (nixpkgs-unstable, where darwin caches populate first) — don't collapse them.

1. `hosts/wsl/`, `hosts/wsl-lite/`, and `hosts/mac/` — the entries in `flake.nix`. Host-specific values only (hostname, platform, `system.stateVersion`, and on the NixOS hosts `homeEntryPoint` — the option `modules/nixos/home-manager.nix` reads to decide which home config this host's marcus gets).
2. `modules/common/` (shared — only options that exist on both platforms), `modules/nixos/`, and `modules/darwin/` — system layer, one concern per file. Each platform aggregator imports `../common` plus its own files: **a new module does nothing until added to an imports list.** Both WSL hosts import `modules/nixos` unchanged — the two boxes differ only in hostname and `homeEntryPoint`, because what separates them lives in the home layer. Each platform's `home-manager.nix` bridges to layer 3 (`backupFileExtension = "hm-backup"`).
3. `home/marcus/` — Home Manager, mirroring the system layer's shape: `common/` (shared concern files, aggregated by its `default.nix`), `wsl/` and `mac/` (platform-only concern files), and `wsl.nix` / `wsl-lite.nix` / `mac.nix` as the per-host entry points (identity + `./common` + whichever platform files that host wants). `wsl-lite.nix` is `wsl.nix` minus `windows.nix` + `dotfiles.nix` — **that omission is the whole difference between the two WSL boxes**; read its header before adding either back. The bridges import the entry points, never `common/` directly.

Where things go: CLI tool for every machine → `modules/common/packages.nix`, or `home/marcus/packages.nix` if user-scoped; Linux-only build tools → `modules/nixos/packages.nix` (note: everything in `modules/nixos/` lands on *both* WSL hosts); mac GUI app → cask in `modules/darwin/homebrew.nix`; new concern → new file + aggregator entry in `common/` (both platforms) or the platform dir; shared user config → concern file in `home/marcus/common/` + import in its `default.nix`; platform-only user config → file in `home/marcus/wsl/` or `home/marcus/mac/`, imported from the relevant entry point.

## Constraints that are easy to violate

- **Never manage `~/.config/nvim` through Nix, and never re-enable `programs.neovim`.** It is marcus's own LazyVim fork (github.com/marcussanchez/neovim-config), a normal mutable git checkout — lazy.nvim writes `lazy-lock.json` and marcus commits/pushes from there. `programs.neovim` generates its own `init.lua` and symlinks it over the checkout, silently breaking the whole editor (this happened once; the fix was deliberate). `home/marcus/common/neovim.nix` installs the stable nixpkgs binary via `home.packages`, clone-bootstraps the config if `~/.config/nvim` doesn't exist, and otherwise ff-only pulls it during activation (only when the tree is clean — never touch that safety check). (Marcus prefers stable over nightly; a nightly-overlay setup existed before commit ~2026-07 if ever needed again.)
- **Zig and ZLS must stay on matching versions or editor tooling breaks.** Both come from nixpkgs (`pkgs.zig` / `pkgs.zls` in `modules/common/packages.nix`), which builds zls against its own zig, so they stay in lockstep automatically — don't source one of them from somewhere else. If a just-released Zig is ever needed before nixpkgs catches up, the old two-input overlay approach (mitchellh/zig-overlay + zigtools/zls pinned ref) is in git history at `modules/nixos/zig.nix` before commit ~2026-07.
- **Rust must come via rustup, not nixpkgs rustc/cargo — RustRover refuses standalone toolchains.** (Tried the nixpkgs route once, 2026-07, had to revert.) On WSL, rustup's downloaded binaries are patched against one specific store glibc and die with ENOENT after a glibc bump + GC; the activation hook in `home/marcus/wsl/toolchains.nix` reinstalls stable whenever glibc changes. On the mac there is no glibc problem — `home/marcus/mac/toolchains.nix` has only a first-run bootstrap. JetBrains gets its GOROOT from `home/marcus/common/goroot.nix`, which copies `${pkgs.go}/share/go` to `~/.toolchains/go` with `cp -RL` — **it must be a real dereferenced directory**: over `\\wsl$` Windows can't traverse Linux symlinks, and a raw store path rots on the next go update + GC. That file is shared by `wsl.nix` and `mac.nix` but deliberately **not** in `home/marcus/common/default.nix`, so `wsl-lite` (no IDE) skips the 250MB copy.
- **On the mac, `nix.enable = false` is load-bearing** — Determinate Nix owns the daemon and nix-darwin refuses to build otherwise. Never set system-side `nix.settings`/`nix.gc`/`nix.optimise` in `modules/darwin/`; user-level GC lives in `home/marcus/mac/nix.nix` instead.
- **`homebrew.nix` has `cleanup = "zap"`**: any formula/cask/tap not declared there is uninstalled on the next mac rebuild. When marcus mentions installing a mac app, it must be declared or it will vanish.
- **The usernames differ per machine** — `marcus` on WSL, `marcussanchez` on the mac. The HM bridges and `users.nix` files encode this; don't "unify" them.
- **`home.stateVersion` ("25.05") and both `system.stateVersion`s ("25.05" on WSL, `6` on darwin) must never change** — they are not "the version we're on".
- The zsh `initContent` in `home/marcus/common/shell.nix` is wrapped in `lib.mkOrder 1200` on purpose, so marcus's keybindings land after zoxide/atuin's shell hooks. Don't drop the ordering when editing it.
