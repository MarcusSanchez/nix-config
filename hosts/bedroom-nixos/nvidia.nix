# Proprietary NVIDIA driver for the RTX 5080. HOST-level, not in
# modules/desktop, because everything here encodes THIS machine's GPU
# facts. A desktop card has no MUX/PRIME story at all — the monitors hang
# straight off the dGPU — so this is the simplest possible shape.
{ ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  # Early KMS: load the driver in the initrd so the monitor is driven at
  # native mode from the first splash frame — without this, plymouth
  # starts on the firmware framebuffer and the screen mode-switches
  # (black flash) when the real driver loads mid-boot. This is why the
  # NixOS ESP is 1 GB: each unique initrd costs ~130-200 MB, shared
  # across the generations that use it (configurationLimit 10 in
  # modules/desktop/boot.nix bounds the total).
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

    # NOT a choice on this card: Blackwell (GB203) is supported ONLY by
    # the open kernel module — the legacy proprietary blob never learned
    # these chips
    open = true;

    nvidiaSettings = true;

    # saves/restores VRAM across suspend — what makes suspend/resume
    # reliable on Wayland
    powerManagement.enable = true;
    # fine-grained power management is a PRIME-offload feature; a desktop
    # card has no iGPU to offload from
    powerManagement.finegrained = false;

    # Default driver pin. Blackwell needs 570+, which the default has
    # long since passed; if a build ever breaks against a new kernel:
    #   package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
}
