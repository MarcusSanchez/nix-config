# User-side of the niri session (the compositor itself and its
# portals come from programs.niri in modules/nixos/niri.nix): the
# config links the compositor reads, the fallback locker, and every
# tool its binds and spawns expect on PATH.
#
# niri hot-reloads its files on save; linked out-of-store so edits
# apply without a rebuild and land in the repo as ordinary git drift.
# niri.outputs.kdl must sit BESIDE config.kdl: its include is resolved
# relative to the symlink's directory, not the target's (verified on
# niri 26.04) — the same file also feeds the greeter's compositor via
# /etc/greetd/niri_overrides.kdl (modules/nixos/greeter.nix).
{
  config,
  pkgs,
  osConfig,
  ...
}:

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

    # video wallpapers (the live spaceman on the 4K): mpv on the
    # background layer, spawned per-output
    pkgs.mpvpaper

    # the snipping tool (Mod+Shift+S in niri.config.kdl): slurp picks a
    # region, grim captures it, satty annotates (arrows/text/blur) and
    # copies via wl-clipboard. niri's built-in Print overlay stays for
    # quick unannotated shots; flameshot fights niri's portal situation.
    pkgs.grim
    pkgs.slurp
    pkgs.satty
    pkgs.wl-clipboard
    # notify-send, for the screenshot binds' best-effort toast (DMS is
    # the notification daemon that renders it)
    pkgs.libnotify

    # clipboard history: wl-paste watchers (spawned in niri.config.kdl)
    # store every copy; DMS's clipboard view (Mod+V) reads it back via
    # `cliphist list`
    pkgs.cliphist

    # MPRIS media control — the XF86AudioPlay/Prev/Next binds in
    # niri.config.kdl call this; without it media keys are wired to
    # nothing (the Wooting's skip keys included)
    pkgs.playerctl
    # same story for XF86MonBrightness keys, where a panel has them
    pkgs.brightnessctl

    # synthetic keystrokes via the virtual-keyboard protocol; Mod+W in
    # niri.config.kdl forwards Ctrl+W to the focused app (close tab)
    pkgs.wtype

    # per-application key remapping (alt+hjkl -> arrows outside vim-y
    # apps); the niri variant tracks the focused window over niri IPC.
    # Config: dotfiles/xremap.yml, spawned in niri.config.kdl.
    (pkgs.xremap.override { withVariant = "niri"; })

    # TPM-backed virtual FIDO2 key (system plumbing in
    # modules/nixos/security.nix, spawned in niri.config.kdl). It
    # shells out to a bare `pinentry` for the touch-confirmation
    # prompt — the alias beside it points that name at the gnome3 flavor,
    # which prompts via gcr.
    pkgs.tpm-fido
    (pkgs.runCommand "pinentry-alias" { } ''
      mkdir -p $out/bin
      ln -s ${pkgs.pinentry-gnome3}/bin/pinentry-gnome3 $out/bin/pinentry
    '')

    # shell-ipc: the shell-neutral verbs niri.config.kdl's binds call.
    # Routes to whichever shell is running by asking each shell's IPC
    # directly (not pgrep: wrapper comms lie — ".noctalia-wrapp" — and
    # a name match would self-match shells quoting the word): noctalia
    # 5.x first, then 4.x, DMS otherwise — one shared bind set serves
    # every session. On hosts without noctalia the probes are clean
    # command-not-founds = DMS branch. The islocked verb exits 0/1 for
    # the boot-lock loop; the 4.x shell exposes no runtime lock state,
    # so its branch reports "IPC reachable" — quickshell IPC fails
    # until the shell is up, which is exactly the readiness the loop
    # retries for (the true-readback exists for DMS's lying exits).
    (pkgs.writeShellScriptBin "shell-ipc" ''
      verb=$1
      if noctalia msg status >/dev/null 2>&1; then
        case "$verb" in
          spotlight)      exec noctalia msg panel-toggle launcher ;;
          lock)           exec noctalia msg session lock ;;
          islocked)       noctalia msg status 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '"locked": true' ;;
          powermenu)      exec noctalia msg panel-toggle session ;;
          control-center) exec noctalia msg panel-toggle control-center ;;
          clipboard)      exec noctalia msg panel-toggle clipboard ;;
          *)              echo "shell-ipc: unknown verb $verb" >&2; exit 64 ;;
        esac
      elif noctalia-shell ipc call state all >/dev/null 2>&1; then
        case "$verb" in
          spotlight)      exec noctalia-shell ipc call launcher toggle ;;
          lock)           exec noctalia-shell ipc call lockScreen lock ;;
          islocked)       noctalia-shell ipc call state all >/dev/null 2>&1 ;;
          powermenu)      exec noctalia-shell ipc call sessionMenu toggle ;;
          control-center) exec noctalia-shell ipc call controlCenter toggle ;;
          clipboard)      exec noctalia-shell ipc call launcher clipboard ;;
          *)              echo "shell-ipc: unknown verb $verb" >&2; exit 64 ;;
        esac
      else
        case "$verb" in
          spotlight)      exec dms ipc call spotlight toggle ;;
          lock)           exec dms ipc call lock lock ;;
          islocked)       [ "$(dms ipc call lock isLocked 2>/dev/null)" = true ] ;;
          powermenu)      exec dms ipc call powermenu toggle ;;
          control-center) exec dms ipc call control-center toggle ;;
          clipboard)      exec dms ipc call clipboard toggle ;;
          *)              echo "shell-ipc: unknown verb $verb" >&2; exit 64 ;;
        esac
      fi
    '')
  ];

  xdg.configFile =
    let
      dotfiles = "${config.home.homeDirectory}/nix-config/home/marcus/common/dotfiles";
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

  # fallback lock (PAM entry in modules/nixos/niri.nix) in case the
  # DMS lock ever misbehaves — run `swaylock` from a terminal
  programs.swaylock.enable = true;
}
