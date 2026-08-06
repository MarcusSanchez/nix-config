# Desktop-only system packages (mirrors modules/nixos/packages.nix).
# libsecret's secret-tool probes the org.freedesktop.secrets provider
# by hand: secret-tool store/lookup. watchman is desktop-only on Linux:
# its folly/fbthrift closure is ~87 MiB, which the WSL boxes shouldn't
# carry (the mac gets its own from brew).
{ pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.libsecret
    pkgs.watchman
  ];
}
