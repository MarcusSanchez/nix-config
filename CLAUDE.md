# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flake-based Nix configuration for a WSL NixOS dev box (host `bedroom-wsl`, user `marcus`), a family of headless WSL instances sharing one config (`nixos-lite`, `office-lite-wsl-1`, `office-lite-wsl-2` — same user — same toolchains, no Windows integration; meant for pulling a repo down on some other PC and working from a terminal), and a MacBook Air on nix-darwin + Determinate Nix (host `macbook-air`, user `marcussanchez`). On every machine the repo lives at `~/nix-config`; on WSL `/etc/nixos` is symlinked to it (what bare `nixos-rebuild` relies on), on the mac `/etc/nix-darwin` is. The GitHub repo is `MarcusSanchez/nix-config`; the weekly `system.autoUpgrade` on both WSL boxes builds from pushed main there, never from the working tree — so one push deploys to two machines. The mac has no autoUpgrade (`nh darwin switch -u` updates it by hand). GC runs daily on the WSL boxes and weekly as a launchd agent on the mac; every one of these timers catches up after downtime rather than skipping.

**Each NixOS host resolves its config by hostname**: `nixos-rebuild --flake /etc/nixos` with no `#attr` builds `nixosConfigurations.<hostname>`, as do `system.autoUpgrade` and `NH_FLAKE`. The flake attribute and `networking.hostName` must therefore stay equal — `flake.nix` keys each entry by hostname and passes it to the host module as `hostName` via `specialArgs`, so they cannot drift. Several attributes may point at the same host module; that's how an identical second box is added, as one line in `flake.nix` and nothing else. The Windows-side WSL distro name (`wsl -d <name>`) is a separate identifier NixOS never sees.

Claude Code sessions run on any of them — `uname` separates darwin from Linux, `hostname` separates the two WSL boxes (`uname` alone cannot). Each machine can build and activate only its own platform; the *other* platform's config can still be fully evaluated — do that after touching shared files, and flag cross-platform changes for marcus to activate on the other machine.

## Commands

```sh
# WSL only
sudo nixos-rebuild switch --flake /etc/nixos   # apply (passwordless sudo works)
nix eval --raw '/etc/nixos#darwinConfigurations."macbook-air".system.drvPath'
                                               # eval the mac system after touching darwin/ or home/

# Mac only
sudo darwin-rebuild switch                     # apply — sudo pops a Touch ID prompt that works
                                               # even from Claude's non-interactive shell; marcus
                                               # approves it by fingerprint
nix eval --raw '/etc/nix-darwin#nixosConfigurations.bedroom-wsl.config.system.build.toplevel.drvPath'
nix eval --raw '/etc/nix-darwin#nixosConfigurations.nixos-lite.config.system.build.toplevel.drvPath'
                                               # eval the WSL systems after touching nixos/ or home/
                                               # (on WSL, `nix flake check` already covers both)

# Both
nix flake check                                # validate before switching — always do this after edits
nix fmt                                        # format all nix files (nixfmt-tree)
nix flake update                               # bump inputs by hand (CI does it Sundays via
                                               # update-flake-lock.yml, gated on the full eval)
```

There are no tests; `nix flake check` (which evaluates every `nixosConfigurations` entry, all four WSL hosts included) + the darwin eval + a successful switch is the verification story.

## Architecture

Three layers per platform, wired in `flake.nix`. Flake inputs are passed everywhere as `specialArgs`/`extraSpecialArgs`, so any module can take `inputs` as an argument. Two nixpkgs inputs on purpose: `nixpkgs` (nixos-unstable, Linux) and `nixpkgs-darwin` (nixpkgs-unstable, where darwin caches populate first) — don't collapse them.

1. `hosts/wsl/`, `hosts/wsl-lite/`, and `hosts/mac/` — the entries in `flake.nix`. Host-specific values only (platform, `system.stateVersion`, `networking.hostName` from the `hostName` specialArg, and `homeEntryPoint` — the option `modules/common/home-manager.nix` reads to decide which home config this host's user gets; every host declares it, the mac included).
2. `modules/common/` (shared — only options that exist on both platforms), `modules/nixos/`, and `modules/darwin/` — system layer, one concern per file. Each platform aggregator imports `../common` plus its own files: **a new module does nothing until added to an imports list.** Every WSL host imports `modules/nixos` unchanged and adds `tailscale.nix` at host level; they differ only in hostname and `homeEntryPoint`, because what separates the dev box from the lite ones lives in the home layer. The HM bridge and the sops config live in `modules/common/` (`home-manager.nix`, `secrets.nix`), branching on `isDarwin` where the platforms differ; each platform's `home-manager.nix`/`secrets.nix` are one-line shims holding only the platform module import that makes those options exist. The bridge sets `backupFileExtension = "hm-backup"`.
3. `home/marcus/` — Home Manager, mirroring the system layer's shape: `common/` (shared concern files, aggregated by its `default.nix`), `wsl/` and `mac/` (platform-only concern files), and `wsl.nix` / `wsl-lite.nix` / `mac.nix` as the per-host entry points (identity + `./common` + whichever platform files that host wants). `wsl-lite.nix` imports only `./common` — it is `wsl.nix` minus the entire `wsl/` dir, **and that omission is the whole difference between the dev box and the lite kind**; read its header before adding anything back. The bridges import the entry points, never `common/` directly.

Where things go: CLI tool for every machine → `modules/common/packages.nix`, or `home/marcus/common/packages.nix` if user-scoped; Linux-only build tools → `modules/nixos/packages.nix` (note: everything in `modules/nixos/` lands on *both* WSL hosts); mac GUI app → cask in `modules/darwin/homebrew.nix`; new concern → new file + aggregator entry in `common/` (both platforms) or the platform dir; shared user config → concern file in `home/marcus/common/` + import in its `default.nix`; platform-only user config → file in `home/marcus/wsl/` or `home/marcus/mac/`, imported from the relevant entry point. There is no `modules/darwin/packages.nix` — the mac gets its build tools from the Xcode CLT, so create that file only if a mac-only system package ever appears.

**Project-specific tooling never goes in this repo.** It belongs to the project, via devenv: `devenv init` there, declare `packages`/`languages.*`/`services.*` in its `devenv.nix`, and auto-load on `cd` with `use devenv` in its `.envrc` (or `use flake` for a plain flake devShell). This repo carries only what every machine needs.

## File map

Every `.nix` file here opens with a header comment explaining itself, so this map only records what a single file *cannot* tell you — where it sits in the wiring, and which ones are traps. Unannotated names are exactly what they sound like; open them.

```
flake.nix                  inputs + all three host wirings
.sops.yaml                 age recipients          secrets/secrets.yaml  ciphertext

hosts/{wsl,wsl-lite,mac}/  layer 1 — per-host values only

modules/common/            default.nix packages.nix claude-code.nix
                           secrets.nix home-manager.nix — the shared sops
                           config and HM bridge (platform files are shims)
modules/nixos/             lands on EVERY WSL host, unchanged
  default.nix              aggregator — a file here does nothing until listed
  packages.nix             Linux-only build tools + ghostty.terminfo, which
                           fixes TERM for sessions ssh-ing *into* this box
  keyring.nix              gnome-keyring as the Secret Service secretspec needs
  tailscale.nix            NOT in the aggregator — host-level, and it carries
                           the systemd-resolved config MagicDNS needs on WSL
                           (Constraints)
  nix.nix nix-ld.nix users.nix wsl.nix
  secrets.nix home-manager.nix            shims — see modules/common
                           (no ssh.nix — it existed only to make the host key
                           that sops used before the single-key move)
modules/darwin/
  default.nix              aggregator
  nix.nix                  nix.enable = false (Constraints)
  tailscale.nix            OSS tailscaled as a launchd daemon, so the mac
                           serves Tailscale SSH like the WSL boxes (the
                           sandboxed GUI builds can't). NEVER re-add the
                           tailscale-app cask while this is on — one
                           tailscaled per mac. nix-darwin#1688 recovery
                           command is in the file header
  homebrew.nix             cleanup = "zap" (Constraints)
  macos.nix                Touch ID sudo + Remote Login (the password-auth
                           fallback for when tailscaled is down — no
                           authorized_keys exist anywhere any more)
  users.nix fonts.nix
  secrets.nix home-manager.nix            shims — see modules/common

home/marcus/
  wsl.nix wsl-lite.nix mac.nix   entry points — the HM bridges import these,
                           never common/ directly
  common/                  aggregated by its default.nix
    secrets.nix            user side of /run/secrets: FLY_API_TOKEN export +
                           atuin's one-time login
    dotfiles/              flat: zed.settings.json, zed.keymap.json (which
                           carries both cmd- and ctrl- variants), .ideavimrc
    toolchains.nix         rustup repair/bootstrap (isDarwin branch) + the
                           JetBrains GOROOT symlink — see Constraints
    neovim.nix bitwarden.nix                see Constraints
    packages.nix shell.nix git.nix catppuccin.nix comma.nix
  wsl/
    win-sync.nix           two-way sync engine: UI-side edits pull into the
                           repo and auto-commit (chore(<name>):) + push, repo-side
                           edits push out to Windows, and both-changed warns
                           and writes nothing
    dotfiles.nix           common/dotfiles/ ↔ Windows, via win-sync
    windows.nix            windows.username, set per host
  mac/
    dotfiles.nix           per-file symlinks into common/dotfiles/ (where the
                           WSL side copies instead)
    auto-commit.nix        commits + pushes common/dotfiles drift on activation
    manual.nix             HM's own manpages off — they warn on every eval
    ghostty.nix nix.nix
```

## Constraints that are easy to violate

- **Never commit a decrypted secret, and never print one.** Credentials live age-encrypted in `secrets/secrets.yaml` (`sops secrets/secrets.yaml` to edit; `.sops.yaml` lists recipients). The repo is public, so the ciphertext is world-readable — that's fine, but a plaintext slip is permanent in git history and means revoking at the provider. **Every machine decrypts with the same key** — the personal age key from Bitwarden, at `/var/lib/sops-nix/key.txt` (`sops.age.keyFile`, sops-nix's system module on both platforms). `.sops.yaml` has one recipient, so onboarding a machine never edits the recipient list and never runs `sops updatekeys`: place the key, switch. The same key at `~/.config/sops/age/keys.txt` is what `sops` uses to edit. This replaced per-machine SSH host keys deliberately — marcus owns every box, and revoking a recipient never un-exposes what it already decrypted, so the per-machine scheme was paying real friction for protection it didn't deliver. **A missing `keyFile` is fatal, not a fallback** (`sops-install-secrets`: "cannot read keyfile"), so a machine that hasn't had the key placed fails the whole `setupSecrets` step — that's the expected first-switch error on a fresh box, and it's why the key must land before the second switch.

- **`modules/nixos/tailscale.nix` is imported by the host modules, NOT the aggregator — never move it there.** Every WSL2 distro on a Windows PC shares one network namespace (same IP, ports, routing table), so two `tailscaled` instances fight over `tailscale0`, UDP 41641 and the `100.64.0.0/10` route. One tailnet node per PC — every host module imports it today only because each instance lives on a PC of its own. Two sharing a PC means the second drops the import, and that per-machine fact is exactly what the aggregator cannot express. Also **never install Tailscale on Windows while this is on** — traffic would be encapsulated twice and Tailscale packets don't fit inside Tailscale packets. Running it inside WSL is viable only because mirrored networking gives `eth1` an MTU of 1500 (NAT mode's 1280 breaks SSH and TLS while ping keeps working) and NixOS-WSL runs systemd as PID 1. The node is up only while WSL is — that's accepted, not a bug. (The mac is its own node via `modules/darwin/tailscale.nix` — OSS daemon, not the GUI app; see the file map.)

- **Never manage `~/.config/nvim` through Nix, and never re-enable `programs.neovim`.** It is marcus's own LazyVim fork (github.com/marcussanchez/neovim-config), a normal mutable git checkout — lazy.nvim writes `lazy-lock.json` and marcus commits/pushes from there. `programs.neovim` generates its own `init.lua` and symlinks it over the checkout, silently breaking the whole editor (this happened once; the fix was deliberate). `home/marcus/common/neovim.nix` installs the stable nixpkgs binary via `home.packages`, clone-bootstraps the config if `~/.config/nvim` doesn't exist, and otherwise ff-only pulls it during activation (only when the tree is clean — never touch that safety check). (Marcus prefers stable over nightly; a nightly-overlay setup existed before commit ~2026-07 if ever needed again.)
- **Zig and ZLS must stay on matching versions or editor tooling breaks.** Both come from nixpkgs (`pkgs.zig` / `pkgs.zls` in `modules/common/packages.nix`), which builds zls against its own zig, so they stay in lockstep automatically — don't source one of them from somewhere else. If a just-released Zig is ever needed before nixpkgs catches up, the old two-input overlay approach (mitchellh/zig-overlay + zigtools/zls pinned ref) is in git history at `modules/nixos/zig.nix` before commit ~2026-07.
- **Rust must come via rustup, not nixpkgs rustc/cargo — RustRover refuses standalone toolchains.** (Tried the nixpkgs route once, 2026-07, had to revert.) On WSL, rustup's downloaded binaries are patched against one specific store glibc and die with ENOENT after a glibc bump + GC; the activation hook in `home/marcus/common/toolchains.nix` (one file, branched on `isDarwin`) reinstalls stable whenever glibc changes; on the mac there is no glibc problem, so that branch is only a first-run bootstrap. The same file gives JetBrains its GOROOT, linking `~/.toolchains/go` at `${pkgs.go}/share/go` so the IDE has a path that doesn't rot when a go update + GC retires the old store path. It was a `cp -RL` dereferenced copy until 2026-07-28 because `\\wsl$` used to expose Linux symlinks as untraversable reparse points (commit 46643f1); marcus confirmed a link works now, and the copy is in git history if that regresses. Now one symlink, and the whole file lives in `common/`, so every host gets it.
- **On the mac, `nix.enable = false` is load-bearing** — Determinate Nix owns the daemon and nix-darwin refuses to build otherwise. Never set system-side `nix.settings`/`nix.gc`/`nix.optimise` in `modules/darwin/`; user-level GC lives in `home/marcus/mac/nix.nix` instead. Daemon-level settings (extra substituters and their keys) are therefore imperative on the mac, in `/etc/nix/nix.custom.conf` — Determinate's file, applied with `sudo launchctl kickstart -k system/systems.determinate.nix-daemon`. The WSL boxes get the same settings declaratively from `modules/nixos/nix.nix`.
- **If `programs.starship` is ever enabled again, set `catppuccin.starship.enable = false` with it.** `autoEnable` otherwise pulls in catppuccin's starship port, which reads its palette from a derivation built at *evaluation* time. That derivation is the target platform's, so evaluating the mac config from Linux — CI's ubuntu runner, or a WSL box — fails outright rather than degrading. It broke CI for three commits on 2026-07-30 and looked like a hostname problem. `nix flake check` never catches it, because that command doesn't touch `darwinConfigurations`.

- **`homebrew.nix` has `cleanup = "zap"`**: any formula/cask/tap not declared there is uninstalled on the next mac rebuild. When marcus mentions installing a mac app, it must be declared or it will vanish.
- **The usernames differ per machine** — `marcus` on WSL, `marcussanchez` on the mac. The HM bridges and `users.nix` files encode this; don't "unify" them.
- **`home.stateVersion` ("25.05") and both `system.stateVersion`s ("25.05" on WSL, `6` on darwin) must never change** — they are not "the version we're on".
- The zsh `initContent` in `home/marcus/common/shell.nix` is wrapped in `lib.mkOrder 1200` on purpose, so marcus's keybindings land after zoxide/atuin's shell hooks. Don't drop the ordering when editing it.
