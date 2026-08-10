# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flake-based Nix configuration for a WSL NixOS dev box (host `bedroom-wsl`, user `marcus`), a family of headless WSL instances sharing one config (`framework-wsl`, `office-lite-wsl-1`, `office-lite-wsl-2` — same user — same toolchains, no Windows integration; meant for pulling a repo down on some other PC and working from a terminal), a bare-metal NixOS laptop (host `tuf-nixos`, user `marcus` — ASUS TUF Dash F15, niri + DankMaterialShell desktop, absorbed from the archived `marcussanchez/tuf-nix-config` repo whose git history holds the rejected Plasma/GNOME/SDDM experiments), a bare-metal desktop (host `bedroom-nixos` — the dual-boot side of the PC that also hosts bedroom-wsl; same desktop flavor as the laptop, its own RTX 5080 facts), and a MacBook Air on nix-darwin + Determinate Nix (host `macbook-air`, user `marcussanchez`). On every machine the repo lives at `~/nix-config`; on Linux `/etc/nixos` is symlinked to it (what bare `nixos-rebuild` relies on), on the mac `/etc/nix-darwin` is. The GitHub repo is `MarcusSanchez/nix-config`; the weekly `system.autoUpgrade` on every WSL box builds from pushed main there, never from the working tree — so one push deploys to all of them. The mac and both bare-metal hosts have no autoUpgrade (`nh darwin switch -u` / `nh os switch -u` by hand — a desktop should never swap its compositor mid-session). GC runs daily on the Linux boxes and weekly as a launchd agent on the mac; every one of these timers catches up after downtime rather than skipping.

**Each NixOS host resolves its config by hostname**: `nixos-rebuild --flake /etc/nixos` with no `#attr` builds `nixosConfigurations.<hostname>`, as do `system.autoUpgrade` and `NH_FLAKE`. The flake attribute and `networking.hostName` must therefore stay equal — `flake.nix` keys each entry by hostname and passes it to the host module as `hostName` via `specialArgs`, so they cannot drift. Several attributes may point at the same host module; that's how an identical second box is added, as one line in `flake.nix` and nothing else. The Windows-side WSL distro name (`wsl -d <name>`) is a separate identifier NixOS never sees; installs keep the `.wsl` file's default name `NixOS`, since parameterizing it bought nothing (`--name` only matters if one PC hosts two distros — WSL refuses duplicates).

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
nix eval --raw '/etc/nix-darwin#nixosConfigurations.framework-wsl.config.system.build.toplevel.drvPath'
nix eval --raw '/etc/nix-darwin#nixosConfigurations.tuf-nixos.config.system.build.toplevel.drvPath'
nix eval --raw '/etc/nix-darwin#nixosConfigurations.bedroom-nixos.config.system.build.toplevel.drvPath'
                                               # eval the NixOS systems after touching nixos/ wsl/
                                               # desktop/ or home/ (on any NixOS box, `nix flake
                                               # check` already covers every NixOS host; the office
                                               # attrs differ from framework-wsl only by hostname)

# Both
nix flake check                                # validate before switching — always do this after edits
nix fmt                                        # format all nix files (nixfmt-tree)
nix flake update                               # bump inputs by hand (CI does it Sundays via
                                               # update-flake-lock.yml, gated on the full eval)
```

There are no tests; `nix flake check` (which evaluates every `nixosConfigurations` entry — all six: four WSL hosts and both bare-metal machines) + the darwin eval + a successful switch is the verification story. `./bin/config:check` runs the whole gate including the darwin eval. Each machine can switch only itself — changes for the others are flagged for the user to activate there.

## Architecture

Three layers per platform, wired in `flake.nix`. Flake inputs are passed everywhere as `specialArgs`/`extraSpecialArgs`, so any module can take `inputs` as an argument. Two nixpkgs inputs on purpose: `nixpkgs` (nixos-unstable, Linux) and `nixpkgs-darwin` (nixpkgs-unstable, where darwin caches populate first) — don't collapse them.

1. `hosts/` — the entries in `flake.nix`. The naming rule: dirs with hardware truth on disk are 1:1 with a machine and named by its EXACT hostname (`tuf-nixos/`, `bedroom-nixos/` — hardware-configuration.nix, nvidia facts, lanzaboote); dirs without hardware truth are shareable KINDS (`wsl/`, `wsl-lite/`, `darwin/` — several flake attrs may point at one). Host-specific values only (platform, `system.stateVersion`, `networking.hostName` from the `hostName` specialArg, and `homeEntryPoint` — the option `modules/common/home-manager.nix` reads to decide which home config this host's user gets; every host declares it, the mac included).
2. `modules/common/` (shared — only options that exist on both platforms), `modules/nixos/` (the shared **Linux core** — every NixOS host, WSL and bare metal alike), `modules/wsl/` and `modules/desktop/` (the two Linux **flavors** — Windows integration + weekly autoUpgrade vs the boot/niri/DMS desktop stack), and `modules/darwin/` — system layer, one PURPOSE per file: a purpose may span several related options (peripherals.nix carries bluetooth+printing+fwupd+power+wooting), but never becomes a grab-bag — that is how the old desktop.nix monolith grew. The naming system across every layer: `common` is all platforms, OS names for OS cores (`nixos`, `darwin`), flavor names for flavors (`wsl`, `desktop`); `darwin` doubles as core and only-kind until a second darwin kind exists (a second mac would share `hosts/darwin` the way WSL boxes share `hosts/wsl`). Aggregators import `../common` (or, for flavors, just their own files): **a new module does nothing until added to an imports list.** Every WSL host imports `modules/nixos` + `modules/wsl` and adds `modules/wsl/tailscale.nix` at host level; both bare-metal hosts import `modules/nixos` + `modules/desktop` (whose aggregator carries tailscale — bare metal is always its own node). The HM bridge and the sops config live in `modules/common/` (`home-manager.nix`, `secrets.nix`), branching on `isDarwin` where the platforms differ; `modules/nixos/default.nix` and `modules/darwin/default.nix` carry the sops-nix/HM platform module imports that make those options exist. The bridge sets `backupFileExtension = "hm-backup"`.
3. `home/marcus/` — Home Manager, mirroring the system layer's shape: `common/` (shared concern files, aggregated by its `default.nix`), `wsl/`, `darwin/`, and `desktop/` (platform-only concern files), and `wsl.nix` / `wsl-lite.nix` / `darwin.nix` / `desktop.nix` as the per-host entry points (identity + `home.stateVersion` + `./common` + whichever platform files that host wants). `wsl-lite.nix` imports only `./common` — it is `wsl.nix` minus the entire `wsl/` dir, **and that omission is the whole difference between the dev box and the lite kind**; read its header before adding anything back. The bridges import the entry points, never `common/` directly.

Where things go: CLI tool for every machine → `modules/common/packages.nix`, or `home/marcus/common/packages.nix` if user-scoped; Linux-only build tools → `modules/nixos/packages.nix` (lands on EVERY NixOS host, laptop included); WSL-only or desktop-only system config → `modules/wsl/` or `modules/desktop/` + their aggregator; mac GUI app → cask in `modules/darwin/homebrew.nix`; desktop GUI app → `home/marcus/desktop/apps.nix`; new concern → new file + aggregator entry; shared user config → concern file in `home/marcus/common/` + import in its `default.nix`; platform-only user config → file in `home/marcus/wsl/`, `home/marcus/darwin/`, or `home/marcus/desktop/`, imported from the relevant entry point. There is no `modules/darwin/packages.nix` — the mac gets its build tools from the Xcode CLT, so create that file only if a mac-only system package ever appears.

**Project-specific tooling never goes in this repo.** It belongs to the project, via devenv: `devenv init` there, declare `packages`/`languages.*`/`services.*` in its `devenv.nix`, and auto-load on `cd` with `use devenv` in its `.envrc` (or `use flake` for a plain flake devShell). This repo carries only what every machine needs. Its own operational commands (`secrets:edit`, `secrets:status`, `age:place`, `config:check`) are plain executables in `bin/`, on PATH via the one-line `.envrc` (`PATH_add bin`) — devenv was tried for this and retired 2026-08-01: a 67 MiB profile and a second lockfile for four scripts whose tools all come from the system config. `./bin/<name>` works with no direnv at all.

## File map

Every `.nix` file here opens with a header comment explaining itself, so this map only records what a single file *cannot* tell you — where it sits in the wiring, and which ones are traps. Unannotated names are exactly what they sound like; open them.

```
flake.nix                  inputs + all host wirings. dank-material-shell
                           input supplies ONLY the dms-greeter module (the
                           shell is nixpkgs' dms-shell — cache reasons;
                           don't collapse the split). nix-homebrew takes no
                           follows — it has no nixpkgs input, only the brew
                           source it pins
bin/                       repo-operations scripts (secrets:edit,
                           secrets:status, age:place, secrets:drop,
                           config:check) — plain executables, PATH_add'd
                           by .envrc; secrets:drop is age:place's inverse
                           and must remove more than the two key files
                           (its header lists the full inventory)
.sops.yaml                 age recipients + tier rules (super first — first
                           match wins)
secrets/secrets.yaml       lower-tier ciphertext   secrets/super.yaml  trusted-only

hosts/{wsl,wsl-lite,darwin}/ layer 1 — per-host values only
hosts/bedroom-nixos/       the desktop PC, dual-booted beside Windows
                           (installed 2026-08-06). hardware-configuration
                           .nix is the generated truth from that install —
                           excluded from statix + deadnix like tuf's,
                           regenerate don't edit. Its own RTX 5080
                           nvidia.nix
  lanzaboote.nix           Secure Boot, LIVE since install. On a
                           reinstall, comment the import out until
                           `sbctl create-keys` has run, or the bootloader
                           install (and nixos-install with it) fails.
                           The working MSI ceremony (its header):
                           firmware "Delete all Secure Boot variables" =
                           TRUE Setup Mode (delete-PK-only leaves db/KEK
                           immutable), then runtime `sbctl enroll-keys
                           --microsoft` succeeds; fwupd restores the
                           dropped dbx afterwards
hosts/tuf-nixos/           the laptop: per-host values + its hardware truth
  hardware-configuration.nix  generated (nixos-generate-config) — excluded
                           from statix (statix.toml) and deadnix
                           (config:check + check.yml), regenerate don't edit
  nvidia.nix               HOST-level on purpose: MUX-discrete RTX 3070,
                           open modules, early-KMS initrd — a future
                           desktop PC writes its own, never inherits this

modules/common/            default.nix packages.nix claude-code.nix
                           secrets.nix home-manager.nix — the shared sops
                           config and HM bridge (platform files are shims)
modules/nixos/             the shared Linux CORE — every NixOS host
  default.nix              aggregator — a file here does nothing until
                           listed; also carries the platform sops-nix + HM
                           module imports for modules/common
  packages.nix             Linux-only build tools + ghostty.terminfo, which
                           fixes TERM for sessions ssh-ing *into* this box
  nix-ld.nix               enable only — the desktop's GUI library list
                           lives in modules/desktop/foreign-binaries.nix
                           (libraries CONCATENATE across modules; proven
                           by eval: WSL = base 14, laptop = 47)
  nix.nix users.nix        (no ssh.nix — it existed only to make the host key
                           that sops used before the single-key move)
modules/wsl/               the WSL flavor — both WSL host kinds
  wsl.nix keyring.nix      keyring = gnome-keyring for headless secretspec
                           (the desktop gets its keyring via niri instead)
  autoupgrade.nix          the weekly deploy timer — WSL only, deliberately
                           not the laptop (Constraints)
  tailscale.nix            NOT in the aggregator — host-level, and it carries
                           the systemd-resolved config MagicDNS needs on WSL
                           (Constraints)
  rustdesk-bridge.nix      NOT in the aggregator — imported by hosts/wsl-lite
                           only: tailscale-serve doorway to the Windows side's
                           RustDesk direct-access port (21118), because the
                           tailnet node lives in WSL while RustDesk runs on
                           Windows. Needs a one-time Windows-side checkbox —
                           its header has the ceremony
modules/desktop/           the bare-metal flavor — the laptop and the
                           bedroom-nixos desktop
  default.nix              aggregator; imports the dms-greeter flake module;
                           carries tailscale.nix (aggregator placement is
                           CORRECT here, unlike WSL — bare metal is always
                           its own node). The niri..packages import order
                           mirrors the old desktop.nix monolith — merged
                           lists order by module position, don't reorder
  niri.nix                 the compositor + portals; session Exec routed
                           through systemd-cat (journalctl -t niri-session)
  greeter.nix              the whole login-screen story: dms-greeter,
                           accounts-daemon + the AccountsService avatar
                           seed (the greeter can't read ~/.face through
                           the 0700 home), and the generated
                           /etc/greetd/niri_overrides.kdl — the session's
                           niri.outputs.kdl handed over unmodified.
                           Which screens carry the sign-in UI is the
                           per-host greeterScreens option (declared
                           here, set in hosts/ like secretsTier; empty =
                           all screens, no value can strand the login);
                           the rest stay blank-but-on. Cross-layer on
                           purpose: reads home/marcus/common/dotfiles/ and
                           desktop/assets/. Ships via `nixos-rebuild
                           boot`, never switch
  peripherals.nix          plugged-in/paired devices, their firmware and
                           power: bluetooth, CUPS, fwupd (the dbx-restore
                           story), upower + power-profiles-daemon (DMS
                           widgets fail QUIETLY without them), wooting
                           udev rules (deliberately not
                           hardware.wooting.enable — it bundles the app)
  audio.nix                pipewire + rtkit; allowed-rates is a device-
                           intersected MENU (content-rate following), not
                           a forced rate
  networking.nix           NetworkManager + the LAN firewall policy (dev
                           ports); the tailnet catch-all lives in
                           tailscale.nix (trustedInterfaces)
  users.nix                desktop-only groups (input/uinput for xremap,
                           networkmanager) — one list, order feeds merges
  boot.nix                 Plymouth + retain-splash handoff to the greeter —
                           several cooperating tricks, see its header and
                           Constraints before touching ANY of it (also
                           carries zramSwap, independent of that web)
  foreign-binaries.nix     the two shims for non-nix binaries, both for
                           the JetBrains/Toolbox story: the nix-ld
                           X11/GTK/NSS/JCEF list (empirically derived, do
                           not trim — header has the ldd recipe) and
                           envfs (/bin + /usr/bin as a FUSE mount
                           resolving shebangs against PATH, so Toolbox's
                           generated #!/bin/bash launchers run; desktop
                           only — not handed to the unattended WSL boxes)
  security-keys.nix        (was tpm.nix) tpm-fido + libfido2 udev rules;
                           the tpm-fido rules must sort BEFORE
                           70-uaccess.rules — numbered package file, NOT
                           services.udev.extraRules (lands at 99-, too late)
  packages.nix locale.nix fonts.nix tailscale.nix
                           (swaylock's PAM entry lives in niri.nix with
                           the session it unlocks)
modules/darwin/
  default.nix              aggregator
  nix.nix                  nix.enable = false (Constraints)
  tailscale.nix            OSS tailscaled as a launchd daemon, so the mac
                           serves Tailscale SSH like the WSL boxes (the
                           sandboxed GUI builds can't). NEVER re-add the
                           tailscale-app cask while this is on — one
                           tailscaled per mac. nix-darwin#1688 recovery
                           command is in the file header
  homebrew.nix             cleanup = "zap" + nix-homebrew, which owns the
                           prefix and pins brew's version (Constraints)
  macos.nix                Touch ID sudo + Remote Login (the password-auth
                           fallback for when tailscaled is down — no
                           authorized_keys exist anywhere any more)
  users.nix fonts.nix

home/marcus/
  wsl.nix wsl-lite.nix darwin.nix desktop.nix  entry points — the HM bridges
                           import these, never common/ directly; each owns
                           its home.stateVersion (25.05 everywhere except
                           desktop = 26.05 — per-machine birth certificates,
                           can't live in common/)
  common/                  aggregated by its default.nix
    secrets.nix            user side of /run/secrets (FLY_API_TOKEN/
                           CROC_SECRET exports) + rbw, the root of the
                           whole credential chain. atuin's login is NOT
                           here — it's system-activation text in
                           modules/common/secrets.nix, because HM
                           activation misses a case on each platform
                           (both files say which)
    shell.nix              zsh + the prompt + catppuccin theming (autoEnable —
                           nvim opts out, and a revived starship must too;
                           see Constraints)
    packages.nix           user CLIs + comma with its prebuilt nix-index db
    cli-tools.nix          the modern-unix staples that carry shell hooks,
                           aliases or theming (fzf/bat/eza/yazi/lazygit/
                           btop as programs.* — catppuccin themes them via
                           the HM modules; ls->eza, cat->bat aliases,
                           interactive-only). The no-config siblings live
                           in modules/common/packages.nix
    dotfiles-links.nix     the UI-managed-config links + drift auto-commit
                           shared by darwin/ and desktop/ (message names the
                           host via osConfig) — NOT in common/default.nix
                           on purpose: win-sync owns those files on WSL
    ghostty.nix            shared ghostty settings — NOT in
                           common/default.nix on purpose: enable installs
                           the package, and WSL must not gain a GUI
                           terminal. Imported by darwin/ + desktop/ ghostty.nix
    dotfiles/              flat: zed.settings.json (ONE file for every
                           machine — font sizes and wsl_connections need
                           cross-machine consensus), zed.keymap.json (both
                           cmd- and ctrl- variants), .ideavimrc,
                           niri.config.kdl (binds/layout; also hardcodes
                           the absolute xremap.yml path),
                           niri.outputs.kdl (connector-keyed outputs:
                           absent monitors are inert, so one file serves
                           many machines — add output blocks, don't fork;
                           split out because the greeter's compositor
                           consumes the same file via modules/desktop/
                           greeter.nix; DP-2's rotation comes from the
                           bedroom host's panel_orientation kernel param,
                           NOT a transform here — niri composes the two),
                           niri.host.<hostname>.kdl (per-host tail —
                           config.kdl includes the stable name
                           niri.host.kdl, linked per hostname; a NEW
                           desktop host must commit its file BEFORE first
                           switch or HM links against nothing),
                           dms.settings.json, xremap.yml,
                           hammerspoon.init.lua (the mac's xremap; watches
                           this directory and reloads itself on save, so
                           edits need no rebuild)
    toolchains.nix         rustup repair/bootstrap (isDarwin branch) + the
                           JetBrains GOROOT symlink — see Constraints
    neovim.nix             see Constraints
    git.nix
  wsl/
    win-sync.nix           two-way sync engine: UI-side edits pull into the
                           repo and auto-commit (chore(<name>):) + push, repo-side
                           edits push out to Windows, and both-changed warns
                           and writes nothing
    dotfiles.nix           common/dotfiles/ ↔ Windows via win-sync; also
                           declares windows.username (its only consumer;
                           the value is set in wsl.nix)
  darwin/
    dotfiles.nix           shim -> common/dotfiles-links.nix (per-file
                           symlinks where the WSL side copies instead)
    nix.nix                user GC launchd agent + HM manpages off (they
                           warn on every eval under Determinate Nix)
    hammerspoon.nix        the mac's xremap — per-app remaps matched on
                           bundle id AND window title, which is why it is
                           not Karabiner (bundle ids only, and its DriverKit
                           driver is broken on macOS 26). Accessibility must
                           be granted BY HAND; until it is, the event tap
                           never starts and the keys silently do nothing
    ghostty.nix
  desktop/
    niri.nix               user side of the session: DMS helper packages
                           (quickshell/dgop/matugen — dms-shell does NOT
                           bundle them; matugen missing = theme generation
                           silently no-ops), GTK/dconf theme names
                           (Adwaita everywhere; see Constraints for why
                           not Papirus), the snipping tool
                           (grim/slurp/satty, Mod+Shift+S), and FOUR
                           out-of-store links: niri/config.kdl,
                           niri/niri.outputs.kdl, niri/niri.host.kdl
                           (target picked by hostname), DMS settings.json
    dotfiles.nix           shim -> common/dotfiles-links.nix
    appearance.nix         wallpaper + avatar from ./assets, linked to
                           stable paths under ~ — DMS records an ABSOLUTE
                           path in its session state, so a store path would
                           rot at the next GC. Avatar goes to ~/.face, the
                           convention AccountsService falls back to
    apps.nix ghostty.nix   ghostty.nix = shared common/ghostty.nix +
                           the GTK chrome and Windows-Terminal keybinds
```

## Constraints that are easy to violate

- **Never commit a decrypted secret, and never print one.** Credentials live age-encrypted in `secrets/` (`secrets:edit` / `secrets:edit super`; `.sops.yaml` lists recipients). The repo is public, so the ciphertext is world-readable — that's fine, but a plaintext slip is permanent in git history and means revoking at the provider. **Two tiers, six keys** (tiers since 2026-08-02): `secrets.yaml` (gh low-scope token, croc, atuin) is opened by the roaming master key from Bitwarden — what `age:place` places on lite/temporary boxes; `super.yaml` (fly org token + future hot secrets) is opened ONLY by the per-machine keys of `bedroom-wsl`, `macbook-air`, `tuf-nixos`, and `bedroom-nixos` (each generated on-box, backed up nowhere — deliberately: vault compromise cannot open super) plus a buried paper-only recovery key. Hosts pick their declaration set via `secretsTier` (`hosts/wsl-lite` = "lite"; default "full" declares `fly_token` with `sopsFile = super.yaml`). Consequences to respect: onboarding a lite box still never touches `.sops.yaml` (place master, switch; `age:place` re-locks rbw afterward — the vault holds the super RECOVERY key, so an unlocked hour would bridge the tiers); enrolling/replacing a TRUSTED machine edits `.sops.yaml` + runs `sops updatekeys` on both files, and updatekeys for `super.yaml` must run where an existing recipient lives; `secrets:drop` AND `age:place` both REFUSE on trusted boxes (capability probe: does the box's key open super.yaml) — drop would destroy the unbacked-up machine key, place would silently overwrite it with the master; **nothing unreissuable ever goes in `super.yaml`** — atuin_key stays in the lower tier so it remains Bitwarden-recoverable; the mac factory reset will destroy `&macbook-air` (re-enrollment joins that day's checklist). **A missing `keyFile` is fatal, not a fallback** (`sops-install-secrets`: "cannot read keyfile"), so a machine without a key fails the whole `setupSecrets` step — the expected first-switch error on a fresh box. Declared-but-missing VALUES are equally fatal ("the key 'x' cannot be found"), so a value lands in its yaml before or with its wiring.

- **`modules/wsl/tailscale.nix` is imported by the WSL host modules, NOT the wsl aggregator — never move it there.** Every WSL2 distro on a Windows PC shares one network namespace (same IP, ports, routing table), so two `tailscaled` instances fight over `tailscale0`, UDP 41641 and the `100.64.0.0/10` route. One tailnet node per PC — every host module imports it today only because each instance lives on a PC of its own. Two sharing a PC means the second drops the import, and that per-machine fact is exactly what the aggregator cannot express. Also **never install Tailscale on Windows while this is on** — traffic would be encapsulated twice and Tailscale packets don't fit inside Tailscale packets. Running it inside WSL is viable only because mirrored networking gives `eth1` an MTU of 1500 (NAT mode's 1280 breaks SSH and TLS while ping keeps working) and NixOS-WSL runs systemd as PID 1. The node is up only while WSL is — that's accepted, not a bug. (The mac and both bare-metal hosts are their own nodes — `modules/darwin/tailscale.nix` (OSS daemon, not the GUI app) and `modules/desktop/tailscale.nix` (aggregator placement is fine on bare metal, and it trusts tailscale0 wholesale — the LAN firewall list in networking.nix stays tight because of it); see the file map.)

- **Never manage `~/.config/nvim` through Nix, and never re-enable `programs.neovim`.** It is marcus's own LazyVim fork (github.com/marcussanchez/neovim-config), a normal mutable git checkout — lazy.nvim writes `lazy-lock.json` and marcus commits/pushes from there. `programs.neovim` generates its own `init.lua` and symlinks it over the checkout, silently breaking the whole editor (this happened once; the fix was deliberate). `home/marcus/common/neovim.nix` installs the stable nixpkgs binary via `home.packages`, clone-bootstraps the config if `~/.config/nvim` doesn't exist, and otherwise ff-only pulls it during activation (only when the tree is clean — never touch that safety check). (Marcus prefers stable over nightly; a nightly-overlay setup existed before commit ~2026-07 if ever needed again.)
- **Zig and ZLS must stay on matching versions or editor tooling breaks.** Both come from nixpkgs (`pkgs.zig` / `pkgs.zls` in `modules/common/packages.nix`), which builds zls against its own zig, so they stay in lockstep automatically — don't source one of them from somewhere else. If a just-released Zig is ever needed before nixpkgs catches up, the old two-input overlay approach (mitchellh/zig-overlay + zigtools/zls pinned ref) is in git history at `modules/nixos/zig.nix` before commit ~2026-07.
- **Rust must come via rustup, not nixpkgs rustc/cargo — RustRover refuses standalone toolchains.** (Tried the nixpkgs route once, 2026-07, had to revert.) On WSL, rustup's downloaded binaries are patched against one specific store glibc and die with ENOENT after a glibc bump + GC; the activation hook in `home/marcus/common/toolchains.nix` (one file, branched on `isDarwin`) reinstalls stable whenever glibc changes; on the mac there is no glibc problem, so that branch is only a first-run bootstrap. The same file gives JetBrains its GOROOT, linking `~/.toolchains/go` at `${pkgs.go}/share/go` so the IDE has a path that doesn't rot when a go update + GC retires the old store path. It was a `cp -RL` dereferenced copy until 2026-07-28 because `\\wsl$` used to expose Linux symlinks as untraversable reparse points (commit 46643f1); marcus confirmed a link works now, and the copy is in git history if that regresses. Now one symlink, and the whole file lives in `common/`, so every host gets it.
- **On the mac, `nix.enable = false` is load-bearing** — Determinate Nix owns the daemon and nix-darwin refuses to build otherwise. Never set system-side `nix.settings`/`nix.gc`/`nix.optimise` in `modules/darwin/`; user-level GC lives in `home/marcus/darwin/nix.nix` instead. Daemon-level settings (extra substituters and their keys) are therefore imperative on the mac, in `/etc/nix/nix.custom.conf` — Determinate's file, applied with `sudo launchctl kickstart -k system/systems.determinate.nix-daemon`. The WSL boxes get the same settings declaratively from `modules/nixos/nix.nix`.
- **If `programs.starship` is ever enabled again, set `catppuccin.starship.enable = false` with it.** `autoEnable` otherwise pulls in catppuccin's starship port, which reads its palette from a derivation built at *evaluation* time. That derivation is the target platform's, so evaluating the mac config from Linux — CI's ubuntu runner, or a WSL box — fails outright rather than degrading. It broke CI for three commits on 2026-07-30 and looked like a hostname problem. `nix flake check` never catches it, because that command doesn't touch `darwinConfigurations`.

- **`homebrew.nix` has `cleanup = "zap"`**: any formula/cask/tap not declared there is uninstalled on the next mac rebuild. When marcus mentions installing a mac app, it must be declared or it will vanish. **Homebrew 6 refuses third-party taps that aren't trusted on the machine** — a declared tap the mac hasn't trusted kills activation at the brew-bundle step ("Refusing to load formula ... from untrusted tap") *before Home Manager or secrets run*, which presents as a totally broken switch (2026-08-01, the pinentry-touchid leftover). No taps are declared today. Since nix-homebrew arrived (below), a tap's trust entry can be declared with it — `nix-homebrew.trust.{taps,casks,formulae,commands}` — so a tap no longer needs a hand-run `brew trust` on each mac; removing an entry does NOT revoke it, that still needs `brew untrust`. Core formulae remain the simpler path.

- **Homebrew itself is nix-managed** (`nix-homebrew` in `modules/darwin/homebrew.nix`): it owns `/opt/homebrew` and pins brew's version through the flake, so `brew --version` moves on `nix flake update` and never on self-update. Consequences: `brew doctor` permanently warns "Missing git origin remote" right before its own "managed by Nix" line — expected, not a fault; `brew update` still exits 0 against the read-only store path, so `onActivation.autoUpdate` is unaffected. Taps stay mutable deliberately — pinning them means carrying homebrew-core and homebrew-cask as flake inputs (~1.6 GB, pushed to daily), and pinning a cask's definition still doesn't pin what it downloads.
- **The usernames differ per machine** — `marcus` on Linux, `marcussanchez` on the mac; don't "unify" them. The single source of truth is `identity.username`, assigned in each platform's `users.nix` (option declared in `modules/common/identity.nix`, with `identity.home` derived); modules read `config.identity.*` instead of hardcoding or branching on isDarwin. The assignment must stay an unconditional literal — consumers use it in dynamic attr names, and a conditional value invites infinite recursion (identity.nix's header has the guard rails).
- **stateVersions must never change — they are not "the version we're on".** Per machine: `system.stateVersion` "25.05" (WSL), "26.05" (tuf and bedroom-nixos), `6` (darwin); `home.stateVersion` lives in each entry point ("25.05" everywhere except desktop.nix's "26.05") and can never move back into `home/marcus/common/` — the machines were installed under different releases.

- **Desktop-stack rules (both bare-metal hosts), distilled from the absorbed repo's two hard-won days** — the full briefing is MERGE-NOTES.md in the archived `marcussanchez/tuf-nix-config`:
  - **Greeter/display-manager changes ship via `nixos-rebuild boot`, not `switch`** — switch kills the live session out from under the user.
  - **`niri validate` does NOT catch duplicate keybinds**; the compositor rejects the whole live reload instead. After editing niri.config.kdl check the journal, not just the validator. Session logs: `journalctl -t niri-session`.
  - **`dms ipc` exit codes lie** (0 even when a call lands before the shell is ready, SUCCESS while persisting nothing). Verify outcomes by querying state back, never by exit code or process existence. **And correct state can still render stale** (2026-08-06: session.json + `wallpaper getFor` both right while every monitor painted the old wallpaper) — when state and pixels disagree, restart the shell: `pkill quickshell`, then `niri msg action spawn -- dms run` (the supervisor may be long dead, so respawn explicitly). Verify pixels with `grim -o <output>` over SSH, not by asking state again.
  - The boot experience is several cooperating tricks (early-KMS nvidia initrd, plymouth `--retain-splash`, niriQuiet's systemd-cat rewrite, `systemd.show_status=false`, greeter `logs.save`) — `modules/desktop/boot.nix` + `desktop.nix` headers explain the web; change pieces together or not at all. `configurationLimit 10` is load-bearing (1 GB ESP, ~130 MB per early-KMS initrd).
  - **Group membership changes (input/uinput) need a relogin** — the session that ran the switch doesn't have them yet.
  - **Adwaita icons are a PREFERENCE, not a workaround.** `home/marcus/common/shell.nix` keeps `catppuccin.gtk.icon.enable = false` and `desktop/niri.nix` pins Adwaita: with Adwaita named, apps fall through to their own hicolor icons (native look). Papirus was trialed on bedroom-nixos 2026-08-06 and proved technically fine — ghostty's tab bar renders; the old laptop breakage was Plasma-leftover fallout, not a Papirus deficiency — but its restyled app icons were rejected on looks. Re-enabling it is safe on clean installs; it is a taste decision, not a stability one.
  - Toolbox rewrites its `jetbrains-*.desktop` files on every IDE update — never hand-edit them; new IDEs need a DMS restart to be indexed.
  - When a GUI app misbehaves, run it from a terminal and read its output before theorizing about the launcher.
- The zsh `initContent` in `home/marcus/common/shell.nix` is wrapped in `lib.mkOrder 1200` on purpose, so marcus's keybindings land after zoxide/atuin's shell hooks. Don't drop the ordering when editing it.
