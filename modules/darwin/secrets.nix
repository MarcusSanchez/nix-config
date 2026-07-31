# Credentials on the mac. Mirror of modules/nixos/secrets.nix — see that
# file for why the system module is used rather than the home-manager one.
#
# Same single identity as the WSL boxes: the personal age key from Bitwarden,
# at /var/lib/sops-nix/key.txt. Place it with the commands in that file.
{ config, inputs, ... }:

{
  imports = [ inputs.sops-nix.darwinModules.sops ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
    age.sshKeyPaths = [ ];
    # Age only — the default hunts for an RSA host key and fails activation.
    gnupg.sshKeyPaths = [ ];

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
      path = "/Users/marcussanchez/.config/gh/hosts.yml";
      owner = "marcussanchez";
      mode = "0600";
    };

    secrets = {
      gh_token = {
        owner = "marcussanchez";
        mode = "0400";
      };
      fly_token = {
        owner = "marcussanchez";
        mode = "0400";
      };
      # croc's code phrase. The home layer exports it as CROC_SECRET, which
      # makes `croc send <file>` and bare `croc` pair without a code.
      croc_secret = {
        owner = "marcussanchez";
        mode = "0400";
      };

      atuin_key = {
        owner = "marcussanchez";
        mode = "0400";
      };
      atuin_username = {
        owner = "marcussanchez";
        mode = "0400";
      };
      atuin_password = {
        owner = "marcussanchez";
        mode = "0400";
      };
    };
  };
}
