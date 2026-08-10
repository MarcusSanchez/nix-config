# User-side wiring of the niri session (the compositor itself and its
# portals come from programs.niri in modules/desktop/niri.nix): the
# config links the compositor reads, the fallback locker, and the
# xwayland bridge it spawns.
#
# niri hot-reloads its files on save; linked out-of-store so edits
# apply without a rebuild and land in the repo as ordinary git drift.
# niri.outputs.kdl must sit BESIDE config.kdl: its include is resolved
# relative to the symlink's directory, not the target's (verified on
# niri 26.04) — the same file also feeds the greeter's compositor via
# /etc/greetd/niri_overrides.kdl (modules/desktop/greeter.nix).
{
  config,
  pkgs,
  osConfig,
  ...
}:

{
  home.packages = [
    # X11 apps (JetBrains IDEs...) under niri: niri auto-spawns
    # xwayland-satellite when it's on PATH
    pkgs.xwayland-satellite
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

  # fallback lock (PAM entry in modules/desktop/niri.nix) in case the
  # DMS lock ever misbehaves — run `swaylock` from a terminal
  programs.swaylock.enable = true;
}
