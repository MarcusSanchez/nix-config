# What niri.config.kdl's binds and spawn-at-startup lines expect on
# PATH — one purpose, many tools: every package here exists because a
# bind or spawn in that file (or a sibling's) calls it by name, and
# removing one silently breaks its bind rather than erroring.
{ pkgs, ... }:

{
  home.packages = [
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
    # same story for the laptop's XF86MonBrightness keys
    pkgs.brightnessctl

    # synthetic keystrokes via the virtual-keyboard protocol; Mod+W in
    # niri.config.kdl forwards Ctrl+W to the focused app (close tab)
    pkgs.wtype

    # per-application key remapping (alt+hjkl -> arrows outside vim-y
    # apps); the niri variant tracks the focused window over niri IPC.
    # Config: dotfiles/xremap.yml, spawned in niri.config.kdl.
    (pkgs.xremap.override { withVariant = "niri"; })

    # TPM-backed virtual FIDO2 key (system plumbing in
    # modules/nixos/security-keys.nix, spawned in niri.config.kdl).
    # It shells out to a bare `pinentry` for the touch-confirmation
    # prompt — ./pkgs/pinentry-alias.nix points that name at the gnome3
    # flavor, which prompts via gcr.
    pkgs.tpm-fido
    (pkgs.callPackage ./pkgs/pinentry-alias.nix { })
  ];
}
