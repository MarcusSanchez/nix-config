# Remote Login, so the WSL box can reach this machine — for diagnostics and
# `darwin-rebuild --target-host`.
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
