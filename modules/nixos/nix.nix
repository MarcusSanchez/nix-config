# Nix daemon settings, garbage collection, and automatic upgrades.
{ ... }:

{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };

  # Automatic cleanup
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 10d";
  };

  # Automatic updating: rebuilds /etc/nixos weekly, honouring flake.lock.
  # Run `nix flake update` to actually bump inputs.
  system.autoUpgrade = {
    enable = true;
    dates = "weekly";
    flake = "/etc/nixos";
  };
  # WSL only runs timers while the VM is up; catch up missed windows on
  # the next boot instead of silently skipping the week. (nix.gc's timer
  # is already persistent by default.)
  systemd.timers.nixos-upgrade.timerConfig.Persistent = true;

  nixpkgs.config.allowUnfree = true;
}
