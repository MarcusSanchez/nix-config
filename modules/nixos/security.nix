# Physical security keys: libfido2's udev rules give the seat user
# access to a USB token's hidraw device, which is what lets a browser
# use it for WebAuthn. Nothing else is needed for the phone-as-passkey
# QR/bluetooth flow beyond bluetooth itself (system.nix).
{ pkgs, ... }:

{
  services.udev.packages = [ pkgs.libfido2 ];
}
