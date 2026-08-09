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
# NOT 127.0.0.1: these boxes run WSL's NAT networking (verified live on
# office-lite-wsl-1 — eth0 172.18.x.x/20; loopback interop is a
# mirrored-mode feature, and a localhost backend dies with connection
# refused inside the distro's own loopback). The NAT subnet is
# re-randomized every Windows boot, which is also why this unit
# re-asserts the mapping each boot instead of trusting the serve state
# tailscaled persists — a remembered gateway goes stale on reboot.
# Windows Firewall already admits WSL-subnet traffic to rustdesk.exe
# via the rules its installer adds (verified: gateway:21118 OPEN).
#
# Imported by hosts/wsl-lite only — the lite PCs are the ones controlled
# remotely. Windows-side hand-work, once per PC: RustDesk -> Security ->
# unlock -> "Enable direct IP access" + set a permanent password.
# Connect from any tailnet machine with <hostname>:21118 (or bare
# <hostname>; the port is the client's default).
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
