# Tailscale, so the machines reach each other from any network rather than
# only over the LAN.
#
# **Imported by the host modules, never by modules/nixos/default.nix.**
# Every WSL2 distro on a Windows PC shares ONE network namespace: same IP,
# same ports, same routing table (microsoft/WSL#4304). Two tailscaled
# instances there would fight over tailscale0, UDP 41641, and the
# 100.64.0.0/10 route. So the rule is one importing distro per PC, which is
# a per-machine fact the aggregator cannot express — hence host-level. Every
# host module imports it today because each instance lives on its own PC; two
# that shared one would need the second to drop this import.
#
# Also do NOT install Tailscale on Windows while this is enabled: traffic
# would be encapsulated twice and Tailscale packets don't fit inside
# Tailscale packets. Tailscale's own docs actually recommend the Windows
# host over WSL; this config goes the other way because it makes this distro a
# real node with its own MagicDNS name and inbound `tailscale ssh`, which
# the Windows-side setup can't do without port-dispatching into wsl.exe.
# If it misbehaves, that's the pivot.
#
# Two things that make this viable here and would not be true by default:
# an MTU of 1500 on the WSL NIC (an MTU of 1280 breaks SSH and TLS while
# leaving ping working — tailscale#7346; mirrored networking's eth1 has
# 1500, and current WSL ships it in NAT mode too),
# and NixOS-WSL runs systemd as PID 1, without which tailscaled won't
# start at all. Which mode a PC runs matters elsewhere though: NAT means
# the distro's 127.0.0.1 never reaches Windows — the Windows host is the
# NAT gateway instead (see rustdesk-bridge.nix).
#
# Enrolment is interactive and stores nothing in the repo:
#
#   sudo tailscale up --ssh
#
# (An authKeyFile from sops would allow unattended enrolment, but auth keys
# expire after 90 days max, so it'd be a recurring rotation for two
# interactively-used machines. Note extraUpFlags only applies when
# authKeyFile is set — hence passing --ssh by hand above.)
{ ... }:

{
  services = {
    tailscale = {
      enable = true;

      # Tailscale SSH: tailscaled terminates SSH itself and authorizes from
      # tailnet identity + the policy file's "ssh" rules, so there is no
      # sshd, no authorized_keys and no key to distribute. This is why there
      # is no ssh.nix here. Creates tailscaled-set.service, which runs
      # `tailscale set --ssh` after tailscaled.
      #
      # Reaching this box needs a matching rule in the tailnet policy, and
      # the action must be "accept" — "check" demands a periodic browser
      # re-auth and presents as a connection that simply closes.
      extraSetFlags = [ "--ssh" ];
    };

    # MagicDNS needs somewhere to install the .ts.net route. tailscaled
    # would normally rewrite /etc/resolv.conf, but on WSL that file belongs
    # to the host — a symlink to /mnt/wsl/resolv.conf, regenerated at every
    # distro start. So `tailscale dns status` reports DNS as enabled while
    # no tailnet name resolves at all. Hand resolution to systemd-resolved,
    # which tailscaled configures over D-Bus rather than by file.
    #
    # DNS= keeps WSL's own resolver (a stub on lo, proxying to the Windows
    # resolvers) as the upstream, so ordinary lookups and any LAN/VPN split
    # DNS behave exactly as before. It pairs with generateResolvConf below:
    # dropping that alone leaves the box with no DNS whatsoever.
    resolved = {
      enable = true;
      settings.Resolve.DNS = "10.255.255.254";
    };
  };

  # Stop WSL owning /etc/resolv.conf so resolved can. Read only at distro
  # start, so this needs `wsl -t nixos` from PowerShell after the switch —
  # a rebuild alone changes nothing.
  wsl.wslConf.network.generateResolvConf = false;

  # /dev/net/tun already exists on this kernel; belt and braces, since
  # without it tailscaled fails with CreateTUN("tailscale0") failed.
  boot.kernelModules = [ "tun" ];
}
