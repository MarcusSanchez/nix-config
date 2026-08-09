# Tailnet doorway to the Windows side's RustDesk receiver, for the
# account-free "direct IP access" mode (their public rendezvous now
# gates ID-based connections behind an account login). RustDesk runs on
# WINDOWS on these PCs, but the tailnet node lives inside the distro —
# traffic to this host's tailnet name terminates in WSL, where nothing
# listens. Bridge: `tailscale serve` accepts tailnet-only TCP 21118
# (the direct-access port, RENDEZVOUS_PORT+2 in rustdesk's source) and
# dials 127.0.0.1:21118, which mirrored networking's localhost interop
# hands to the Windows listener. serve terminates inside tailscaled, so
# nothing binds 21118 in the shared WSL/Windows port space (mirrored
# networking would otherwise collide with RustDesk's own listener), no
# firewall port opens, and the mapping is unreachable from the LAN by
# construction.
#
# Imported by hosts/wsl-lite only — the lite PCs are the ones controlled
# remotely. Windows-side hand-work, once per PC: RustDesk -> Security ->
# unlock -> "Enable direct IP access" + set a permanent password.
# Connect from any tailnet machine with <hostname>:21118 (or bare
# <hostname>; the port is the client's default).
#
# `serve --bg` persists in tailscaled's state; this unit just re-asserts
# it every boot so the config, not daemon state, is the source of truth.
# On a machine not yet enrolled (`tailscale up` never run) the unit
# fails after its retries — expected until first enrolment; it heals on
# the next boot or `systemctl restart rustdesk-tailnet-bridge`.
{
  config,
  lib,
  ...
}:

{
  systemd.services.rustdesk-tailnet-bridge = {
    description = "Publish the Windows RustDesk direct-access port on the tailnet";
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for _ in $(seq 1 12); do
        if ${lib.getExe config.services.tailscale.package} serve --bg --tcp=21118 tcp://127.0.0.1:21118; then
          exit 0
        fi
        sleep 5
      done
      echo "tailscale serve mapping not applied (node not enrolled yet?)" >&2
      exit 1
    '';
  };
}
