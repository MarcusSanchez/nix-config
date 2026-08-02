# Standalone user-level tools.
{ inputs, pkgs, ... }:

{
  home.packages = with pkgs; [
    croc
    flyctl
    # sends WoL magic packets; the target PC's BIOS/NIC must have
    # wake-on-LAN enabled or the packet is silently ignored
    wakeonlan
  ];

  # comma: `, <cmd>` runs any program from nixpkgs without installing it
  # (one-off tools, trying things out). Backed by nix-index-database's
  # prebuilt index — refreshed by `nix flake update`, never built locally.
  # Bonus: nix-index's command-not-found handler tells you which package
  # provides a missing command.
  imports = [ inputs.nix-index-database.homeModules.nix-index ];
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;
}
