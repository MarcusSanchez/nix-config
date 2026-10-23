# Nix daemon settings and garbage collection for the bare-metal
# machines. The weekly autoUpgrade is deliberately NOT here — it's WSL
# policy (modules/wsl/nix.nix); a desktop updates by hand, when its
# owner means to.
{ ... }:

{
  nix = {
    settings = {
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

      # Channels are off (below); this keeps nix-shell -p and <nixpkgs>
      # resolving through the flake registry.
      nix-path = [ "nixpkgs=flake:nixpkgs" ];
    };

    # Flake-only: every input comes from flake.lock, nothing resolves
    # through channels. Off, the installer's leftover root channel is
    # ignored and nix-channel leaves the system path.
    channel.enable = false;

    # Automatic cleanup
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 10d";
    };
  };

  # The option alone only warns about leftover channel state at
  # activation; sweep it (root's .nix-channels, .nix-defexpr, the
  # channels profile). Idempotent, and generations never depended on it.
  system.activationScripts.dropInstallerChannels = ''
    rm -rf /root/.nix-channels /root/.nix-defexpr \
      /nix/var/nix/profiles/per-user/root/channels \
      /nix/var/nix/profiles/per-user/root/channels-*-link
  '';

  # The timer's Persistent catch-up fires missed runs at boot, where a
  # large GC competes with the greeter's startup I/O. Idle scheduling
  # keeps the catch-up semantics while keeping GC out of every
  # foreground path's way.
  systemd.services.nix-gc.serviceConfig = {
    IOSchedulingClass = "idle";
    CPUSchedulingPolicy = "idle";
    Nice = 19;
  };
}
