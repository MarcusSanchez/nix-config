# Credentials on the mac. Mirror of modules/nixos/secrets.nix — see that
# file for why the system module is used rather than the home-manager one.
#
# Same single identity as the WSL boxes: the personal age key from Bitwarden,
# at /var/lib/sops-nix/key.txt. Place it with the commands in that file.
{ inputs, ... }:

{
  imports = [ inputs.sops-nix.darwinModules.sops ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
    age.sshKeyPaths = [ ];
    # Age only — the default hunts for an RSA host key and fails activation.
    gnupg.sshKeyPaths = [ ];

    secrets = {
      gh_hosts = {
        owner = "marcussanchez";
        mode = "0600";
        path = "/Users/marcussanchez/.config/gh/hosts.yml";
      };
      fly_config = {
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
