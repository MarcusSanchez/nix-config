# The desktop: Ryoku (Hyprland + Quickshell, the maintained NixOS
# port's module) — every bare-metal host runs it, so it lives in the
# aggregator like the rest of the desktop stack. It owns both sessions
# (niri and Hyprland), the login screen (SDDM wearing its theme), the
# wallpaper, theming and locker. Promoted from a hero-only trial after
# the shell-variety era; the niri + DMS world it replaced is whole in
# git history.
#
# How its config space works: niri reads exactly one entrypoint
# (~/.config/niri/config.kdl), laid and maintained by Ryoku's
# materializer — per-user tweaks belong in ~/.config/niri/user.kdl
# (machine-owned, the last word of their include chain), hand-pinned
# display modes in monitors_user.kdl beside it, neutral settings in
# ~/.config/ryoku/desktop.json (the Hub's store). The materializer
# (ryoku-materialize.service at every Ryoku session start; also
# `ryoku materialize` by hand) REPLACES whatever sits at a shipped
# path — wanted, now that Ryoku owns the config space. The one
# HM-managed file it still collides with is btop.conf (force in
# home/marcus/nixos/ryoku.nix); seeds like nvim/ and ghostty/config
# respect existing files and symlinks by upstream's own design.
# BOOTSTRAP on a machine new to Ryoku: the niri session has no config
# until the first materialization, which only their session start
# runs — so after the first switch, either log into Hyprland once (its
# session-start materialize lays the niri side too) or run the
# packaged materializer by hand.
#
# What the module drags in and why it's accepted:
#   - programs.niri gets enabled with the package mkForce'd to Ryoku's
#     niri, built from the port's own locked nixpkgs (no follows — see
#     flake.nix): niri versions ride the port's lock, not the host's.
#   - virtualisation.docker (mkDefault, enableOnBoot=false) for its
#     Cobalt workflow; hardware.bluetooth General.Experimental
#     (mkDefault true) — hero's MT7927 latch canary is the thing to
#     watch there (hosts/hero/bluetooth.nix).
#   - users.defaultUserShell leans fish (mkOverride 900); the account's
#     explicit zsh in ./users.nix outranks it. `shell = "fish"` below
#     is upstream's default AND the safe choice: the zsh variant
#     appends Ryoku's prompt/alias init to /etc/zshrc, which would
#     fight the HM zsh setup in every session.
{
  inputs,
  lib,
  ...
}:

{
  imports = [ inputs.ryoku.nixosModules.default ];

  programs.ryoku = {
    enable = true;
    shell = "fish";
  };

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

  # The login screen is ./greeter.nix (the recreated dms-greeter —
  # SDDM with Ryoku's theme was tried and couldn't rotate the portrait
  # or filter screens; its theming block in their module sits inert
  # while sddm stays off).

  # Avatars persist through AccountsService (the greeter reads it;
  # Ryoku's profile page writes it)
  services.accounts-daemon.enable = true;

  # backs HM's dconf.settings and the gsettings calls Ryoku's session
  # bootstrap makes (color-scheme, gtk-theme)
  programs.dconf.enable = true;

  # swaylock is the session's fallback locker (qylock is primary); it
  # authenticates via PAM, and without this entry unlocking fails.
  # Pairs with programs.swaylock in home/marcus/nixos/ryoku.nix.
  security.pam.services.swaylock = { };

  # session apps that ignore SIGTERM once the compositor is gone
  # otherwise hold the user manager for its default 90s at shutdown —
  # every session app here stops in a second or two, so bound the wait
  # and let the SIGKILL land early
  systemd.user.settings.Manager.DefaultTimeoutStopSec = "15s";
}
