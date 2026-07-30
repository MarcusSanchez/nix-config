# Credentials, so no machine ever needs a CLI login.
#
# Every machine decrypts with the SAME identity — the personal age key from
# Bitwarden, at /var/lib/sops-nix/key.txt. .sops.yaml therefore has exactly
# one recipient, so adding a machine never edits the recipient list and never
# needs `sops updatekeys`: place the key, switch, done.
#
# The file has to be there before a switch that installs secrets —
# sops-install-secrets treats a missing keyFile as fatal, not as a fallback,
# so it aborts the whole step. On a fresh box the first switch fails it
# harmlessly, then:
#   sudo install -d -m 0700 /var/lib/sops-nix
#   rbw get -f notes "sops age key - nix-config (all machines)" \
#     | sudo tee /var/lib/sops-nix/key.txt >/dev/null
#   sudo chmod 0400 /var/lib/sops-nix/key.txt
# (tee, not `install /dev/stdin`: BSD install rejects a non-regular source,
# so that form works on Linux and fails on the mac. The 0700 parent is what
# keeps the file private between tee and chmod.)
#
# Secrets are decrypted to /run/secrets (tmpfs) owned by marcus; the home
# layer wires each one to its tool. To change a credential:
# `sops secrets/secrets.yaml` opens the plaintext in $EDITOR.
{ inputs, ... }:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;

    age.keyFile = "/var/lib/sops-nix/key.txt";
    # No SSH host key as a second identity: it isn't a recipient, so it would
    # decrypt nothing, and leaving it set implies a fallback that doesn't
    # exist.
    age.sshKeyPaths = [ ];
    # Age only. Left at its default this hunts for an RSA host key that isn't
    # generated, and activation dies with "Cannot read ssh key
    # '/etc/ssh/ssh_host_rsa_key'" — the most common sops-nix first-boot
    # failure.
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

      # croc's code phrase. The home layer exports it as CROC_SECRET, which
      # makes `croc send <file>` and bare `croc` pair without a code.
      croc_secret = {
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
