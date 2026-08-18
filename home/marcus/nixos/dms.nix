# The shell: DankMaterialShell (quickshell-based) — bar, launcher,
# notifications, control center, lock screen and wallpaper-driven
# Material theming in one — spawned and bound in niri.config.kdl
# (spawn-at-startup "dms run", Mod+D / Alt+Space spotlight, Super+Alt+L
# lock). Its settings.json is linked into the repo below (same
# UI-managed-config pattern as zed/niri: edits made in the DMS settings
# UI land as git drift). Session *state* — wallpaper path, avatar,
# per-app usage — stays outside in ~/.local/state, machine-local by
# design. (noctalia fits the same slot; DMS is the deliberate pick.)
{
  config,
  pkgs,
  lib,
  ...
}:

let
  wallpaper = "${config.home.homeDirectory}/Pictures/Wallpapers/astronaut-jellyfish.jpg";
in
{

  # DMS caveat, same as the zed links: it may atomically replace
  # settings.json's link with a plain file on save; HM re-links and
  # hm-backups it on the next switch.
  xdg.configFile =
    let
      dotfiles = "${config.home.homeDirectory}/nix-config/home/marcus/common/dotfiles";
      link = f: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${f}";
      # custom DMS bar widgets (one dir per plugin id), linked out-of-store
      # like the rest of the rice so QML edits hot-reload without a rebuild.
      # A plugin only LOADS where plugin_settings.json (machine-local DMS
      # state, not managed here) has it enabled — a bar entry for a plugin
      # the machine hasn't enabled simply doesn't render, so the shared
      # dms.settings.json stays safe across hosts.
      plugins = "${config.home.homeDirectory}/nix-config/home/marcus/nixos/assets/dms-plugins";
      pluginLink = p: config.lib.file.mkOutOfStoreSymlink "${plugins}/${p}";
    in
    {
      "DankMaterialShell/settings.json".source = link "dms.settings.json";
      "DankMaterialShell/plugins/cpuCombo".source = pluginLink "cpuCombo";
      "DankMaterialShell/plugins/gpuCombo".source = pluginLink "gpuCombo";
    };

  # the wallpaper groups as spotlight results: type "wall", click, the
  # whole desk changes (wallpaper:group in home.packages below). DMS
  # indexes new entries on shell restart.
  xdg.desktopEntries = {
    wallpaper-space = {
      name = "Wallpaper: Space Desk";
      comment = "Stars on the sides, the animated spaceman in the middle";
      exec = "wallpaper:group space";
      icon = "preferences-desktop-wallpaper";
    };
    wallpaper-flake = {
      name = "Wallpaper: Flake Desk";
      comment = "The Nix flake on all three monitors";
      exec = "wallpaper:group flake";
      icon = "preferences-desktop-wallpaper";
    };
  };

  # Wallpaper and avatar, carried in the repo so a fresh desktop machine
  # looks like the others without hand-setting anything. The images live
  # in ./assets and are linked to stable paths under ~ — not referenced
  # by store path, because DMS records an ABSOLUTE path in its session
  # state and a store path would rot on the next GC.
  #
  # The avatar goes to ~/.face, the freedesktop convention
  # AccountsService falls back to when no icon has been set explicitly —
  # which is what the in-session readers (lock screen, control center)
  # resolve. The GREETER runs as its own user and cannot read ~/.face
  # through the 0700 home dir; modules/nixos/greeter.nix seeds
  # /var/lib/AccountsService/icons/ from the same asset for it. (Setting
  # it through `dms ipc call profile setImage` instead writes a
  # root-owned copy under /var/lib/AccountsService; that path stays
  # valid but isn't declarative.)

  # Point DMS at the wallpaper on a machine that hasn't got one yet.
  # Deliberately only when the recorded path is missing or gone: the
  # wallpaper is also a UI-driven choice (it drives matugen theming), and
  # re-asserting it on every switch would stomp a deliberate change.
  # session.json is patched directly so this works before the shell is
  # up (swaybg reads the same key at session start); the ipc call is for
  # immediate effect when DMS happens to be running.
  home = {
    packages = [
      pkgs.dms-shell
      # dms spawns `qs` from PATH; its package doesn't bundle quickshell
      pkgs.quickshell
      # backs dms's system-monitor widgets (cpu/mem/process list)
      pkgs.dgop
      # backs dms's wallpaper-driven dynamic theming; without it on PATH,
      # theme generation silently does nothing
      pkgs.matugen

      # whole-desk wallpaper sets in one action: three setFor calls
      # (per-monitor session state, same as picking by hand) plus the
      # animated layer commanded into a known state via
      # mpvpaper:toggle's on/off verbs (niri.nix). Surfaced in the
      # spotlight through the xdg.desktopEntries below — that is the
      # clickable "menu" side of the command. Adding a group = one
      # case here + one desktop entry. Colon name = the
      # file-inside-a-derivation shape.
      (pkgs.runCommand "wallpaper-group" { } ''
        mkdir -p $out/bin
        install -m755 ${pkgs.writeShellScript "wallpaper-group" ''
          W="$HOME/Pictures/Wallpapers"
          case "''${1:-}" in
            space)
              dms ipc call wallpaper setFor DP-1 "$W/space-stars-2560x1440.jpg" >/dev/null
              dms ipc call wallpaper setFor DP-2 "$W/space-stars-1080x1920.jpg" >/dev/null
              dms ipc call wallpaper setFor DP-3 "$W/astronaut-jellyfish.jpg" >/dev/null
              mpvpaper:toggle on >/dev/null
              echo "wallpaper group: space"
              ;;
            flake)
              for o in DP-1 DP-2 DP-3; do
                dms ipc call wallpaper setFor "$o" "$W/nix-flake.png" >/dev/null
              done
              mpvpaper:toggle off >/dev/null
              echo "wallpaper group: flake"
              ;;
            *)
              echo "usage: wallpaper:group space|flake" >&2
              exit 64
              ;;
          esac
        ''} "$out/bin/wallpaper:group"
      '')
    ];

    file = {
      "Pictures/Wallpapers/astronaut-jellyfish.jpg".source = ./assets/astronaut-jellyfish.jpg;
      # spaceman-free stills for the bedroom desk's side monitors: frame
      # captures from the live spaceman loop's measured-clean star fields
      # (x 0-1010 and 2740-3840 of the 4K source), chosen for comets and
      # composed so every comet flies top-left to bottom-right — mirrored
      # filler pieces are comet-free by audit, since a mirror would
      # reverse the direction (one sub-threshold streak was inpainted out
      # for exactly that reason). The 1440p is a four-column mosaic with
      # 80px gradient-feathered seams; the portrait is a single native
      # rip. Only the middle monitor animates (mpvpaper in
      # niri.host.naut-dt.kdl); these are the sides' whole
      # wallpaper now, not just the fallback. Assigned per-monitor via
      # `dms ipc call wallpaper setFor <connector> <path>` — recorded in
      # machine-local session state, so another desktop host (which would
      # also get these files) is unaffected.
      "Pictures/Wallpapers/space-stars-2560x1440.jpg".source = ./assets/space-stars-2560x1440.jpg;
      "Pictures/Wallpapers/space-stars-1080x1920.jpg".source = ./assets/space-stars-1080x1920.jpg;
      # the flake group's single image (wallpaper:group above)
      "Pictures/Wallpapers/nix-flake.png".source = ./assets/nix-flake.png;
      "Pictures/avatar-spaceman.png".source = ./assets/avatar-spaceman.png;
      ".face".source = ./assets/avatar-spaceman.png;
    };

    activation.dmsWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      state="$HOME/.local/state/DankMaterialShell/session.json"
      current=$([ -f "$state" ] && ${pkgs.jq}/bin/jq -r '.wallpaperPath // ""' "$state" || echo "")
      if [ ! -f "$current" ]; then
        if [ -f "$state" ]; then
          run ${pkgs.jq}/bin/jq --arg p "${wallpaper}" '.wallpaperPath = $p' "$state" > "$state.tmp" \
            && run mv "$state.tmp" "$state"
        else
          # a truly fresh machine has no session state yet — the exact case
          # this hook exists for. Seed a minimal one; DMS merges its
          # defaults into an existing file on startup. (Skip-if-absent
          # alone leaves a fresh machine's wallpaper empty.)
          run mkdir -p "$(dirname "$state")"
          run sh -c 'printf %s "{\"wallpaperPath\": \"${wallpaper}\"}" > "$1"' _ "$state"
        fi
        ${pkgs.dms-shell}/bin/dms ipc call wallpaper set "${wallpaper}" >/dev/null 2>&1 || true
      fi
    '';
  };
}
