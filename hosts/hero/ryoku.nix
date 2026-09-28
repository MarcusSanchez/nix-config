# The Ryoku desktop (Hyprland + Quickshell, the maintained NixOS
# port's module) — THE desktop on this machine, promoted from trial
# after the shell-variety era: it owns both sessions (niri and
# Hyprland), the login screen (its SDDM theme below — the shared
# dms-greeter is force-disabled here and keeps serving the DMS
# desktops), the wallpaper, theming and locker. niri reads exactly one
# config entrypoint (~/.config/niri/config.kdl), laid and maintained by
# Ryoku's materializer; per-user tweaks belong in ~/.config/niri/
# user.kdl (the machine-owned last word of their include chain —
# hero's carries the transferred muscle-memory binds and the frosted
# ghostty rule), hand-pinned display modes in monitors_user.kdl beside
# it, and neutral settings in ~/.config/ryoku/desktop.json (the Hub's
# store). The home half is home/marcus/ryoku.nix -> nixos/ryoku.nix.
# The way back to DMS is git history: the trial-era commits carry the
# link-restore machinery and the shared-entry wiring.
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
# into ~/.config, REPLACING whatever sits at a shipped path — wanted,
# now that Ryoku owns this desktop's config space. The one HM-managed
# file it still collides with is btop.conf (force in the home half);
# seeds like nvim/ and ghostty/config respect existing files and
# symlinks by upstream's own design, so those stay the repo's.
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

  # Ryoku's login screen: SDDM wearing the module's "ryoku" theme (the
  # module applies theme + Qt deps whenever sddm is enabled). The
  # shared dms-greeter (modules/nixos/greeter.nix) is force-disabled on
  # this host only; its niri_overrides/avatar plumbing stays inert.
  # defaultSession "niri" from that same file still applies — SDDM
  # preselects the niri session, which is Ryoku's. The plymouth
  # retain-splash handoff in modules/nixos/boot.nix is
  # greeter-agnostic and carries over.
  services.displayManager = {
    dms-greeter.enable = lib.mkForce false;
    sddm = {
      enable = true;
      wayland.enable = true;
    };
  };
}
