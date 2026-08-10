# Wallpaper and avatar, carried in the repo so a fresh desktop machine
# looks like the others without hand-setting anything. The images live in
# ./assets and are linked to stable paths under ~ — not referenced by
# store path, because DMS records an ABSOLUTE path in its session state
# and a store path would rot on the next GC.
#
# The avatar goes to ~/.face, the freedesktop convention AccountsService
# falls back to when no icon has been set explicitly — which is what the
# in-session readers (lock screen, control center) resolve. The GREETER
# runs as its own user and cannot read ~/.face through the 0700 home
# dir; modules/desktop/greeter.nix seeds /var/lib/AccountsService/icons/
# from the same asset for it. (Setting it through `dms ipc call profile
# setImage` instead writes a root-owned copy under /var/lib/
# AccountsService; that path stays valid but isn't declarative.)
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
  home.file = {
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
    # niri.host.bedroom-nixos.kdl); these are the sides' whole
    # wallpaper now, not just the fallback. Assigned per-monitor via
    # `dms ipc call wallpaper setFor <connector> <path>` — recorded in
    # machine-local session state, so the laptop (which also gets these
    # files) is unaffected.
    "Pictures/Wallpapers/space-stars-2560x1440.jpg".source = ./assets/space-stars-2560x1440.jpg;
    "Pictures/Wallpapers/space-stars-1080x1920.jpg".source = ./assets/space-stars-1080x1920.jpg;
    "Pictures/avatar-spaceman.png".source = ./assets/avatar-spaceman.png;
    ".face".source = ./assets/avatar-spaceman.png;
  };

  # Point DMS at the wallpaper on a machine that hasn't got one yet.
  # Deliberately only when the recorded path is missing or gone: the
  # wallpaper is also a UI-driven choice (it drives matugen theming), and
  # re-asserting it on every switch would stomp a deliberate change.
  # session.json is patched directly so this works before the shell is
  # up (swaybg reads the same key at session start); the ipc call is for
  # immediate effect when DMS happens to be running.
  home.activation.dmsWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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
}
