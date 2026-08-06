# Tailscale, so this machine is reachable from any network rather than
# only over the LAN. Inbound SSH is Tailscale SSH: tailscaled terminates
# SSH itself and authorizes from tailnet identity + the policy file's
# "ssh" rules — no sshd, no authorized_keys, no key to distribute, and
# nothing listening on the LAN. Reaching this box needs a matching rule
# in the tailnet policy, and the action must be "accept" — "check"
# demands a periodic browser re-auth and presents as a connection that
# simply closes.
#
# Enrolment is interactive and stores nothing in the repo:
#
#   sudo tailscale up
#
# (--ssh is already handled: extraSetFlags creates tailscaled-set.service,
# which runs `tailscale set --ssh` after tailscaled starts.)
{ ... }:

{
  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--ssh" ];
  };

  # Everything arriving over the tailnet comes from this tailnet's own
  # enrolled devices, so skip the firewall for it entirely: every dev
  # server, on any port, is reachable from the phone/laptop via this
  # box's tailnet name — from anywhere, with zero LAN exposure. The LAN
  # port list in desktop.nix stays tight because this is the catch-all.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
