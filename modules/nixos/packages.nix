# System-wide development toolchains and CLI basics.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gcc
    curl
    unzip
    gzip
    gnutar
    tree

    nodejs_latest

    go
    gopls

    # rust, all from the same nixpkgs tree so compiler and tooling always
    # match (rustup's downloaded toolchains broke on every glibc bump + GC)
    rustc
    cargo
    clippy
    rustfmt
    rust-analyzer

    # zls is built against this same nixpkgs zig, so the compiler and
    # language server stay on matching versions automatically
    zig
    zls
  ];
}
