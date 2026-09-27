# TRIAL: the home half of the Ryoku desktop (system half:
# hosts/hero/ryoku.nix, where the whole story lives). Ryoku's
# materializer replaces the files below with its own copies — a
# replace, not a write-through, so the repo never takes the hit, but
# a replaced link is exactly the "would be clobbered" activation
# failure the iNiR trial hit. force lets every switch stomp Ryoku's
# copy back to the declared one: the niri entrypoint returns to the
# repo link (the DMS session depends on it), the theming files return
# to their generated selves. Inert on hosts without Ryoku — force
# over a file HM already owns is a no-op. Retires with the trial.
{ ... }:

{
  xdg.configFile = {
    "niri/config.kdl".force = true;
    "gtk-3.0/settings.ini".force = true;
    "gtk-4.0/settings.ini".force = true;
    "btop/btop.conf".force = true;
    # yazi is absent on purpose: HM manages its keymap/theme but not
    # yazi.toml, so Ryoku's copy of that one collides with nothing
  };
}
