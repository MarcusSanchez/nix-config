# Credentials, so no machine ever needs a CLI login.
#
# secrets/secrets.yaml holds them encrypted with age — safe in a public
# repo, since only the values are encrypted and only this key can unwrap
# them. sops-nix decrypts at every activation and every boot and drops
# each one at the path its CLI expects, so `git pull && nixos-rebuild` is
# the whole setup step on a new machine.
#
# The one thing that can't be automated is the key itself: the private
# half must reach the machine out of band BEFORE the first rebuild, or
# activation fails here with "age: no identity matched any of the
# recipients". Put it at ~/.config/sops/age/keys.txt (mode 600) — either
# `croc send ~/.config/sops/age/keys.txt` from a machine that already has
# it, or paste it out of Bitwarden. Never commit it.
#
# To change a credential: `sops secrets/secrets.yaml` opens the plaintext
# in $EDITOR and re-encrypts on save. To add a machine with its own key,
# add it to .sops.yaml and run `sops updatekeys secrets/secrets.yaml`.
{
  inputs,
  config,
  ...
}:

{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  sops = {
    defaultSopsFile = ../../../secrets/secrets.yaml;
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

    # gh's own config.yml is HM-managed (see git.nix); hosts.yml is the
    # separate file `gh auth login` would write, and holds the token
    secrets.gh_hosts = {
      path = "${config.home.homeDirectory}/.config/gh/hosts.yml";
      mode = "0600";
    };

    secrets.fly_config = {
      path = "${config.home.homeDirectory}/.fly/config.yml";
      mode = "0600";
    };
  };
}
