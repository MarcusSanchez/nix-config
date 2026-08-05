# NixOS-WSL integration.
{ inputs, pkgs, ... }:

{
  imports = [ inputs.nixos-wsl.nixosModules.default ];

  wsl = {
    enable = true;
    defaultUser = "marcus";
    # systemd-binfmt can wipe WSL's own handler for Windows .exe files,
    # which breaks interop (powershell.exe: "Exec format error", wsl-open
    # dies). Registering it declaratively keeps it in place.
    interop.register = true;
  };

  # Make xdg-open / $BROWSER reach the Windows browser, so CLI auth flows
  # (gh, flyctl, OAuth callbacks) open a page instead of printing a URL.
  # (wslu/wslview is gone from nixpkgs — project archived.)
  environment.systemPackages = [ pkgs.wsl-open ];
  environment.sessionVariables.BROWSER = "wsl-open";
}
