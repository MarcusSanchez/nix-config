# Nix daemon settings, garbage collection, and automatic upgrades.
{ ... }:

{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;

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

  # Automatic updating: rebuilds weekly from pushed main, honouring the
  # pushed flake.lock. Run `nix flake update` to actually bump inputs.
  # Deliberately NOT /etc/nixos: that's the live working tree, and the
  # timer would silently activate uncommitted work-in-progress.
  system.autoUpgrade = {
    enable = true;
    dates = "weekly";
    flake = "github:MarcusSanchez/nix-config";
  };
  # WSL only runs timers while the VM is up; catch up missed windows on
  # the next boot instead of silently skipping the week. (nix.gc's timer
  # is already persistent by default.)
  systemd.timers.nixos-upgrade.timerConfig.Persistent = true;
}
