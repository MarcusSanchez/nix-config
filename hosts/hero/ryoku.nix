# TRIAL: the Ryoku desktop (Hyprland + Quickshell, the maintained
# NixOS port's module) — and FOR NOW it owns niri too: both greeter
# doors (niri, Hyprland) land in Ryoku. niri reads exactly one config
# entrypoint (~/.config/niri/config.kdl), so handing Ryoku the niri
# session meant handing over that file — the HM half stops linking it
# on this host and Ryoku's materializer lays and maintains its own.
# DMS stays installed but dormant (its spawn-at-startup lived in the
# repo's niri config, which nothing reads here now); the other
# bare-metal hosts keep DMS-on-niri untouched. Giving niri back to
# DMS = revert the commit that handed it over (restores the HM link,
# a restore oneshot, and this header's previous form — git history
# has all three). Full retirement additionally deletes this file +
# import + the HM half (home/marcus/nixos/ryoku.nix) + flake input.
# Per-user tweaks under Ryoku-niri belong in ~/.config/niri/user.kdl,
# the machine-owned last word of their include chain; hand-pinned
# display modes in monitors_user.kdl beside it.
#
# What the module drags in and why it's accepted:
#   - programs.niri.package gets mkForce'd to Ryoku's niri, built from
#     the port's own locked nixpkgs (no follows — see flake.nix). With
#     the niri session handed to Ryoku that force is simply correct;
#     it means niri versions ride the port's lock, not the host's,
#     while the trial lasts.
#   - virtualisation.docker (mkDefault, enableOnBoot=false) for its
#     Cobalt workflow; hardware.bluetooth General.Experimental
#     (mkDefault true) — watch the MT7927 latch canary after this
#     lands (hosts/hero/bluetooth.nix).
#   - users.defaultUserShell leans fish (mkOverride 900); the account's
#     explicit zsh in modules/nixos/users.nix outranks it. `shell =
#     "fish"` below is upstream's default AND the safe choice: the zsh
#     variant appends Ryoku's prompt/alias init to /etc/zshrc, which
#     would fight the HM zsh setup in every session.
#
# The materializer (ryoku-materialize.service at every Ryoku session
# start; also `ryoku materialize` by hand) lays its config payload
# into ~/.config, REPLACING whatever sits at a shipped path. With
# niri handed over that's now wanted for the entrypoint; the HM half
# still force-restores the theming files it replaces (gtk settings,
# btop) on every switch. Seeds like nvim/ and ghostty/config respect
# existing files and symlinks by upstream's own design, so those
# stay the repo's.
{
  inputs,
  lib,
  ...
}:

{
  imports = [ inputs.ryoku.nixosModules.default ];

  # The module ships its GNOME-portal fix (UnsetEnvironment=GDK_BACKEND
  # so the portal's screencast backend survives Ryoku's global override)
  # as an environment.etc drop-in under systemd/user — a path this
  # nixpkgs builds as one directory symlink, which no etc entry can
  # nest under (their own pin predates the change; the etc build dies
  # on it). Same fix, delivered the way this nixpkgs wants it.
  environment.etc."systemd/user/xdg-desktop-portal-gnome.service.d/10-ryoku.conf".enable =
    lib.mkForce false;
  systemd.user.services.xdg-desktop-portal-gnome = {
    overrideStrategy = "asDropin";
    serviceConfig.UnsetEnvironment = "GDK_BACKEND";
  };

  programs.ryoku = {
    enable = true;
    shell = "fish";
  };
}
