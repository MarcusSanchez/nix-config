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
# Which devices the server detects is machine-local state, not here:
# the Detectors map in /var/lib/OpenRGB/OpenRGB.json (the server runs
# as root). The Lian Li screen and the Wooting are switched off there
# on purpose — each has its own owner (the lianli daemon, Wootility)
# and a second controller fighting over them undoes their settings.
# A device OpenRGB "cannot see" is usually that map, not a driver.
# Prefer hardware modes over continuous software effects on the GPU —
# each frame is dozens of blocking I2C transfers.
{ pkgs, ... }:

{
  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd";
    # this board's Aura controller reports its onboard LED count one
    # byte past where OpenRGB reads it (0x1B is 0, 0x1C holds the
    # count), so stock OpenRGB builds no mainboard zone and the onboard
    # lighting only ever receives colour-less effects. The fallback
    # read gives it a zone; --replace-fail makes a release that moves
    # the line fail the build rather than silently drop the zone.
    package = pkgs.openrgb.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
            substituteInPlace Controllers/AsusAuraUSBController/AsusAuraUSBController/AsusAuraMainboardController.cpp \
              --replace-fail 'unsigned char num_total_mainboard_leds  = config_table[0x1B];' \
              'unsigned char num_total_mainboard_leds  = config_table[0x1B];
        if(num_total_mainboard_leds == 0)
        {
            num_total_mainboard_leds = config_table[0x1C];
        }'
      '';
    });
  };

  boot.blacklistedKernelModules = [ "spd5118" ];
}
