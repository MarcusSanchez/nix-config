# The machine's whole network story: NetworkManager, the LAN-facing
# firewall policy, and tailscale — whose trustedInterfaces line is the
# tailnet catch-all the tight LAN port list below leans on.
{ ... }:

{
  networking = {
    networkmanager.enable = true;
    # LAN-open ports: only servers another device plausibly connects
    # to — localhost traffic never touches the firewall, so a dev
    # server used purely from this machine's own browser needs nothing
    # here. Databases and other internals stay closed; for anything
    # not listed, the tailnet path (tailscale0 is trusted below)
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
      # mosh (common/packages.nix) picks a server port from this
      # range. The working path is the tailnet: tailscale0 is trusted
      # below, so those packets never consult this list. The LAN
      # opening is forward-looking only — mosh bootstraps over SSH and
      # nothing serves SSH on the LAN here (Tailscale SSH only, per
      # the block below), so a LAN-side session cannot start today.
      allowedUDPPortRanges = [
        {
          from = 60000;
          to = 61000;
        }
      ];
    };
  };

  # Tailscale, so this machine is reachable from any network rather than
  # only over the LAN. Inbound SSH is Tailscale SSH: tailscaled
  # terminates SSH itself and authorizes from tailnet identity + the
  # policy file's "ssh" rules — no sshd, no authorized_keys, no key to
  # distribute, and nothing listening on the LAN. Reaching this box
  # needs a matching rule in the tailnet policy, and the action must be
  # "accept" — "check" demands a periodic browser re-auth and presents
  # as a connection that simply closes. Enrolment is interactive and
  # stores nothing in the repo: `sudo tailscale up` (--ssh is already
  # handled: extraSetFlags creates tailscaled-set.service, which runs
  # `tailscale set --ssh` after tailscaled starts).
  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--ssh" ];
  };

  # Everything arriving over the tailnet comes from this tailnet's own
  # enrolled devices, so skip the firewall for it entirely: every dev
  # server, on any port, is reachable from the phone/laptop via this
  # box's tailnet name — from anywhere, with zero LAN exposure.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
