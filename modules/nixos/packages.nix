# System-wide development toolchains and CLI basics.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gcc
    gnumake
    curl
    unzip
    gzip
    gnutar
    tree
    jq
    file
    htop

    # what did a rebuild actually change: nvd diff /run/booted-system /run/current-system
    nvd
    nh

    nodejs_latest

    go
    gopls

    # rustup rather than nixpkgs rustc/cargo: RustRover only accepts a
    # rustup-managed toolchain. Its downloaded binaries break when a glibc
    # bump + GC removes the linker they were patched against; the activation
    # hook in home/marcus/toolchains.nix repairs that automatically.
    rustup

    buf # protobuf tooling, JetBrains plugin points at it

    # zls is built against this same nixpkgs zig, so the compiler and
    # language server stay on matching versions automatically
    zig
    zls
  ];
}
