# PRE-INSTALL PLACEHOLDER — not generated, cannot boot. It exists so the
# host evaluates (flake check covers it) before the machine does. At
# install time, replace this whole file with the real one:
#   sudo nixos-generate-config --root /mnt   # from the installer, or
#   sudo nixos-generate-config               # from the installed system
# and copy the generated hardware-configuration.nix over this file. The
# warning below prints on every eval until that happens.
{ lib, config, ... }:

{
  warnings = [
    "bedroom-nixos: hardware-configuration.nix is a pre-install placeholder — regenerate it at install time (see its header)"
  ];

  # plausible for the machine (WD_BLACK NVMe, AMD 9800X3D) but the real
  # list comes from the generator
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-amd" ];

  # dummy UUIDs — the generator writes the real ones
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0000-0000";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  # no disk swap on purpose — zram, like the tuf (modules/desktop/zram.nix)
  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
