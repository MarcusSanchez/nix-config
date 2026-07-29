# sshd, enabled mainly for the host key it generates.
#
# /etc/ssh/ssh_host_ed25519_key is this machine's sops identity — sops-nix
# converts it to an age key (ssh-to-age) and decrypts with it, which is why
# no private key is ever copied between machines. Without sshd enabled the
# key is never created and secrets can't be decrypted at all.
#
# Bound to loopback with password auth off: we want the key, not a service
# reachable from the network. Being able to `ssh marcus@localhost` is a
# side effect, occasionally a useful one on the headless box.
{ ... }:

{
  services.openssh = {
    enable = true;
    openFirewall = false;
    listenAddresses = [
      {
        addr = "127.0.0.1";
        port = 22;
      }
    ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
