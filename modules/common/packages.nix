# Dev toolchains and CLI basics for every machine. Platform-only packages
# (build essentials the mac gets from Xcode CLT) live in the platform's own
# packages.nix.
{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    tree
    jq
    file
    htop

    # what did a rebuild actually change: nvd diff <old-gen> <new-gen>
    nvd
    nh

    # per-project dev environments (packages, languages, services):
    # `devenv init` + `devenv allow` in the project repo
    devenv
    # declarative secrets for those projects (secretspec.toml declares,
    # a provider — keyring/dotenv/env — supplies; devenv reads it natively)
    secretspec

    nodejs_latest

    # scripting: global `pip install` can't work against the read-only
    # store — use `uvx <tool>` for ad-hoc CLIs and `uv venv`/`uv run`
    # for projects instead
    python3
    uv

    go
    gopls

    # rustup rather than nixpkgs rustc/cargo: RustRover only accepts a
    # rustup-managed toolchain. Bootstrap/repair hooks live in
    # home/marcus/{wsl,mac}/toolchains.nix (glibc repair on WSL, plain
    # first-run bootstrap on the mac).
    rustup

    buf # protobuf tooling, JetBrains plugin points at it

    # nix: LSP + formatter (the lang.nix LazyVim extra uses these)
    nixd
    nixfmt

    # nix linters, also enforced by CI: statix (antipatterns, config in
    # statix.toml) and deadnix (unused bindings)
    statix
    deadnix

    # zls is built against this same nixpkgs zig, so the compiler and
    # language server stay on matching versions automatically
    zig
    zls
  ];
}
