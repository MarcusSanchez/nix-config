# Declarative Homebrew: nix-darwin drives `brew bundle` on every rebuild,
# and nix-homebrew (below) owns the installation those commands run
# against. GUI apps stay casks — nixpkgs darwin GUI packages are
# second-class; brew casks are the happy path.
#
# cleanup = "zap": every formula, cask, and tap NOT declared below is
# uninstalled on activation. Adding a tool imperatively with `brew install`
# only lasts until the next rebuild — declare it here or lose it.
{
  config,
  lib,
  hostName,
  ...
}:

{
  # The installation itself, which nix-darwin's homebrew.* options do NOT
  # provide: they assume a brew that someone installed by hand. With this,
  # a fresh mac needs only Xcode CLT, Nix, and the first darwin-rebuild.
  #
  # It also pins the brew VERSION through the flake (its brew-src input),
  # so `brew --version` becomes a property of the lock rather than of
  # whenever the machine last self-updated.
  nix-homebrew = {
    enable = true;
    # Owner of the prefix — the same account nix-darwin acts on, from
    # system.primaryUser in ./users.nix.
    user = config.identity.username;
    # Adopts the brew that is already on this machine instead of demanding
    # a clean prefix. Harmless once adopted; it is what makes the switch to
    # nix-homebrew a no-op for an existing install rather than a reinstall.
    autoMigrate = true;
    # No second prefix under /usr/local: everything declared below is
    # arm64-native, and the Intel prefix only exists to run x86-64 bottles
    # through Rosetta 2.
    enableRosetta = false;
    # Taps deliberately stay MUTABLE (the default). Pinning them means
    # carrying homebrew-core and homebrew-cask as flake inputs — ~1.6 GB
    # of repos that are pushed to daily, so every `nix flake update` would
    # rewrite them. Pinning a cask's definition also does not pin what it
    # downloads, since vendors delete old releases.
    #
    # nix-homebrew.trust.* is the declarative answer to Homebrew 6
    # refusing untrusted third-party taps — if a tap is ever needed here,
    # that is where its trust entry goes instead of a per-machine
    # `brew trust`. (Removing an entry does NOT revoke it; that needs
    # `brew untrust`.)
  };

  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      # upgrade what brew tracks, but no greedy: self-updating casks
      # (spotify, zed, zen, toolbox, raycast) own their update channel —
      # greedy would downgrade any app whose self-updater is ahead of the index
      upgrade = true;
      cleanup = "zap";
    };

    brews = [
      # real gcc (not clang-pretending); nixpkgs gcc on darwin is awkward
      "gcc"

      # file-watching daemon; nixpkgs watchman has a rocky history on darwin
      "watchman"
    ];

    casks = [
      "ghostty"
      "google-chrome"
      # per-application key remapping; its config and the launchd agent
      # that keeps it running live in home/marcus/darwin/hammerspoon.nix
      "hammerspoon"
      # video player for downloaded files — mpv's engine (the same one
      # nixos' mpvpaper runs) behind a native mac UI, so mkv and its
      # embedded subtitle tracks play without transcoding
      "iina"
      # IDE manager only — the JetBrains IDEs themselves are installed and
      # updated inside Toolbox (declaring them as casks would just drift
      # against their self-updater)
      "jetbrains-toolbox"
      "localsend"
      "raycast"
      "rustdesk"
      "spotify"
      "stremio"
      "zed"
      "zen"
    ]
    # Desktop-mouse-only scroll inversion: flip the wheel to the
    # traditional direction WITHOUT touching the trackpad. macOS can't
    # split scroll direction per device, so Scroll Reverser does it. Mini
    # only — the Air is trackpad-primary and keeps global natural scroll.
    # Manual after install, same shape as hammerspoon's accessibility:
    # grant Scroll Reverser Accessibility permission, then in its menu bar
    # item set Reverse Mouse ON, Reverse Trackpad OFF, and Start at Login.
    ++ lib.optionals (hostName == "mac-mini") [
      "scroll-reverser"
    ];
  };
}
