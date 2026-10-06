# NixOS-WSL integration.
{
  inputs,
  config,
  pkgs,
  ...
}:

{
  imports = [ inputs.nixos-wsl.nixosModules.default ];

  wsl = {
    enable = true;
    defaultUser = config.identity.username;
    # Deliberately off. WSL >= 2.5.7 registers the .exe handler itself
    # and locks binfmt_misc/status read-only, so nothing can flush it.
    # Registering it here would install systemd-binfmt.service, which
    # fails on that read-only lock at every boot and switch and makes
    # every autoUpgrade report failed. With no registrations nixpkgs
    # installs no binfmt unit at all. Must become true the day any other
    # registration appears (emulatedSystems) — NixOS-WSL asserts on it.
    interop.register = false;
  };

  # Make xdg-open / $BROWSER reach the Windows browser, so CLI auth flows
  # (gh, flyctl, OAuth callbacks) open a page instead of printing a URL.
  # (wslu/wslview is gone from nixpkgs — project archived.)
  environment.systemPackages = [ pkgs.wsl-open ];
  environment.sessionVariables.BROWSER = "wsl-open";
}
