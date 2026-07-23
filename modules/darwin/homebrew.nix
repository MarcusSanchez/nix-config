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
      autoUpdate = false;
      upgrade = false;
      cleanup = "zap";
    };

    brews = [
      # real gcc (not clang-pretending); nixpkgs gcc on darwin is awkward
      "gcc"

      # file-watching daemon; nixpkgs watchman has a rocky history on darwin
      "watchman"
    ];

    casks = [
      "firefox"
      "ghostty"
      "google-chrome"
      "localsend"
    ];
  };
}
