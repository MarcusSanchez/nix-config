# Proprietary NVIDIA driver — the shared shape: every bare-metal host
# drives its panel straight off a discrete NVIDIA GPU, so there is
# deliberately NO prime offload/sync config here. A hybrid-MUX or
# iGPU-offload machine adds its own prime block at host level; the
# mkDefault scalars below are what let such a host override any of
# this cleanly.
#
# The two LISTS stay at NORMAL priority on purpose:
# hardware-configuration.nix also defines boot.initrd.kernelModules (as
# [ ], priority 100), so an mkDefault here would LOSE to that empty
# list and silently drop the driver from the initrd — no early KMS, no
# error. Same-priority lists concatenate, which is also the natural
# host-level extension path.
{ lib, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  # Early KMS: load the driver in the initrd so the panel is driven at
  # native mode from the first splash frame — without this, plymouth
  # starts on the firmware framebuffer and the screen mode-switches
  # (black flash) when the real driver loads mid-boot. Each unique
  # early-KMS initrd costs on the order of 60-200 MB on the ESP, shared
  # across the generations that use it — why the desktop install runbook
  # calls for a 1 GB ESP, and why configurationLimit 10 in ./boot.nix
  # bounds the total.
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_drm"
  ];

  hardware.graphics = {
    enable = lib.mkDefault true;
    # cheap now, needed the day Steam/Wine appears
    enable32Bit = lib.mkDefault true;
  };

  hardware.nvidia = {
    # required for any Wayland compositor
    modesetting.enable = lib.mkDefault true;

    # the open kernel module — NVIDIA's recommended path for Turing and
    # newer, and the ONLY option on the newest generations (the legacy
    # proprietary blob never learned them). A pre-Turing card sets
    # open = false at host level.
    open = lib.mkDefault true;

    nvidiaSettings = lib.mkDefault true;

    # saves/restores VRAM across suspend — what makes suspend/resume
    # reliable on Wayland
    powerManagement.enable = lib.mkDefault true;
    # fine-grained power management is a PRIME-offload feature; nothing
    # here offloads
    powerManagement.finegrained = lib.mkDefault false;

    # Default driver pin. If it ever fails to build against the current
    # kernel, switch to:
    #   package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
}
