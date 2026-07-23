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

  # Let bare `nh os switch` find the flake without a path argument.
  environment.sessionVariables.NH_FLAKE = "/etc/nixos";
}
