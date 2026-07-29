# Host aliases, mainly so the per-machine usernames stop mattering.
#
# marcus on the WSL boxes, marcussanchez on the mac — so
# `ssh marcuss-macbook-air` from WSL tries marcus@, gets no such user,
# and sshd closes the connection with a message that says nothing about
# usernames. These aliases carry the right user, so `ssh mac` and
# `ssh nixos` work from anywhere without thinking about it.
#
# Both entries are defined on every machine; the one naming a host you're
# already on is simply unused. Hostnames resolve over Tailscale MagicDNS
# (see modules/nixos/tailscale.nix), so these work off-LAN too.
{ ... }:

{
  programs.ssh = {
    enable = true;

    matchBlocks = {
      mac = {
        hostname = "marcuss-macbook-air";
        user = "marcussanchez";
      };
      nixos = {
        hostname = "nixos";
        user = "marcus";
      };
    };
  };
}
