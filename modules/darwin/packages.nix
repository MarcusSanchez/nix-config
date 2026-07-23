# System-wide development toolchains and CLI basics.
#
# Deliberately absent vs the WSL config: gcc/gnumake/curl/unzip/gzip/gnutar —
# macOS and the Xcode Command Line Tools provide those (clang, make, bsdtar).
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    tree
    jq
    file
    htop

    # what did a rebuild actually change: nvd diff <old-gen> <new-gen>
    nvd
    nh

    nodejs_latest

    # scripting: global `pip install` can't work against the read-only
    # store — use `uvx <tool>` for ad-hoc CLIs and `uv venv`/`uv run`
    # for projects instead
    python3
    uv

    go
    gopls

    # rustup rather than nixpkgs rustc/cargo, same as on WSL — one toolchain
    # manager everywhere (bootstrap hook in home/marcus/toolchains.nix)
    rustup

    buf # protobuf tooling, JetBrains plugin points at it

    # nix: LSP + formatter (the lang.nix LazyVim extra uses these)
    nixd
    nixfmt

    # zls is built against this same nixpkgs zig, so the compiler and
    # language server stay on matching versions automatically
    zig
    zls
  ];
}
