# The desk's remaining RGB — motherboard zones, the GPU's lighting and
# the DDR5 sticks — through OpenRGB (the vendor tooling is
# Windows-only). HOST-level: which buses carry lighting is this
# machine's hardware truth.
#
# How each one is reached:
#   - motherboard zones: the board's Aura controller over the AMD FCH
#     SMBus (i2c-piix4, loaded by the module's motherboard = "amd");
#   - GPU: an ENE controller on the card's internal I2C bus, exposed
#     through the NVIDIA driver;
#   - RAM: ENE controllers at 0x70-0x77 on the SMBus — which the
#     kernel's spd5118 SPD driver otherwise claims first (UU in
#     i2cdetect), so it is blacklisted below. The trade: no DDR5
#     temperature sensors, lighting control instead.
#
# OpenRGB's known NVIDIA-on-Linux quirk lives in machine-local user
# config, not here: ~/.config/OpenRGB/OpenRGB.json wants
# "NvidiaLinuxPatch": {"usePatch": true} (an SMBus packet off-by-one
# swaps red and blue on this vendor's cards without it). Prefer
# hardware modes over continuous software effects on the GPU — each
# frame is dozens of blocking I2C transfers.
{ ... }:

{
  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd";
  };

  boot.blacklistedKernelModules = [ "spd5118" ];
}
