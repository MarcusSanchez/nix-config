# NixOS-WSL integration.
{ inputs, pkgs, ... }:

{
  imports = [ inputs.nixos-wsl.nixosModules.default ];

  wsl.enable = true;
  wsl.defaultUser = "marcus";

  # Make xdg-open / $BROWSER reach the Windows browser, so CLI auth flows
  # (gh, flyctl, OAuth callbacks) open a page instead of printing a URL.
  # (wslu/wslview is gone from nixpkgs — project archived.)
  environment.systemPackages = [ pkgs.wsl-open ];
  environment.sessionVariables.BROWSER = "wsl-open";
}
