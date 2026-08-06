# Bluetooth radio, powered on at boot.
{ ... }:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
}
