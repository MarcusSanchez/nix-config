# Credentials, so no machine ever needs a CLI login.
#
# This machine decrypts with ITS OWN identity: sops-nix converts
# /etc/ssh/ssh_host_ed25519_key (see ssh.nix, which exists to generate it)
# into an age key. No private key is ever copied between machines —
# onboarding one means adding its *public* key to .sops.yaml and running
# `sops updatekeys secrets/secrets.yaml`. The personal age key in
# ~/.config/sops/age/keys.txt is only for *editing* secrets.
#
# Secrets are decrypted to /run/secrets (tmpfs) owned by marcus; the home
# layer wires each one to its tool. To change a credential:
# `sops secrets/secrets.yaml` opens the plaintext in $EDITOR.
{ inputs, ... }:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;

    # Explicit rather than relying on the default: that's derived from
    # services.openssh.hostKeys and doesn't track changes reliably
    # (sops-nix#203).
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    # Age only. Left at its default this looks for an RSA host key that
    # ssh.nix doesn't generate, and activation dies with "Cannot read ssh
    # key '/etc/ssh/ssh_host_rsa_key'" — the most common sops-nix
    # first-boot failure.
    gnupg.sshKeyPaths = [ ];

    secrets = {
      # gh reads this directly; it's the file `gh auth login` would write.
      # Deliberately not programs.gh.hosts, which would put the token in a
      # world-readable /nix/store path.
      gh_hosts = {
        owner = "marcus";
        mode = "0600";
        path = "/home/marcus/.config/gh/hosts.yml";
      };

      # Read by the shell export in home/marcus/common/secrets.nix. Holds
      # a fly ORG token (`fly tokens create org`) — static, unlike the
      # session macaroon `fly auth login` leaves behind, which carries a
      # 10-minute discharge and dies with the session.
      fly_config = {
        owner = "marcus";
        mode = "0400";
      };

      # atuin points at this via programs.atuin.settings.key_path. It's the
      # E2E key for synced history and the one credential here that can't
      # be reissued — losing every copy leaves the server side unreadable.
      atuin_key = {
        owner = "marcus";
        mode = "0400";
      };
      atuin_username = {
        owner = "marcus";
        mode = "0400";
      };
      atuin_password = {
        owner = "marcus";
        mode = "0400";
      };
    };
  };
}
