# Credentials, so no machine ever needs a CLI login. One file for both
# platforms — only the sops module import differs, and that lives in each
# platform aggregator (which is what makes the sops.* options exist here
# at all).
#
# Every machine decrypts with the SAME identity — the personal age key from
# Bitwarden, at /var/lib/sops-nix/key.txt. .sops.yaml therefore has exactly
# one recipient, so adding a machine never edits the recipient list and
# never needs `sops updatekeys`: place the key, switch, done.
#
# The file has to be there before a switch that installs secrets —
# sops-install-secrets treats a missing keyFile as fatal, not as a
# fallback, so it aborts the whole step. On a fresh box the first switch
# fails it harmlessly, then:
#   sudo install -d -m 0700 /var/lib/sops-nix
#   rbw get -f notes "sops age key - nix-config (all machines)" \
#     | sudo tee /var/lib/sops-nix/key.txt >/dev/null
#   sudo chmod 0400 /var/lib/sops-nix/key.txt
# (tee, not `install /dev/stdin`: BSD install rejects a non-regular source,
# so that form works on Linux and fails on the mac. The 0700 parent is what
# keeps the file private between tee and chmod.)
#
# Secrets are decrypted to /run/secrets (tmpfs) owned by the user; the home
# layer wires each one to its tool. To change a credential:
# `sops secrets/secrets.yaml` opens the plaintext in $EDITOR. The same
# ordering rule as the keyFile applies to VALUES: a declared secret missing
# from secrets.yaml aborts the entire install ("the key 'x' cannot be
# found"), so a new value lands in secrets.yaml before or with its wiring.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  user = if pkgs.stdenv.isDarwin then "marcussanchez" else "marcus";
  home = if pkgs.stdenv.isDarwin then "/Users/marcussanchez" else "/home/marcus";
in
{
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

    # gh's state file, rendered at activation with only the token coming
    # from ciphertext — the structure is reviewable here. Still not
    # programs.gh.hosts, which would bake the token into a world-readable
    # /nix/store path. gh needs the token twice; that duplication is gh's
    # format, not an accident.
    templates."gh-hosts.yml" = {
      content = ''
        github.com:
            users:
                MarcusSanchez:
                    oauth_token: ${config.sops.placeholder.gh_token}
            git_protocol: https
            user: MarcusSanchez
            oauth_token: ${config.sops.placeholder.gh_token}
      '';
      path = "${home}/.config/gh/hosts.yml";
      owner = user;
      mode = "0600";
    };

    # Bare values, all owner-read-only. What each one is:
    #   gh_token        rendered into gh-hosts.yml above
    #   fly_token       a fly ORG token (`fly tokens create org`) — static,
    #                   unlike the session macaroon `fly auth login` leaves
    #                   behind; exported as FLY_API_TOKEN by
    #                   home/marcus/common/secrets.nix
    #   croc_secret     croc's code phrase, exported as CROC_SECRET — same
    #                   value everywhere means bare `croc send`/`croc` pair
    #   atuin_key       E2E history key (programs.atuin key_path) — the one
    #                   credential that can't be reissued; losing every copy
    #                   leaves the server side unreadable
    #   atuin_username  with atuin_password, the activation-hook login
    #   atuin_password
    secrets =
      lib.genAttrs
        [
          "gh_token"
          "fly_token"
          "croc_secret"
          "atuin_key"
          "atuin_username"
          "atuin_password"
        ]
        (_: {
          owner = user;
          mode = "0400";
        });
  };
}
