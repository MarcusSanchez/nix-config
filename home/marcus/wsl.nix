# Home Manager entry point for every WSL box: identity + shared config,
# nothing more. WSL is a terminal into the shared toolchains — no GUI
# apps, no UI-managed-config links (those belong to the desktop and mac
# sessions; a WSL box edits the repo like any other checkout). The
# Windows sides of these PCs are unmanaged on purpose.
{ ... }:

{
  imports = [ ./common ];

  # username/homeDirectory come from identity.* via the HM bridge
  # Do not change after initial install.
  home.stateVersion = "25.05";
}
