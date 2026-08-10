# Desktop-only system packages (mirrors modules/nixos/packages.nix).
# libsecret's secret-tool probes the org.freedesktop.secrets provider
# by hand: secret-tool store/lookup. watchman is desktop-only on Linux:
# its folly/fbthrift closure is ~87 MiB, which the WSL boxes shouldn't
# carry (the mac gets its own from brew). ethtool reads and sets the
# NIC's own hardware flags — `ethtool <iface>` is how you confirm the
# Wake-on-LAN state that hosts/naut-dt/wake-on-lan.nix arms
# (`Wake-on: g` armed, `d` disabled); bare metal only, since a WSL box
# has no real NIC to interrogate.
{ pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.ethtool
    pkgs.libsecret
    pkgs.watchman
  ];
}
