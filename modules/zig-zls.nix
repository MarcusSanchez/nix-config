{ inputs, pkgs, ... }:

let
  system = pkgs.system;
  zig = inputs.zig-overlay.packages.${system}."0.16.0";
  zls = inputs.zls-overlay.packages.${system}.zls.overrideAttrs (_: {
    nativeBuildInputs = [ zig ];
  });
in
{
  nixpkgs.overlays = [
    inputs.zig-overlay.overlays.default
  ];

  environment.systemPackages = [
    zig
    zls
  ];
}
