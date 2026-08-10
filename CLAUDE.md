# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flake-based Nix configuration for a family of WSL NixOS boxes sharing one config (`naut-box`, `framework-dt`, `office-one`, `office-two` — user `marcus`, same toolchains, headless: a terminal into the fleet on whatever PC hosts the distro; the Windows sides are unmanaged on purpose), a bare-metal NixOS laptop (host `tuf-laptop`, user `marcus` — ASUS TUF Dash F15, niri + DankMaterialShell desktop, absorbed from the archived `marcussanchez/tuf-nix-config` repo whose git history holds the rejected Plasma/GNOME/SDDM experiments), a bare-metal desktop (host `naut-dt` — the dual-boot side of the PC that also hosts naut-box; same desktop session as the laptop, its own RTX 5080 facts), and a MacBook Air on nix-darwin + Determinate Nix (host `macbook-air`, user `marcussanchez`). On every machine the repo lives at `~/nix-config`; on Linux `/etc/nixos` is symlinked to it (what bare `nixos-rebuild` relies on), on the mac `/etc/nix-darwin` is. The GitHub repo is `MarcusSanchez/nix-config`; the weekly `system.autoUpgrade` on every WSL box builds from pushed main there, never from the working tree — so one push deploys to all of them. The mac and both bare-metal hosts have no autoUpgrade (`nh darwin switch -u` / `nh os switch -u` by hand — a desktop should never swap its compositor mid-session). GC runs daily on the Linux boxes and weekly as a launchd agent on the mac; every one of these timers catches up after downtime rather than skipping.

**Each NixOS host resolves its config by hostname**: `nixos-rebuild --flake /etc/nixos` with no `#attr` builds `nixosConfigurations.<hostname>`, as do `system.autoUpgrade` and `NH_FLAKE`. The flake attribute and `networking.hostName` must therefore stay equal — `flake.nix` keys each entry by hostname and passes it to the host module as `hostName` via `specialArgs`, so they cannot drift. Several attributes may point at the same host module; that's how an identical second box is added, as one line in `flake.nix` and nothing else. The Windows-side WSL distro name (`wsl -d <name>`) is a separate identifier NixOS never sees; installs keep the `.wsl` file's default name `NixOS`, since parameterizing it bought nothing (`--name` only matters if one PC hosts two distros — WSL refuses duplicates).

Claude Code sessions run on any of them — `uname` separates darwin from Linux, `hostname` separates the WSL boxes from each other (`uname` alone cannot). Each machine can build and activate only its own platform; the *other* platform's config can still be fully evaluated — do that after touching shared files, and flag cross-platform changes for marcus to activate on the other machine.

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
nix eval --raw '/etc/nix-darwin#nixosConfigurations.naut-box.config.system.build.toplevel.drvPath'
nix eval --raw '/etc/nix-darwin#nixosConfigurations.framework-dt.config.system.build.toplevel.drvPath'
nix eval --raw '/etc/nix-darwin#nixosConfigurations.tuf-laptop.config.system.build.toplevel.drvPath'
nix eval --raw '/etc/nix-darwin#nixosConfigurations.naut-dt.config.system.build.toplevel.drvPath'
                                               # eval the NixOS systems after touching modules/
                                               # or home/ (on any NixOS box, `nix flake
                                               # check` already covers every NixOS host; the office
                                               # attrs differ from framework-dt only by hostname)

# Both
nix flake check                                # validate before switching — always do this after edits
nix fmt                                        # format all nix files (nixfmt-tree)
nix flake update                               # bump inputs by hand (CI does it Sundays via
                                               # update-flake-lock.yml, gated on the full eval)
```

There are no tests; `nix flake check` (which evaluates every `nixosConfigurations` entry — all six: four WSL hosts and both bare-metal machines) + the darwin eval + a successful switch is the verification story. `./bin/config:check` runs the whole gate including the darwin eval. Each machine can switch only itself — changes for the others are flagged for the user to activate there.

## Architecture

Three layers per platform, wired in `flake.nix`. Flake inputs are passed everywhere as `specialArgs`/`extraSpecialArgs`, so any module can take `inputs` as an argument. Two nixpkgs inputs on purpose: `nixpkgs` (nixos-unstable, Linux) and `nixpkgs-darwin` (nixpkgs-unstable, where darwin caches populate first) — don't collapse them.

1. `hosts/` — the entries in `flake.nix`. The naming rule: dirs with hardware truth on disk are 1:1 with a machine and named by its EXACT hostname (`tuf-laptop/`, `naut-dt/` — hardware-configuration.nix, nvidia facts, lanzaboote); dirs without hardware truth are shareable KINDS (`wsl/`, `darwin/` — several flake attrs may point at one, and a per-machine fact that isn't hardware truth is a hostname list hardcoded at the option it gates: the super tier in secrets.nix, the rustdesk bridge in wsl/networking.nix). Host-specific values only (platform, `system.stateVersion`, `networking.hostName` from the `hostName` specialArg, and `homeEntryPoint` — the option `modules/common/home-manager.nix` reads to decide which home config this host's user gets; every host declares it).
2. `modules/` — four directories, each self-contained for its kind of machine: `common/` (both platforms — identity, secrets, the HM bridge, cross-platform CLIs), `nixos/` (the bare-metal machines' whole world: account, nix daemon, and the boot/niri/DMS desktop stack — **no default.nix on purpose**; the desktop hosts import its files DECISIVELY, and the import order in their lists is not cosmetic, merged-list options order by module position), `wsl/` (the WSL machines' whole world, aggregated by its default.nix — including its OWN users.nix/nix.nix/nix-ld.nix/packages.nix, duplicated with nixos/'s on purpose: **bad duplication beats bad abstraction**, each directory reasons alone), and `darwin/` (the mac). One PURPOSE per file everywhere: a purpose may span several related options (system.nix carries locale+fonts+bluetooth+printing+fwupd+power+wooting), but never becomes a grab-bag — that is how the old desktop.nix monolith grew. The sops-nix/HM platform module imports that make the sops.* and home-manager.* options exist are listed directly in the host modules (hosts/wsl and both desktop hosts), beside `modules/common`; `modules/darwin/default.nix` carries its own. The bridge sets `backupFileExtension = "hm-backup"`.
3. `home/marcus/` — Home Manager, mirroring the system layer's shape: `common/` (shared concern files, aggregated by its `default.nix`), `nixos/` (the desktop session's concern files — no default.nix, imported decisively) and `darwin/` (mac concern files), with `nixos.nix` / `wsl.nix` / `darwin.nix` as the per-world entry points (`home.stateVersion` + decisive imports; username/homeDirectory come from identity.* via the HM bridge; both desktop machines share nixos.nix the way the four WSL boxes share wsl.nix — it splits per-host the day a real divergence appears). `wsl.nix` imports only `./common` — WSL is a terminal into the shared toolchains, no GUI and no UI-managed links, and the Windows sides of those PCs are unmanaged on purpose. The bridges import the entry points, never `common/` directly.

Where things go: CLI tool for every machine → `modules/common/packages.nix`, or `home/marcus/common/packages.nix` if user-scoped; desktop-machine system config → `modules/nixos/<file>` + BOTH desktop hosts' import lists (order aligned); WSL system config → `modules/wsl/` + its aggregator; build tools → the owning directory's `packages.nix` (nixos and wsl each carry their own — duplication on purpose); mac GUI app → cask in `modules/darwin/homebrew.nix`; desktop GUI app → `home/marcus/nixos/apps.nix`; shared user config → concern file in `home/marcus/common/` + import in its `default.nix`; desktop-only user config → file in `home/marcus/nixos/`, imported from the shared nixos.nix entry; mac-only user config → `home/marcus/darwin/`. There is no `modules/darwin/packages.nix` — the mac gets its build tools from the Xcode CLT, so create that file only if a mac-only system package ever appears.

**Project-specific tooling never goes in this repo.** It belongs to the project, via devenv: `devenv init` there, declare `packages`/`languages.*`/`services.*` in its `devenv.nix`, and auto-load on `cd` with `use devenv` in its `.envrc` (or `use flake` for a plain flake devShell). This repo carries only what every machine needs. Its own operational commands (`secrets:edit`, `secrets:status`, `age:place`, `secrets:drop`, `config:check`) are plain executables in `bin/`, on PATH fleet-wide through `modules/common/bin.nix` — thin wrappers that run the LIVE working-tree scripts, so editing bin/ needs no rebuild. `./bin/<name>` also works directly, no wrapper involved.

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
                           config:check) — plain executables, on PATH
                           fleet-wide via modules/common/bin.nix's live
                           wrappers; secrets:drop is age:place's inverse
                           and must remove more than the two key files
                           (its header lists the full inventory)
.sops.yaml                 age recipients + tier rules (super first — first
                           match wins)
secrets/secrets.yaml       lower-tier ciphertext   secrets/super.yaml  trusted-only

hosts/{wsl,darwin}/       layer 1 — shareable KINDS (several flake attrs
                           may point at one); per-host values only
hosts/naut-dt/       the desktop PC, dual-booted beside Windows
                           (installed 2026-08-06). hardware-configuration
                           .nix is the generated truth from that install —
                           excluded from statix + deadnix like tuf's,
                           regenerate don't edit. RTX 5080 — the shared
                           modules/nixos/nvidia.nix fits it as-is
  default.nix              the machine's whole statement, quirks
                           included: boot-splash-on-one-monitor (side
                           connectors kernel-forced off through
                           plymouth + the wake-side-monitors oneshot —
                           the d-force is permanent for compositors
                           otherwise), WoL armed via a systemd.network
                           link file keyed by MAC, and the
                           reboot-windows command (one-shot BootNext by
                           label lookup — no firmware menus)
  lanzaboote.nix           Secure Boot, LIVE since install — a separate
                           file ON PURPOSE: a reinstall must comment its
                           import out until `sbctl create-keys` has run
                           (one line, one #). On a
                           reinstall, comment the import out until
                           `sbctl create-keys` has run, or the bootloader
                           install (and nixos-install with it) fails.
                           The working MSI ceremony (its header):
                           firmware "Delete all Secure Boot variables" =
                           TRUE Setup Mode (delete-PK-only leaves db/KEK
                           immutable), then runtime `sbctl enroll-keys
                           --microsoft` succeeds; fwupd restores the
                           dropped dbx afterwards
hosts/tuf-laptop/           the laptop: per-host values + its hardware truth
                           (MUX-discrete RTX 3070 — the shared
                           modules/nixos/nvidia.nix fits it as-is)
  hardware-configuration.nix  generated (nixos-generate-config) — excluded
                           from statix (statix.toml) and deadnix
                           (config:check + check.yml), regenerate don't edit

modules/common/            default.nix packages.nix (cross-platform CLIs
                           + the claude-code overlay and package)
  bin.nix                  the repo's bin/ scripts on PATH everywhere —
                           wrappers exec the LIVE working tree (edits
                           need no rebuild) and return the caller to
                           their starting directory; also the
                           reboot-windows command, hostname-gated to
                           the dual-boot desktop
                           identity.nix secrets.nix home-manager.nix —
                           the identity option, the shared sops config
                           and the HM bridge (platform files are shims)
  secrets.nix              also carries the super tier: fly_token is
                           declared only for the hostnames hardcoded at
                           its declaration, which must track
                           .sops.yaml's recipients and key reality (the
                           comment there says why a mismatch loses
                           everything)
modules/nixos/             the bare-metal machines' world — NO aggregator
                           on purpose: both desktop hosts import these
                           files DECISIVELY, and the order of the desktop
                           run in their lists is not cosmetic (merged-list
                           options order by module position; keep the two
                           hosts' lists aligned)
  packages.nix             build tools + ghostty.terminfo (fixes TERM for
                           sessions ssh-ing *into* this box) + the
                           desk-only tools (ethtool/libsecret/watchman)
  users.nix                the account, groups included (input/uinput for
                           xremap, networkmanager pairing with
                           ./networking.nix) + hardware.uinput
  nix.nix                  daemon settings + daily GC (no ssh module —
                           one existed only to make the host key that
                           sops used before the single-key move)
  users.nix nix-ld.nix     the WSL boxes' own copies — duplicated with
  packages.nix             modules/nixos/'s on purpose (bad duplication
                           beats bad abstraction; each directory reasons
                           alone). packages.nix here has no desk tools
  wsl.nix keyring.nix      keyring = gnome-keyring for headless secretspec
                           (the desktop gets its keyring via niri instead)
  nix.nix                  daemon settings + GC + the weekly autoUpgrade
                           deploy timer (WSL only, deliberately not the
                           laptop — Constraints)
  networking.nix           NOT in the aggregator — host-level: the tailscale
                           node + the systemd-resolved config MagicDNS
                           needs on WSL (Constraints), and the
                           tailscale-serve doorway to the Windows side's
                           RustDesk direct-access port (21118) on a
                           hardcoded hostname list — one-time
                           Windows-side checkbox, the comment has the
                           ceremony

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
                           home/marcus/nixos/assets/. Ships via `nixos-rebuild
                           boot`, never switch
  system.nix               machine-level settings and services:
                           timezone/locale, fonts, pipewire (allowed-rates
                           is a device-intersected MENU, not a forced
                           rate), bluetooth, CUPS, fwupd
                           (the dbx-restore story), upower +
                           power-profiles-daemon (DMS widgets fail
                           QUIETLY without them), wooting udev rules
                           (deliberately not hardware.wooting.enable —
                           it bundles the app)
  networking.nix           NetworkManager + the LAN firewall policy (dev
                           ports) + the tailscale block whose
                           trustedInterfaces catch-all the tight LAN
                           port list leans on
  boot.nix                 Plymouth + retain-splash handoff to the greeter —
                           several cooperating tricks, see its header and
                           Constraints before touching ANY of it (also
                           carries zramSwap, independent of that web)
  nix-ld.nix               the two shims for non-nix binaries, both for
                           the JetBrains/Toolbox story: nix-ld (enable +
                           the X11/GTK/NSS/JCEF library list —
                           empirically derived, do not trim; header has
                           the ldd recipe; libraries CONCATENATE with the
                           module's base set) and
                           envfs (/bin + /usr/bin as a FUSE mount
                           resolving shebangs against PATH, so Toolbox's
                           generated #!/bin/bash launchers run; desktop
                           only — not handed to the unattended WSL boxes)
  security.nix        tpm-fido + libfido2 udev rules;
                           the tpm-fido rules must sort BEFORE
                           70-uaccess.rules — numbered package file, NOT
                           services.udev.extraRules (lands at 99-, too late)
  nvidia.nix               the shared driver shape (every desktop host
                           drives its panel off a discrete NVIDIA GPU):
                           early-KMS initrd, open modules, mkDefault
                           scalars as the host override point. The two
                           LISTS stay normal priority on purpose —
                           hardware-configuration.nix defines
                           initrd.kernelModules = [ ] at priority 100,
                           so mkDefault there would silently drop early
                           KMS
                           (networking.nix carries the tailscale block —
                           trustedInterfaces is the tailnet catch-all its
                           tight LAN port list leans on; swaylock's PAM
                           entry lives in niri.nix with the session it
                           unlocks)
modules/darwin/
  default.nix              aggregator
  nix.nix                  nix.enable = false (Constraints)
  networking.nix           OSS tailscaled as a launchd daemon, so the mac
                           serves Tailscale SSH like the WSL boxes (the
                           sandboxed GUI builds can't). NEVER re-add the
                           tailscale-app cask while this is on — one
                           tailscaled per mac. nix-darwin#1688 recovery
                           command is in the file header
  homebrew.nix             cleanup = "zap" + nix-homebrew, which owns the
                           prefix and pins brew's version (Constraints)
  system.nix               fonts + Touch ID sudo + Remote Login (the password-auth
                           fallback for when tailscaled is down — no
                           authorized_keys exist anywhere any more)
  users.nix

home/marcus/
  nixos.nix wsl.nix darwin.nix  entry points — the HM bridges
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
    packages.nix           user CLIs + comma with its prebuilt nix-index
                           db + the modern-unix staples that carry shell hooks,
                           aliases or theming (fzf/bat/eza/yazi/lazygit/
                           btop as programs.* — catppuccin themes them via
                           the HM modules; ls->eza, cat->bat aliases,
                           interactive-only). The no-config siblings live
                           in modules/common/packages.nix
    dotfiles.nix           the UI-managed-config links + drift
                           auto-commit shared by the darwin and desktop
                           entries (message names the host via osConfig)
                           — NOT in common/default.nix on purpose: WSL
                           manages none of those files. ghostty gets TWO
                           links: the platform entry file AND the shared
                           base beside it (ghostty resolves the
                           config-file include against the entry's dir —
                           same trap as niri's include); its package
                           lives in nixos/apps.nix (the mac's is a cask)
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
                           consumes the same file via modules/nixos/
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
  darwin/                  (dotfiles.nix is imported straight from
                           the darwin.nix entry point — per-file symlinks
                           where the WSL side copies instead)
    nix.nix                user GC launchd agent + HM manpages off (they
                           warn on every eval under Determinate Nix)
    hammerspoon.nix        the mac's xremap — per-app remaps matched on
                           bundle id AND window title, which is why it is
                           not Karabiner (bundle ids only, and its DriverKit
                           driver is broken on macOS 26). Accessibility must
                           be granted BY HAND; until it is, the event tap
                           never starts and the keys silently do nothing
  nixos/                   the desktop session's concern files, imported
                           decisively by the shared nixos.nix entry
    theme.nix              GTK/dconf theme names + pointer cursor
                           (Adwaita everywhere; see Constraints for why
                           not Papirus)
    dms.nix                the shell stack (dms-shell/quickshell/dgop/
                           matugen — dms-shell does NOT bundle the
                           helpers; matugen missing = theme generation
                           silently no-ops) + out-of-store links for
                           dms.settings.json and the assets/dms-plugins/
                           bar widgets + wallpaper/avatar from ./assets,
                           linked to stable paths under ~ (DMS records
                           ABSOLUTE paths in session state — a store
                           path would rot at GC; avatar to ~/.face, the
                           AccountsService fallback)
    niri.nix               the session: out-of-store links for
                           niri/config.kdl, niri.outputs.kdl,
                           niri.host.kdl (target picked by hostname) +
                           swaylock fallback + everything the binds and
                           spawns expect on PATH — snipping
                           (grim/slurp/satty, Mod+Shift+S), cliphist,
                           playerctl, wallpapers (swaybg/mpvpaper),
                           xremap, tpm-fido, xwayland-satellite

    apps.nix
                           the GTK chrome and Windows-Terminal keybinds
```

## Constraints that are easy to violate

- **Never commit a decrypted secret, and never print one.** Credentials live age-encrypted in `secrets/` (`secrets:edit` / `secrets:edit super`; `.sops.yaml` lists recipients). The repo is public, so the ciphertext is world-readable — that's fine, but a plaintext slip is permanent in git history and means revoking at the provider. **Two files, and the trusted list is the tier**: `secrets.yaml` (gh low-scope token, croc, atuin) is opened by the roaming master key from Bitwarden — what `age:place` places on ordinary boxes; `super.yaml` (fly org token + future hot secrets) is opened ONLY by the per-machine keys of the trusted machines (each generated on-box, backed up nowhere — deliberately: vault compromise cannot open super) plus a buried paper-only recovery key. There is no tier option: a hostname list hardcoded at the fly_token declaration in `modules/common/secrets.nix` gates the super tier, and that list MUST track key reality — `sops-install-secrets` aborts the WHOLE install on the first file it cannot decrypt (`decryptSecrets` returns on first error), so declaring super.yaml on a master-key box loses every secret on it, not just the super ones. Consequences to respect: onboarding an ordinary box never touches `.sops.yaml` (place master, switch; `age:place` re-locks rbw afterward — the vault holds the super RECOVERY key, so an unlocked hour would bridge the tiers); enrolling/replacing a TRUSTED machine edits `.sops.yaml` + runs `sops updatekeys` on both files (updatekeys for `super.yaml` must run where an existing recipient lives) + adds the hostname to secrets.nix's hardcoded list; `secrets:drop` AND `age:place` both REFUSE on trusted boxes (capability probe: does the box's key open super.yaml) — drop would destroy the unbacked-up machine key, place would silently overwrite it with the master; **nothing unreissuable ever goes in `super.yaml`** — atuin_key stays in the lower tier so it remains Bitwarden-recoverable; the mac factory reset will destroy `&macbook-air` (re-enrollment joins that day's checklist). **A missing `keyFile` is fatal, not a fallback** (`sops-install-secrets`: "cannot read keyfile"), so a machine without a key fails the whole `setupSecrets` step — the expected first-switch error on a fresh box. Declared-but-missing VALUES are equally fatal ("the key 'x' cannot be found"), so a value lands in its yaml before or with its wiring.

- **`modules/wsl/networking.nix` is imported by the WSL host modules, NOT the wsl aggregator — never move it there.** Every WSL2 distro on a Windows PC shares one network namespace (same IP, ports, routing table), so two `tailscaled` instances fight over `tailscale0`, UDP 41641 and the `100.64.0.0/10` route. One tailnet node per PC — every host module imports it today only because each instance lives on a PC of its own. Two sharing a PC means the second drops the import, and that per-machine fact is exactly what the aggregator cannot express. Also **never install Tailscale on Windows while this is on** — traffic would be encapsulated twice and Tailscale packets don't fit inside Tailscale packets. Running it inside WSL is viable only because mirrored networking gives `eth1` an MTU of 1500 (NAT mode's 1280 breaks SSH and TLS while ping keeps working) and NixOS-WSL runs systemd as PID 1. The node is up only while WSL is — that's accepted, not a bug. (The mac and both bare-metal hosts are their own nodes — `modules/darwin/networking.nix` (OSS daemon, not the GUI app) and the tailscale block in `modules/nixos/networking.nix` (bare metal is always its own node; it trusts tailscale0 wholesale, which is why the LAN firewall list beside it stays tight); see the file map.)

- **Never manage `~/.config/nvim` through Nix, and never re-enable `programs.neovim`.** It is marcus's own LazyVim fork (github.com/marcussanchez/neovim-config), a normal mutable git checkout — lazy.nvim writes `lazy-lock.json` and marcus commits/pushes from there. `programs.neovim` generates its own `init.lua` and symlinks it over the checkout, silently breaking the whole editor (this happened once; the fix was deliberate). `home/marcus/common/neovim.nix` installs the stable nixpkgs binary via `home.packages`, clone-bootstraps the config if `~/.config/nvim` doesn't exist, and otherwise ff-only pulls it during activation (only when the tree is clean — never touch that safety check). (Marcus prefers stable over nightly; a nightly-overlay setup existed before commit ~2026-07 if ever needed again.)
- **Zig and ZLS must stay on matching versions or editor tooling breaks.** Both come from nixpkgs (`pkgs.zig` / `pkgs.zls` in `modules/common/packages.nix`), which builds zls against its own zig, so they stay in lockstep automatically — don't source one of them from somewhere else. If a just-released Zig is ever needed before nixpkgs catches up, the old two-input overlay approach (mitchellh/zig-overlay + zigtools/zls pinned ref) is in git history at `modules/nixos/zig.nix` before commit ~2026-07.
- **Rust must come via rustup, not nixpkgs rustc/cargo — RustRover refuses standalone toolchains.** (Tried the nixpkgs route once, 2026-07, had to revert.) On WSL, rustup's downloaded binaries are patched against one specific store glibc and die with ENOENT after a glibc bump + GC; the activation hook in `home/marcus/common/toolchains.nix` (one file, branched on `isDarwin`) reinstalls stable whenever glibc changes; on the mac there is no glibc problem, so that branch is only a first-run bootstrap. The same file gives JetBrains its GOROOT, linking `~/.toolchains/go` at `${pkgs.go}/share/go` so the IDE has a path that doesn't rot when a go update + GC retires the old store path. It was a `cp -RL` dereferenced copy until 2026-07-28 because `\\wsl$` used to expose Linux symlinks as untraversable reparse points (commit 46643f1); marcus confirmed a link works now, and the copy is in git history if that regresses. Now one symlink, and the whole file lives in `common/`, so every host gets it.
- **On the mac, `nix.enable = false` is load-bearing** — Determinate Nix owns the daemon and nix-darwin refuses to build otherwise. Never set system-side `nix.settings`/`nix.gc`/`nix.optimise` in `modules/darwin/`; user-level GC lives in `home/marcus/darwin/nix.nix` instead. Daemon-level settings (extra substituters and their keys) are therefore imperative on the mac, in `/etc/nix/nix.custom.conf` — Determinate's file, applied with `sudo launchctl kickstart -k system/systems.determinate.nix-daemon`. The WSL boxes get the same settings declaratively from `modules/nixos/nix.nix`.
- **If `programs.starship` is ever enabled again, set `catppuccin.starship.enable = false` with it.** `autoEnable` otherwise pulls in catppuccin's starship port, which reads its palette from a derivation built at *evaluation* time. That derivation is the target platform's, so evaluating the mac config from Linux — CI's ubuntu runner, or a WSL box — fails outright rather than degrading. It broke CI for three commits on 2026-07-30 and looked like a hostname problem. `nix flake check` never catches it, because that command doesn't touch `darwinConfigurations`.

- **`homebrew.nix` has `cleanup = "zap"`**: any formula/cask/tap not declared there is uninstalled on the next mac rebuild. When marcus mentions installing a mac app, it must be declared or it will vanish. **Homebrew 6 refuses third-party taps that aren't trusted on the machine** — a declared tap the mac hasn't trusted kills activation at the brew-bundle step ("Refusing to load formula ... from untrusted tap") *before Home Manager or secrets run*, which presents as a totally broken switch (2026-08-01, the pinentry-touchid leftover). No taps are declared today. Since nix-homebrew arrived (below), a tap's trust entry can be declared with it — `nix-homebrew.trust.{taps,casks,formulae,commands}` — so a tap no longer needs a hand-run `brew trust` on each mac; removing an entry does NOT revoke it, that still needs `brew untrust`. Core formulae remain the simpler path.

- **Homebrew itself is nix-managed** (`nix-homebrew` in `modules/darwin/homebrew.nix`): it owns `/opt/homebrew` and pins brew's version through the flake, so `brew --version` moves on `nix flake update` and never on self-update. Consequences: `brew doctor` permanently warns "Missing git origin remote" right before its own "managed by Nix" line — expected, not a fault; `brew update` still exits 0 against the read-only store path, so `onActivation.autoUpdate` is unaffected. Taps stay mutable deliberately — pinning them means carrying homebrew-core and homebrew-cask as flake inputs (~1.6 GB, pushed to daily), and pinning a cask's definition still doesn't pin what it downloads.
- **The usernames differ per machine** — `marcus` on Linux, `marcussanchez` on the mac; don't "unify" them. The single source of truth is `identity.username`, assigned in each platform's `users.nix` (option declared in `modules/common/identity.nix`, with `identity.home` derived); modules read `config.identity.*` instead of hardcoding or branching on isDarwin. The assignment must stay an unconditional literal — consumers use it in dynamic attr names, and a conditional value invites infinite recursion (identity.nix's header has the guard rails).
- **stateVersions must never change — they are not "the version we're on".** Per machine: `system.stateVersion` "25.05" (WSL), "26.05" (tuf and naut-dt), `6` (darwin); `home.stateVersion` lives in each entry point ("25.05" everywhere except desktop.nix's "26.05") and can never move back into `home/marcus/common/` — the machines were installed under different releases.

- **Desktop-stack rules (both bare-metal hosts), distilled from the absorbed repo's two hard-won days** — the full briefing is MERGE-NOTES.md in the archived `marcussanchez/tuf-nix-config`:
  - **Greeter/display-manager changes ship via `nixos-rebuild boot`, not `switch`** — switch kills the live session out from under the user.
  - **`niri validate` does NOT catch duplicate keybinds**; the compositor rejects the whole live reload instead. After editing niri.config.kdl check the journal, not just the validator. Session logs: `journalctl -t niri-session`.
  - **`dms ipc` exit codes lie** (0 even when a call lands before the shell is ready, SUCCESS while persisting nothing). Verify outcomes by querying state back, never by exit code or process existence. **And correct state can still render stale** (2026-08-06: session.json + `wallpaper getFor` both right while every monitor painted the old wallpaper) — when state and pixels disagree, restart the shell: `pkill quickshell`, then `niri msg action spawn -- dms run` (the supervisor may be long dead, so respawn explicitly). Verify pixels with `grim -o <output>` over SSH, not by asking state again.
  - The boot experience is several cooperating tricks (early-KMS nvidia initrd, plymouth `--retain-splash`, niriQuiet's systemd-cat rewrite, `systemd.show_status=false`, greeter `logs.save`) — `modules/nixos/boot.nix` + the hosts' headers explain the web; change pieces together or not at all. `configurationLimit 10` is load-bearing (1 GB ESP, ~130 MB per early-KMS initrd).
  - **Group membership changes (input/uinput) need a relogin** — the session that ran the switch doesn't have them yet.
  - **Adwaita icons are a PREFERENCE, not a workaround.** `home/marcus/common/shell.nix` keeps `catppuccin.gtk.icon.enable = false` and `desktop/theme.nix` pins Adwaita: with Adwaita named, apps fall through to their own hicolor icons (native look). Papirus was trialed on naut-dt 2026-08-06 and proved technically fine — ghostty's tab bar renders; the old laptop breakage was Plasma-leftover fallout, not a Papirus deficiency — but its restyled app icons were rejected on looks. Re-enabling it is safe on clean installs; it is a taste decision, not a stability one.
  - Toolbox rewrites its `jetbrains-*.desktop` files on every IDE update — never hand-edit them; new IDEs need a DMS restart to be indexed.
  - When a GUI app misbehaves, run it from a terminal and read its output before theorizing about the launcher.
- The zsh `initContent` in `home/marcus/common/shell.nix` is wrapped in `lib.mkOrder 1200` on purpose, so marcus's keybindings land after zoxide/atuin's shell hooks. Don't drop the ordering when editing it.
