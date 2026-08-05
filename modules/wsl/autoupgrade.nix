# Automatic updating, WSL boxes only: rebuilds weekly from pushed main,
# honouring the pushed flake.lock. Run `nix flake update` to actually bump
# inputs (CI does it Sundays). Deliberately NOT /etc/nixos: that's the
# live working tree, and the timer would silently activate uncommitted
# work-in-progress. The laptop deliberately has no autoUpgrade — a
# desktop mid-session should never swap its compositor under the user;
# it updates via `nh os switch -u`, on purpose.
{ ... }:

{
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
