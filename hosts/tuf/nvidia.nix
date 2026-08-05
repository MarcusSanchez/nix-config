# Proprietary NVIDIA driver for the RTX 3070 Mobile. HOST-level, not in
# modules/desktop, because everything here encodes THIS machine's GPU
# facts — a future desktop PC writes its own nvidia.nix rather than
# inheriting these. The MUX is in discrete mode — the laptop panel (eDP)
# is wired straight to the dGPU — so there is deliberately NO prime
# offload/sync config here; add one only if the BIOS MUX is ever switched
# to hybrid (bus IDs would be PCI:0:2:0 intel / PCI:1:0:0 nvidia).
{ ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  # Early KMS: load the driver in the initrd so the panel is driven at
  # native mode from the first splash frame — without this, plymouth
  # starts on the firmware framebuffer and the screen mode-switches
  # (black flash) when the real driver loads mid-boot. Costs ~60 MB of
  # initrd on the ESP; each unique initrd is shared across the
  # generations that use it.
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_drm"
  ];

  hardware.graphics = {
    enable = true;
    # cheap now, needed the day Steam/Wine appears
    enable32Bit = true;
  };

  hardware.nvidia = {
    # required for any Wayland compositor
    modesetting.enable = true;

    # the open kernel module — NVIDIA's recommended path for Turing and
    # newer; GA104 is Ampere, squarely supported
    open = true;

    nvidiaSettings = true;

    # saves/restores VRAM across suspend — what makes suspend/resume
    # reliable on Wayland
    powerManagement.enable = true;
    # fine-grained power management requires PRIME offload mode, which a
    # MUX-discrete panel can't use
    powerManagement.finegrained = false;

    # Default driver pin. If it ever fails to build against the current
    # kernel, switch to:
    #   package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
}
