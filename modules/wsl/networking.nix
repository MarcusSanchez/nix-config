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
# NAT gateway instead (see the bridge unit at the bottom of this file).
#
# Enrolment is interactive and stores nothing in the repo:
#
#   sudo tailscale up --ssh
#
# (An authKeyFile from sops would allow unattended enrolment, but auth keys
# expire after 90 days max, so it'd be a recurring rotation for two
# interactively-used machines. Note extraUpFlags only applies when
# authKeyFile is set — hence passing --ssh by hand above.)
{
  config,
  lib,
  pkgs,
  ...
}:

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

  # Tailnet doorway to the Windows side's RustDesk receiver, on the
  # remotely-controlled PCs only (the `bridged` list): the account-free
  # "direct IP access" mode (the public rendezvous now gates ID-based
  # connections behind an account login). RustDesk runs on WINDOWS on
  # these PCs, but the tailnet node lives inside the distro — traffic
  # to this host's tailnet name terminates in WSL, where nothing
  # listens. `tailscale serve` accepts tailnet-only TCP 21118 (the
  # direct-access port, RENDEZVOUS_PORT+2 in rustdesk's source) and
  # dials the Windows host — the NAT default gateway, resolved at unit
  # start, NOT 127.0.0.1 (loopback interop is a mirrored-mode feature,
  # and the NAT subnet re-randomizes every Windows boot, which is why
  # the mapping re-asserts each boot instead of trusting the serve
  # state tailscaled persists). serve terminates inside tailscaled: no
  # socket binds in WSL, no firewall port opens, unreachable from the
  # LAN by construction. Windows Firewall admits WSL-subnet traffic to
  # rustdesk.exe via the rules its installer adds.
  #
  # Windows-side hand-work, once per PC: RustDesk -> Security -> unlock
  # -> "Enable direct IP access" + set a permanent password. Connect
  # from any tailnet machine with the box's TAILNET IP —
  # <100.x.y.z>:21118 — not its hostname: RustDesk only enters direct
  # mode when the input parses as an IP; a hostname is treated as an ID
  # and sent to the public rendezvous, which reports the device
  # offline. Tailnet IPs are stable per node, so a saved session keeps
  # working. On a machine not yet enrolled the unit fails after its
  # retries — expected until first enrolment; it heals on the next boot
  # or a restart of rustdesk-tailnet-bridge.
  # ...on the PCs whose Windows side runs a RustDesk receiver — the
  # hardcoded list is the gate, and it must track that Windows-side
  # setup; the PC this desk sits at needs no doorway to itself.
  systemd.services.rustdesk-tailnet-bridge =
    lib.mkIf
      (builtins.elem config.networking.hostName [
        "framework-dt"
        "office-one"
        "office-two"
      ])
      {
        description = "Publish the Windows RustDesk direct-access port on the tailnet";
        after = [
          "tailscaled.service"
          "network-online.target"
        ];
        requires = [ "tailscaled.service" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        path = [
          pkgs.iproute2
          pkgs.coreutils
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          for _ in $(seq 1 12); do
            gw=$(ip route show default | head -n1 | cut -d" " -f3)
            if [ -n "$gw" ] \
              && ${lib.getExe config.services.tailscale.package} serve --bg --tcp=21118 "tcp://$gw:21118"; then
              exit 0
            fi
            sleep 5
          done
          echo "tailscale serve mapping not applied (no default route, or node not enrolled yet?)" >&2
          exit 1
        '';
      };

}
