# TRIAL: the Ryoku desktop (Hyprland + Quickshell, the maintained
# NixOS port's module) beside the regular niri/DMS session — picked at
# the greeter as "Hyprland", which Ryoku owns wholesale on this box:
# its config tree (~/.config/hypr) has no other owner here, so the
# whole product runs exactly as shipped. Its niri flavor is
# deliberately NOT used — niri's one config entrypoint
# (~/.config/niri/config.kdl) already belongs to the DMS session, and
# two desktops cannot share it. Retires by deleting this file + import
# + the HM half (home/marcus/nixos/ryoku.nix) + the flake input.
#
# What the module drags in and why it's accepted:
#   - programs.niri.package gets mkForce'd to Ryoku's niri, built from
#     the port's own locked nixpkgs (no follows — see flake.nix): the
#     regular niri/DMS session runs that build for the trial's
#     duration. Same major (26.04) as the host set today; the freeze
#     ends with the trial or the port's own lock bumps.
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
# The one real collision, and its containment: Ryoku's materializer
# (ryoku-materialize.service, run at every Ryoku session start; also
# `ryoku materialize` by hand) lays its config payload into ~/.config,
# REPLACING whatever sits at a shipped path — including the repo link
# at niri/config.kdl (their niri entrypoint, not a seed; seeds like
# nvim/ and ghostty/config respect existing files and symlinks, so
# those stay safe by upstream's own design). ExecStartPost below
# re-links it before anything else in the session can order after
# materialization; the HM half force-restores it (and the other
# replaced theming files) on every switch, which also self-heals
# `ryoku update` (its NixOS backend ends in a switch). The uncovered
# sliver: a hand-run `ryoku materialize`/`ryoku reload` mid-session
# leaves Ryoku's entrypoint in place until the next Ryoku session
# start or home-manager activation — if the niri session ever greets
# as Ryoku instead of DMS, that's what happened; rebuild or relog into
# Hyprland once.
{
  inputs,
  config,
  lib,
  pkgs,
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

  # A sibling oneshot rather than an ExecStartPost on their service —
  # the module already uses that slot for its qylock materializer, and
  # systemd unit options don't merge two definitions of it.
  systemd.user.services.ryoku-restore-niri-entrypoint = {
    description = "Re-link niri's config entrypoint after Ryoku materialization";
    wantedBy = [ "ryoku-session.target" ];
    after = [ "ryoku-materialize.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.writeShellScript "ryoku-restore-niri-entrypoint" ''
        ln -sfn ${config.identity.home}/nix-config/home/marcus/common/dotfiles/niri.config.kdl \
          "$HOME/.config/niri/config.kdl"
      ''}";
    };
  };
}
