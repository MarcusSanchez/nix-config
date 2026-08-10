# Dev toolchains and CLI basics for every machine. Platform-only packages
# (build essentials the mac gets from Xcode CLT) live in the platform's own
# packages.nix.
{ inputs, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    # from the overlay pinned at the bottom of this file
    claude-code

    tree
    jq
    file
    htop

    # the no-config modern-unix staples (the ones with shell hooks or
    # theming — fzf/bat/eza/yazi/lazygit/btop — live in
    # home/marcus/common/packages.nix instead)
    dust # du, readable
    duf # df, readable
    tealdeer # `tldr <cmd>`: example-first man pages
    hyperfine # statistical CLI benchmarking
    entr # watch files, rerun a command
    xh # HTTP client with humane syntax
    trippy # traceroute+ping TUI
    doggo # dig, readable

    # what did a rebuild actually change: nvd diff <old-gen> <new-gen>
    nvd
    nh

    # per-project dev environments (packages, languages, services):
    # `devenv init` in the project repo, auto-loaded on cd via direnv
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
    # home/marcus/common/toolchains.nix (glibc repair on WSL, plain
    # first-run bootstrap on the mac).
    rustup

    # nix: LSP + formatter (the lang.nix LazyVim extra uses these)
    nixd
    nixfmt

    # nix linters, also enforced by CI: statix (antipatterns, config in
    # statix.toml) and deadnix (unused bindings)
    statix
    deadnix

    # `sops secrets/secrets.yaml` to edit credentials; age is what it
    # encrypts to. One key decrypts everywhere, so onboarding a machine is
    # placing that key, not converting a host key (README's Secrets section).
    sops
    age

    # zls is built against this same nixpkgs zig, so the compiler and
    # language server stay on matching versions automatically
    zig
    zls
  ];

  # Claude Code, kept current via the claude-code-nix overlay. Its
  # binary cache (claude-code.cachix.org) is wired in per-platform:
  # nix.settings in the nixos/wsl nix.nix files, /etc/nix/
  # nix.custom.conf on the mac.
  nixpkgs.overlays = [ inputs.claude-code.overlays.default ];
}
