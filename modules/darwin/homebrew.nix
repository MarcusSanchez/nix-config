# Declarative Homebrew: nix-darwin drives `brew bundle` on every rebuild.
# Homebrew itself must already be installed (it is). GUI apps stay casks —
# nixpkgs darwin GUI packages are second-class; brew casks are the happy path.
#
# cleanup = "zap": every formula, cask, and tap NOT declared below is
# uninstalled on activation. Adding a tool imperatively with `brew install`
# only lasts until the next rebuild — declare it here or lose it.
{ ... }:

{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      # upgrade what brew tracks, but no greedy: self-updating casks
      # (spotify, zed, zen, toolbox) own their update channel — greedy
      # would downgrade any app whose self-updater is ahead of the index
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
      # IDE manager only — the JetBrains IDEs themselves are installed and
      # updated inside Toolbox (declaring them as casks would just drift
      # against their self-updater)
      "jetbrains-toolbox"
      "localsend"
      "spotify"
      "stremio"
      # The app, not nix-darwin's services.tailscale: that runs the bare
      # tailscaled daemon, which Tailscale scopes to unattended headless
      # installs, and nix-darwin#1688 has it hang and log you out on every
      # darwin-rebuild switch. This is an interactive laptop — it wants the
      # menu bar and the Apple network extension.
      "tailscale-app"
      "termius"
      "zed"
      "zen"
    ];
  };
}
