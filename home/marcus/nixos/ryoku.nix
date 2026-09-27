# TRIAL: the home half of the Ryoku desktop (system half:
# hosts/hero/ryoku.nix, where the whole story lives). Two jobs, both
# about Ryoku's materializer replacing files at its shipped paths — a
# replace, not a write-through, so the repo never takes the hit:
#
#   - On the Ryoku host, stop linking niri's config entrypoint at all:
#     Ryoku owns the niri session there for now, and its materializer
#     lays and maintains its own config.kdl. Without this release,
#     every switch would yank the session's config back out from
#     under it. Hostname-gated so the other bare-metal hosts keep
#     their DMS-on-niri link untouched.
#   - Everywhere, force the theming files Ryoku replaces (a replaced
#     link is exactly the "would be clobbered" activation failure the
#     iNiR trial hit): every switch stomps Ryoku's copy back to the
#     declared one. Inert on hosts without Ryoku.
#
# Retires with the trial.
{
  lib,
  osConfig,
  ...
}:

{
  xdg.configFile = {
    "niri/config.kdl".enable = lib.mkIf (osConfig.networking.hostName == "hero") (lib.mkForce false);
    "gtk-3.0/settings.ini".force = true;
    "gtk-4.0/settings.ini".force = true;
    "btop/btop.conf".force = true;
    # yazi is absent on purpose: HM manages its keymap/theme but not
    # yazi.toml, so Ryoku's copy of that one collides with nothing
  };
}
