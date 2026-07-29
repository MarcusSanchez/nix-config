# Tailscale, so the machines reach each other from any network rather than
# only over the LAN.
#
# **Imported by hosts/wsl/default.nix ONLY — never by modules/nixos/default.nix.**
# Every WSL2 distro on a Windows PC shares ONE network namespace: same IP,
# same ports, same routing table (microsoft/WSL#4304). Two tailscaled
# instances there would fight over tailscale0, UDP 41641, and the
# 100.64.0.0/10 route. One tailnet node per Windows PC, and this is it —
# nixos-lite deliberately stays off the tailnet.
#
# Also do NOT install Tailscale on Windows while this is enabled: traffic
# would be encapsulated twice and Tailscale packets don't fit inside
# Tailscale packets. Tailscale's own docs actually recommend the Windows
# host over WSL; we're going the other way because it makes this distro a
# real node with its own MagicDNS name and inbound `tailscale ssh`, which
# the Windows-side setup can't do without port-dispatching into wsl.exe.
# If it misbehaves, that's the pivot.
#
# Two things that make this viable here and would not be true by default:
# mirrored networking gives eth1 an MTU of 1500 (NAT mode's 1280 breaks
# SSH and TLS while leaving ping working — tailscale#7346), and NixOS-WSL
# runs systemd as PID 1, without which tailscaled won't start at all.
#
# Enrolment is interactive and stores nothing in the repo:
#
#   sudo tailscale up --ssh
#
# (An authKeyFile from sops would allow unattended enrolment, but auth keys
# expire after 90 days max, so it'd be a recurring rotation for two
# machines we sit in front of. Note extraUpFlags only applies when
# authKeyFile is set — hence passing --ssh by hand above.)
{ ... }:

{
  services.tailscale.enable = true;

  # /dev/net/tun already exists on this kernel; belt and braces, since
  # without it tailscaled fails with CreateTUN("tailscale0") failed.
  boot.kernelModules = [ "tun" ];
}
