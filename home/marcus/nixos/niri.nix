# User-side of the niri session (the compositor itself and its
# portals come from programs.niri in modules/nixos/niri.nix): the
# config links the compositor reads, the fallback locker, and every
# tool its binds and spawns expect on PATH.
#
# niri hot-reloads its files on save; linked out-of-store so edits
# apply without a rebuild and land in the repo as ordinary git drift.
# niri.outputs.kdl must sit BESIDE config.kdl: its include is resolved
# relative to the symlink's directory, not the target's. The greeter's compositor does NOT read it — its layout
# is the per-host greeterOutputs option (modules/nixos/greeter.nix),
# kept in step by hand.
{
  config,
  pkgs,
  osConfig,
  ...
}:

let
  # niri variant: tracks the focused window over niri IPC to gate the
  # per-app remaps
  xremapNiri = pkgs.xremap.override { withVariant = "niri"; };

  # where every screenshot lands; must stay the directory of
  # screenshot-path in niri.config.kdl, which screenshot-niri watches
  screenshotDir = "$HOME/Pictures/Screenshots";
in
{
  # Everything the session expects on PATH: what niri.config.kdl's
  # binds and spawn-at-startup lines call by name (removing one
  # silently breaks its bind rather than erroring), plus the xwayland
  # bridge niri spawns itself.
  home.packages = [
    # X11 apps (JetBrains IDEs...) under niri: niri auto-spawns
    # xwayland-satellite when it's on PATH
    pkgs.xwayland-satellite

    # instant wallpaper under quickshell's: covers the startup gap
    # before DMS's wallpaper layer maps (spawned in niri.config.kdl
    # with the path read from DMS's session state)
    pkgs.swaybg

    # the Print bind in niri.config.kdl: slurp picks a region, grim
    # captures it, screenshot-copy below takes the result.
    pkgs.grim
    pkgs.slurp
    # notify-send, for the screenshot binds' best-effort toast (DMS is
    # the notification daemon that renders it)
    pkgs.libnotify

    # MPRIS media control — the XF86AudioPlay/Prev/Next binds in
    # niri.config.kdl call this; without it media keys are wired to
    # nothing (the Wooting's skip keys included)
    pkgs.playerctl

    # synthetic keystrokes via the virtual-keyboard protocol; Mod+W in
    # niri.config.kdl forwards Ctrl+W to the focused app (close tab)
    pkgs.wtype

    # per-application key remapping (alt+hjkl -> arrows outside vim-y
    # apps). Config: dotfiles/xremap.yml. On PATH for hand-runs; the
    # SESSION copy is the systemd user service below, NOT a
    # spawn-at-startup — see its comment for why.
    xremapNiri

    # hand a screenshot FILE to DMS's clipboard: a PNG on stdin is saved
    # under the screenshot directory first, an argument names an
    # existing file. DMS offers a file as path text + file URI + image,
    # so the shot pastes into text fields and file pickers as well as
    # image targets; a plain wl-copy (and niri's own screenshot actions)
    # offer only image/png, which those paste as nothing. The daemon
    # owns the offer, so nothing here has to outlive the bind. -q skips
    # the notification, for callers whose capture tool already posted
    # one.
    (pkgs.writeShellScriptBin "screenshot-copy" ''
      quiet=
      if [ "$1" = "-q" ]; then quiet=1; shift; fi
      if [ $# -gt 0 ]; then
        f="$1"
      else
        mkdir -p "${screenshotDir}"
        f="${screenshotDir}/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png"
        cat > "$f"
        [ -s "$f" ] || { rm -f "$f"; exit 0; }
      fi
      # the daemon's socket carries its pid; a stale one from a previous
      # instance refuses the connection and is skipped
      for sock in "$XDG_RUNTIME_DIR"/danklinux*.sock; do
        ${pkgs.jq}/bin/jq -nc --arg p "$f" \
          '{id: 1, method: "clipboard.copyFile", params: {filePath: $p}}' \
          | ${pkgs.socat}/bin/socat -t 2 - "UNIX-CONNECT:$sock" 2>/dev/null \
          | grep -q '"success":true' && break
      done
      [ -n "$quiet" ] || notify-send -i "$f" Screenshot 'Copied to clipboard + saved' 2>/dev/null
    '')

    # run one of niri's own screenshot actions (interactive picker,
    # screen, window) and route the file it saves through
    # screenshot-copy. niri gives no completion signal, so this waits for
    # a new, non-empty, no-longer-growing PNG to appear in the screenshot
    # directory; cancelling the picker produces no file and the wait
    # simply expires. niri posts its own "Screenshot captured"
    # notification, so the copy runs quiet.
    (pkgs.writeShellScriptBin "screenshot-niri" ''
      mkdir -p "${screenshotDir}"
      before=$(ls -t "${screenshotDir}" | head -1)
      niri msg action "$1" || exit 1
      for _ in $(seq 1 600); do
        sleep 0.1
        newest=$(ls -t "${screenshotDir}" | head -1)
        [ -n "$newest" ] && [ "$newest" != "$before" ] || continue
        f="${screenshotDir}/$newest"
        size=0
        while [ "$size" = 0 ] || [ "$(stat -c %s "$f")" != "$size" ]; do
          size=$(stat -c %s "$f")
          sleep 0.1
        done
        exec screenshot-copy -q "$f"
      done
    '')

    # spawn a command and land its window left of the current column
    # (Mod+Shift+T in niri.config.kdl). niri has no open-left, so this
    # waits for the new window to take focus and moves its column
    # once; refocusing elsewhere during the wait window moves that
    # column instead — accepted for fast-launching apps.
    (pkgs.writeShellScriptBin "niri-spawn-left" ''
      prev=$(niri msg --json focused-window 2>/dev/null | ${pkgs.jq}/bin/jq -r '.id // empty')
      "$@" >/dev/null 2>&1 &
      for _ in $(seq 1 50); do
        sleep 0.1
        cur=$(niri msg --json focused-window 2>/dev/null | ${pkgs.jq}/bin/jq -r '.id // empty')
        if [ -n "$cur" ] && [ "$cur" != "$prev" ]; then
          niri msg action move-column-left
          exit 0
        fi
      done
    '')
  ];

  xdg.configFile =
    let
      dotfiles = osConfig.identity.dotfiles;
      link = f: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${f}";
    in
    {
      "niri/config.kdl".source = link "niri.config.kdl";
      "niri/niri.outputs.kdl".source = link "niri.outputs.kdl";
      # the per-host tail config.kdl includes: hostname picks the
      # target, so each desktop machine reads its own rules from the
      # one shared repo (a new host must commit its file first)
      "niri/niri.host.kdl".source = link "niri.host.${osConfig.networking.hostName}.kdl";
    };

  # xremap as a session-bound user service, NOT a niri
  # spawn-at-startup: niri's spawn children land in
  # user@.service/app.slice and outlive the session, so a spawn-started
  # xremap would keep its exclusive evdev grab (EVIOCGRAB) past logout
  # and leave the next login without a keyboard. PartOf
  # graphical-session.target stops it when the session ends, releasing
  # the grab; WantedBy starts it with the session. Restart on-failure
  # covers a transient IPC hiccup.
  #
  # The wrapper exists because a user service snapshots the manager
  # environment at SPAWN, and at login xremap can win the race against
  # niri's NIRI_SOCKET import — it then runs blind: no focused-window
  # feed, the per-app `not:` matchers pass vacuously, and the alt-hjkl
  # remaps capture inside neovim/Zed/JetBrains. Reading the CURRENT
  # manager environment (and waiting briefly for the import) at exec
  # time makes the service immune to login ordering.
  systemd.user.services.xremap = {
    Unit = {
      Description = "Per-application key remapping (niri variant)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = toString (
        pkgs.writeShellScript "xremap-with-niri-socket" ''
          for _ in $(seq 1 30); do
            sock=$(systemctl --user show-environment | ${pkgs.gnused}/bin/sed -n 's/^NIRI_SOCKET=//p')
            [ -n "$sock" ] && [ -S "$sock" ] && break
            sleep 0.5
          done
          if [ -n "''${sock:-}" ] && [ -S "$sock" ]; then
            export NIRI_SOCKET="$sock"
          else
            echo "xremap: NIRI_SOCKET never appeared — running without focused-window tracking" >&2
          fi
          exec ${xremapNiri}/bin/xremap --watch=config,device ${osConfig.identity.dotfiles}/xremap.yml
        ''
      );
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
