# Credentials on the mac. Mirror of modules/nixos/secrets.nix — see that
# file for why the system module is used rather than the home-manager one.
#
# This machine decrypts with its own identity, derived from
# /etc/ssh/ssh_host_ed25519_key. nix-darwin has no services.openssh.enable
# (macOS owns sshd), so unlike the WSL boxes there's nothing here to
# generate that key — macOS does it. If it's ever missing, toggling
# System Settings > General > Sharing > Remote Login on and off once
# creates it permanently.
{ inputs, ... }:

{
  imports = [ inputs.sops-nix.darwinModules.sops ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
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
