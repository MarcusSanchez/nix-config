# The shared darwin host KIND — every Mac in the flake points here (like
# the WSL boxes share hosts/wsl). Per-machine values resolve from the
# hostName specialArg; the account name is the other one, in
# modules/darwin/users.nix. Reusable config lives in modules/darwin.
{ hostName, ... }:

{
  imports = [ ../../modules/darwin ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  homeEntryPoint = ../../home/marcus/darwin.nix;

  # From flake.nix — see hosts/wsl/default.nix.
  networking.hostName = hostName;
  # The Sharing/AirDrop name, per machine. A hostName absent here errors
  # loudly (add the Mac) rather than defaulting to a wrong label.
  networking.computerName =
    {
      macbook-air = "Marcus’s MacBook Air";
      mac-mini = "Marcus’s Mac mini";
    }
    .${hostName};

  # nix-darwin's stateVersion is a single era-wide integer (currently 6),
  # NOT a per-machine date like the NixOS hosts — both Macs installed in
  # the same era legitimately share it. Do not change after install.
  system.stateVersion = 6;
}
