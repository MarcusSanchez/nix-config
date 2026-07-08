# Zig toolchain pinned to 0.16.0, with ZLS built against that exact compiler
# so editor tooling always matches the compiler version.
{ inputs, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  zig = inputs.zig-overlay.packages.${system}."0.16.0";
  zls = inputs.zls-overlay.packages.${system}.zls.overrideAttrs (_: {
    nativeBuildInputs = [ zig ];
  });
in
{
  environment.systemPackages = [
    zig
    zls
  ];
}
