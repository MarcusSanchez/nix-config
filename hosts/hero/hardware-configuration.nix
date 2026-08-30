# PLACEHOLDER — not hardware truth. Replace this whole file at install
# time with the output of `nixos-generate-config` (the real one lands in
# /mnt/etc/nixos/hardware-configuration.nix during nixos-install; copy
# it here and commit). It exists only so the flake can evaluate hero
# before the machine does — the root device below is fictional on
# purpose, and nothing must ever try to boot from it.
{ ... }:

{
  fileSystems."/" = {
    device = "/dev/disk/by-label/PLACEHOLDER";
    fsType = "ext4";
  };
}
