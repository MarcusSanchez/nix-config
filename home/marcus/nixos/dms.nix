# DankMaterialShell, the desktop shell. Theme and wallpaper CHOICE
# live in the settings UI (Mod+Comma) and land as git drift through
# the settings link below, the same UI-managed pattern as zed; what
# this file adds is the plumbing that makes the chosen palette
# PROPAGATE — matugen renders it into niri's focus ring, and DMS's own
# dankcolors ghostty theme (named in ghostty.linux.config) rides the
# same regeneration. The retired looks system — the wallpaper:<name>
# commands, per-look dms.theme jsons, the niri accent-sed — is whole
# in git history if ever wanted back. Spawned and bound in
# niri.config.kdl (spawn-at-startup "dms run", Alt/Mod+Space
# spotlight, Super+Alt+L lock). Session *state* — wallpaper path,
# avatar, per-app usage — stays outside in ~/.local/state,
# machine-local by design.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  xdg.configFile = {
    # DMS caveat, same as the zed links: it may atomically replace
    # settings.json's link with a plain file on save; HM re-links and
    # hm-backups it on the next switch. The target starts as an empty
    # object — DMS runs on its defaults and writes choices back through
    # the link.
    "DankMaterialShell/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/home/marcus/common/dotfiles/dms.settings.json";

    # niri's focus ring follows DMS's palette: whenever DMS runs matugen
    # (wallpaper changes and theme switches), it also runs the USER's
    # matugen config after its own, and this template renders the active
    # primary color into a tiny include that niri.config.kdl loads last —
    # niri hot-reloads when it changes. Three hard-won rules, each a
    # broken afternoon once: the toml stays comment-free plain ASCII (DMS
    # re-parses it when merging and choked on a nixfmt-escaped em-dash),
    # the empty [config] table is mandatory, and the paths must be
    # ABSOLUTE — DMS silently skips a template with ~-relative paths.
    "matugen/config.toml".text = ''
      [config]

      [templates.niri-accent]
      input_path = "${config.home.homeDirectory}/.config/matugen/templates/niri-accent.kdl"
      output_path = "${config.home.homeDirectory}/.config/niri/niri.accent.kdl"
    '';
    "matugen/templates/niri-accent.kdl".text = ''
      layout {
          focus-ring {
              active-color "{{colors.primary.default.hex}}"
          }
      }
    '';
  };

  home = {
    # niri hard-errors on a missing include, and matugen only writes the
    # accent file on its first run — seed it once (multiline on purpose:
    # KDL rejects an inline child block whose last node lacks a `;`).
    # Write-if-absent: matugen owns the file from then on, which is also
    # why it is NOT an xdg.configFile — HM would fight the rewrites.
    activation.seedNiriAccent = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      f="$HOME/.config/niri/niri.accent.kdl"
      [ -e "$f" ] || printf 'layout {\n    focus-ring {\n        active-color "#89b4fa"\n    }\n}\n' > "$f"
    '';

    packages = [
      pkgs.dms-shell
      # dms spawns `qs` from PATH; its package doesn't bundle quickshell
      pkgs.quickshell
      # backs dms's system-monitor widgets (cpu/mem/process list)
      pkgs.dgop
      # backs dms's wallpaper-driven dynamic theming; without it on PATH,
      # theme generation silently does nothing
      pkgs.matugen
    ];

    # The wallpaper collection, carried in the repo so a fresh desktop
    # machine has them to pick from — linked to stable paths under ~
    # rather than referenced by store path, because DMS records an
    # ABSOLUTE path in its session state and a store path would rot on
    # the next GC. Selection happens in the settings UI; nothing here
    # sets one. (avatar-spaceman.png sits beside them in ./assets,
    # unlinked, for whenever a profile picture is wanted again.)
    file = {
      # The bar's launcher glyph: launcherLogoMode "custom" in
      # dms.settings.json points here. Custom over "os" mode on purpose —
      # "os" renders the distro's Nerd Font glyph, whose ink sits
      # off-center in its em box; an SVG through IconImage centers true.
      # Same stable-path reasoning as the wallpapers below. Neither
      # shipped variant works as-is: the settings color override
      # colorizes by luminance, so the white SVG stays white no matter
      # the tint, and the colored one's two lambda tones survive as two
      # brightnesses — a lopsided-looking glyph. A uniform MID-GRAY ink
      # is the fix: one luminance, so the tint lands evenly and exact.
      # (launcherLogoSizeOffset 2 in settings is load-bearing too: the
      # colorization layer snaps the icon texture to whole pixels, and
      # at the default size that snap landed the glyph measurably left
      # of the pill's center — the +2 size flips the parity so the snap
      # lands centered. Remeasure if bar thickness or font scale moves.)
      ".local/share/dms/nix-snowflake.svg".source = pkgs.runCommand "nix-snowflake-gray.svg" { } ''
        sed 's/#ffffff/#808080/g' \
          ${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake-white.svg > $out
      '';

      "Pictures/Wallpapers/astronaut-jellyfish.jpg".source = ./assets/astronaut-jellyfish.jpg;
      "Pictures/Wallpapers/galaxy-waves.jpg".source = ./assets/galaxy-waves.jpg;
      "Pictures/Wallpapers/nix-flake.png".source = ./assets/nix-flake.png;
      "Pictures/Wallpapers/space-stars-2560x1440.jpg".source = ./assets/space-stars-2560x1440.jpg;
      "Pictures/Wallpapers/space-stars-1080x1920.jpg".source = ./assets/space-stars-1080x1920.jpg;
      "Pictures/Wallpapers/swirls.jpg".source = ./assets/swirls.jpg;
    };
  };
}
