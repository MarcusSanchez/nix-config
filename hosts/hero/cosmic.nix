# COSMIC with niri as its compositor — a TRIAL session beside the
# regular niri one, picked at the greeter ("COSMIC (niri)"; plain
# "COSMIC" also appears, cosmic-comp and all, since the DE has to be
# installed either way). Upstream calls this arrangement unsupported
# alpha (Drakulix/cosmic-ext-extra-sessions); this file is its nix
# rendering and retires by deletion.
#
# How the pieces fit: cosmic-session grew alternative-compositor argv
# upstream (epoch 1.8 — `cosmic-session niri`, trailing args handed to
# the compositor), and Drakulix's cosmic-ext-alternative-startup shim,
# spawned INSIDE the compositor, supplies the session API
# cosmic-session waits on. The session runs niri against its OWN
# store-built config — the shared connector-keyed outputs plus a
# starter bind set — so the regular session's spawns (DMS, xremap,
# wallpapers) stay out of COSMIC's way; cosmic-panel, the launcher and
# friends come from the DE. The explicit session bus export keeps
# cosmic-session on systemd's user bus instead of dbus-run-session
# forking a second, divergent one. HOST-level: a trial belongs to the
# machine trying it.
{ pkgs, ... }:

let
  cosmic-ext-alternative-startup = pkgs.rustPlatform.buildRustPackage rec {
    pname = "cosmic-ext-alternative-startup";
    version = "0-unstable-2024-11-24";
    src = pkgs.fetchFromGitHub {
      owner = "Drakulix";
      repo = "cosmic-ext-alternative-startup";
      rev = "8ceda00197c7ec0905cf1dccdc2d67d738e45417";
      hash = "sha256-0kqn3hZ58uQMl39XXF94yQS1EWmGIK45/JFTAigg/3M=";
    };
    cargoHash = "sha256-DeMkAG2iINGden0Up013M9mWDN4QHrF+FXoNqpGB+mg=";
  };

  # the session's niri config, DERIVED from the desk's real one at
  # build time so binds, layout and window rules (the frosted ghostty
  # included) are identical in both sessions — shedding exactly what
  # the DE replaces: every spawn-at-startup (DMS, swaybg, cliphist,
  # tpm-fido, the boot lock — cosmic-bg paints the wallpaper, the
  # panel is cosmic's). The host tail comes along spawn-stripped under
  # the stable name its include expects (its window rules — spotify's
  # full-width portrait — apply here too); the outputs include keeps
  # resolving because the shared file is copied beside. Two spawns are
  # appended: the session-API shim, and an env import + xremap bounce
  # — cosmic-session starts niri WITHOUT its --session wrapper, so
  # NIRI_SOCKET never reaches the user manager on its own, and a
  # blind xremap applies the per-app remaps everywhere (the `not:`
  # matchers pass vacuously with no focused-window feed). A bind edit
  # in niri.config.kdl reaches this session at the next rebuild, not
  # on save — the price of the store copy.
  cosmicNiriConfig =
    pkgs.runCommand "cosmic-niri-config"
      {
        dotfiles = ../../home/marcus/common/dotfiles;
      }
      ''
        mkdir -p $out
        cp "$dotfiles/niri.outputs.kdl" $out/
        sed '/^spawn-at-startup /d' "$dotfiles/niri.host.hero.kdl" > $out/niri.host.kdl
        sed '/^spawn-at-startup /d' "$dotfiles/niri.config.kdl" > $out/config.kdl
        {
          echo 'spawn-at-startup "${cosmic-ext-alternative-startup}/bin/cosmic-ext-alternative-startup"'
          echo 'spawn-at-startup "sh" "-c" "systemctl --user import-environment NIRI_SOCKET WAYLAND_DISPLAY DISPLAY; systemctl --user restart xremap"'
        } >> $out/config.kdl
      '';

  startCosmicNiri = pkgs.writeShellScript "start-cosmic-ext-niri" ''
    # stale failed units from a previous graphical session would break
    # this startup — same reset upstream's start script performs
    for unit in $(systemctl --user --no-legend --state=failed --plain list-units | cut -f1 -d' '); do
      partof="$(systemctl --user show -p PartOf --value "$unit")"
      case "$partof" in
        cosmic-session.target | graphical-session.target)
          systemctl --user reset-failed "$unit"
          ;;
      esac
    done
    export XDG_CURRENT_DESKTOP="COSMIC:niri"
    export XDG_SESSION_TYPE=wayland
    systemctl --user import-environment XDG_SESSION_TYPE XDG_CURRENT_DESKTOP
    if [ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
      export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    fi
    exec ${pkgs.cosmic-session}/bin/cosmic-session niri --config ${cosmicNiriConfig}/config.kdl
  '';

  cosmicNiriSession = pkgs.writeTextFile {
    name = "cosmic-ext-niri-session";
    destination = "/share/wayland-sessions/cosmic-ext-niri.desktop";
    text = ''
      [Desktop Entry]
      Name=COSMIC (niri)
      Comment=COSMIC on the niri compositor
      Exec=${startCosmicNiri}
      Type=Application
      DesktopNames=COSMIC;niri
    '';
    derivationArgs.passthru.providedSessions = [ "cosmic-ext-niri" ];
  };
in
{
  services.desktopManager.cosmic.enable = true;
  services.displayManager.sessionPackages = [ cosmicNiriSession ];
  environment.systemPackages = [ cosmic-ext-alternative-startup ];
}
