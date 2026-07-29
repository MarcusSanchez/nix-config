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
# recipients". Put it at ~/.config/sops/age/keys.txt (mode 600). Never
# commit it.
#
# Watch the ordering: croc and rbw are installed BY the rebuild, so a
# machine that hasn't rebuilt has neither, and it can't rebuild without
# the key. Use `nix shell nixpkgs#croc` / `nixpkgs#rbw`, which need
# nothing installed — the README's Secrets section has the commands.
#
# To change a credential: `sops secrets/secrets.yaml` opens the plaintext
# in $EDITOR and re-encrypts on save. To add a machine with its own key,
# add it to .sops.yaml and run `sops updatekeys secrets/secrets.yaml`.
{
  inputs,
  config,
  lib,
  ...
}:

{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  sops = {
    defaultSopsFile = ../../../secrets/secrets.yaml;
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

    secrets = {
      # gh's own config.yml is HM-managed (see git.nix); hosts.yml is the
      # separate file `gh auth login` would write, and holds the token
      gh_hosts = {
        path = "${config.home.homeDirectory}/.config/gh/hosts.yml";
        mode = "0600";
      };

      fly_config = {
        path = "${config.home.homeDirectory}/.fly/config.yml";
        mode = "0600";
      };

      # atuin is the odd one out: it keeps its session as a `hub_session`
      # row inside meta.db, not a file, so there's nothing to drop into
      # place. Instead it logs itself in below from these three. (Its
      # Hub API token would authenticate too, but no CLI flag installs
      # one — `atuin account link` is the only path and it's interactive.)
      atuin_username = { };
      atuin_password = { };
      atuin_key = { };
    };
  };

  # Log in only when this machine isn't already — atuin then writes its
  # own session, and later activations no-op. Never fails the rebuild:
  # offline is a normal state and sync catches up on its own.
  #
  # atuin_key is the one credential here that can't be reissued: it's the
  # E2E key for the synced history, so losing every copy makes the server
  # side permanently unreadable. This is its backup as much as its
  # deployment.
  home.activation.atuinLogin = lib.hm.dag.entryAfter [ "sops-nix" ] ''
    atuin=${config.programs.atuin.package}/bin/atuin
    if ! timeout 10 "$atuin" status 2>/dev/null | grep -q '^Username:'; then
      echo "atuin: not logged in on this machine — logging in" >&2
      # -p puts the password in argv for the length of one exec; these are
      # single-user machines, and atuin offers no stdin or env alternative
      timeout 30 "$atuin" login \
        -u "$(cat ${config.sops.secrets.atuin_username.path})" \
        -p "$(cat ${config.sops.secrets.atuin_password.path})" \
        -k "$(cat ${config.sops.secrets.atuin_key.path})" >/dev/null 2>&1 \
        || echo "atuin: login failed (offline, or the stored password is stale)" >&2
    fi
  '';
}
