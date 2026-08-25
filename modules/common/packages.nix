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

    # roaming SSH: survives IP changes, sleep and long lag, with
    # local echo over bad links. One package = mosh-server (spawned
    # by the ssh login) + the mosh client. Its UDP range (60000-61000)
    # is opened wherever a firewall gates the path in — see the
    # networking.nix files; the enabling case is the WSL boxes, whose
    # tailscale0 is not trusted. The macs have no app firewall and the
    # desktop trusts tailscale0, so tailnet mosh needs nothing there.
    mosh
    # session persistence for those connections: detach/attach a
    # terminal session (`zmx attach <name>`; Ctrl-\ detaches, and `zmx
    # detach` from any shell is the deterministic fallback — on the mac,
    # TUI output coalescing can swallow the chord) so a dropped link or
    # closed laptop doesn't kill the work. The lightweight answer where
    # tmux would be a full multiplexer; replaced abduco, whose client
    # only ever tested the first byte of each read for its detach key.
    # A bare attach spawns a login $SHELL, so no command export needed.
    zmx

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

    # Gleam: LSP included (`gleam lsp`), so no zls-style second package.
    # It propagates nothing, so the runtime is explicit — erlang to run the
    # default target, rebar3 to build Erlang-project Hex deps, the nodejs
    # above for the JS one. beamPackages.* because pkgs.erlang is
    # deprecated and warns on every eval.
    gleam
    beamPackages.erlang
    beamPackages.rebar3
  ];

  # Claude Code, kept current via the claude-code-nix overlay. Its
  # binary cache (claude-code.cachix.org) is wired in per-platform:
  # nix.settings in the nixos/wsl nix.nix files, /etc/nix/
  # nix.custom.conf on the mac.
  nixpkgs.overlays = [ inputs.claude-code.overlays.default ];
}
