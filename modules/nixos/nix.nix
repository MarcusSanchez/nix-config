# Nix daemon settings and garbage collection for the bare-metal
# machines. The weekly autoUpgrade is deliberately NOT here — it's WSL
# policy (modules/wsl/nix.nix); a desktop updates by hand, when its
# owner means to.
{ ... }:

{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;

    # Single-user machines: wheel is already root-equivalent (passwordless
    # sudo), so let it talk to the daemon fully — extra substituters and
    # devenv's caches work without per-flag trust prompts.
    trusted-users = [
      "root"
      "@wheel"
    ];

    # Pull claude-code and devenv-built artifacts from their cachix caches
    # instead of rebuilding locally. Purely build-vs-download: versions
    # still come from the lockfiles, and a cache miss just builds locally.
    # Can't live in modules/common (darwin has nix.enable = false) — the
    # mac gets the same lines in /etc/nix/nix.custom.conf instead.
    substituters = [
      "https://cache.nixos.org"
      "https://claude-code.cachix.org"
      "https://devenv.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
  };

  # Automatic cleanup
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 10d";
  };
}
