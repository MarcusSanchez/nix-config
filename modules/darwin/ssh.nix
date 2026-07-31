# Remote Login: Apple's sshd with the WSL box's key, kept as the fallback
# path now that Tailscale SSH (tailscale.nix) is the primary way in — if
# tailscaled is down (nix-darwin#1688), this still answers on the LAN.
#
# nix-darwin enables Apple's built-in sshd via launchctl rather than
# `systemsetup -setremotelogin`, which would need Full Disk Access. The
# authorized key is written to /etc/ssh/nix_authorized_keys.d/<user>, so
# removing it here actually revokes access (the old authorized_keys.d
# implementation didn't, hence nix-darwin's loud warning about it).
#
# The WSL boxes run no sshd at all, so this is the only inbound SSH in the
# fleet and it really does listen. It's a laptop, so it listens on whatever
# network it's on; macOS's firewall still applies, and password auth isn't
# used because only this key is authorized.
{ ... }:

{
  services.openssh.enable = true;

  users.users.marcussanchez.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIYpPWRSD1Zbt2cnesO+PcnpbNfrUVyWppiTYW3gJgNu marcus@nixos-wsl"
  ];
}
