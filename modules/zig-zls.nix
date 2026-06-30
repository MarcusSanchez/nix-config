{ inputs, pkgs, ... }:
{
  nixpkgs.overlays = [
    inputs.zig-overlay.overlays.default
    inputs.zls-overlay.overlays.default
  ];

  environment.systemPackages = [
    pkgs.zig
    pkgs.zls
  ];
}
