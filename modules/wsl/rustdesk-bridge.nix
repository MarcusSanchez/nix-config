# Tailnet doorway to the Windows side's RustDesk receiver, for the
# account-free "direct IP access" mode (their public rendezvous now
# gates ID-based connections behind an account login). RustDesk runs on
# WINDOWS on these PCs, but the tailnet node lives inside the distro —
# traffic to this host's tailnet name terminates in WSL, where nothing
# listens. Bridge: `tailscale serve` accepts tailnet-only TCP 21118
# (the direct-access port, RENDEZVOUS_PORT+2 in rustdesk's source) and
# dials the Windows host. serve terminates inside tailscaled, so no
# socket binds in WSL, no firewall port opens, and the mapping is
# unreachable from the LAN by construction.
#
# The Windows host is the NAT default gateway, resolved at unit start,
# NOT 127.0.0.1: these boxes run WSL's NAT networking (eth0 on a
# 172.x/20; loopback interop is a mirrored-mode feature, and a
# localhost backend dies with connection refused inside the distro's
# own loopback). The NAT subnet is re-randomized every Windows boot,
# which is also why this unit re-asserts the mapping each boot instead
# of trusting the serve state tailscaled persists — a remembered
# gateway goes stale on reboot. Windows Firewall admits WSL-subnet
# traffic to rustdesk.exe via the rules its installer adds.
#
# Wired per-attr in flake.nix onto the remotely-controlled PCs (the
# office boxes and the framework desktop), not into the WSL kind — the
# PC this desk sits at needs no doorway to itself. Windows-side
# hand-work, once per PC: RustDesk -> Security ->
# unlock -> "Enable direct IP access" + set a permanent password.
# Connect from any tailnet machine with the box's TAILNET IP —
# <100.x.y.z>:21118 — not its hostname: RustDesk only enters direct
# mode when the input parses as an IP; a hostname is treated as an ID
# and sent to the public rendezvous, which reports the device offline.
# Tailnet IPs are stable per node, so a saved session keeps working.
#
# On a machine not yet enrolled (`tailscale up` never run) the unit
# fails after its retries — expected until first enrolment; it heals on
# the next boot or `systemctl restart rustdesk-tailnet-bridge`.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  systemd.services.rustdesk-tailnet-bridge = {
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
