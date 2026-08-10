# NetworkManager plus the LAN-facing firewall policy. The tailnet
# catch-all (trustedInterfaces = tailscale0) lives in ./tailscale.nix
# beside the daemon it trusts.
{ ... }:

{
  networking = {
    networkmanager.enable = true;
    # LAN-open ports: only servers another device plausibly connects
    # to — localhost traffic never touches the firewall, so a dev
    # server used purely from this machine's own browser needs nothing
    # here. Databases and other internals stay closed; for anything
    # not listed, the tailnet path (tailscale.nix trusts tailscale0)
    # reaches every port from enrolled devices with no LAN exposure.
    firewall = {
      allowedTCPPorts = [
        # localsend discovers and transfers here
        53317
        # Metro (Expo/React Native dev server) — phone-on-LAN loads the
        # app from here. WSL never needed this: its traffic enters
        # through Windows' network stack, not the NixOS firewall.
        8081
        # the front-end dev-server canon, for phone-testing on the LAN:
        # Next.js/CRA/Express habit, Vite, Django/`python -m http.server`,
        # and the generic-8080 crowd (Spring, proxies, tools)
        3000
        5173
        8000
        8080
      ];
      # croc's LAN-local mode: same-network transfers go direct instead
      # of silently falling back to the public relay (relay mode is
      # outbound-only and needs nothing here)
      allowedTCPPortRanges = [
        {
          from = 9009;
          to = 9013;
        }
      ];
      allowedUDPPorts = [
        # localsend's discovery side
        53317
        # croc LAN peer discovery
        9009
      ];
    };
  };
}
