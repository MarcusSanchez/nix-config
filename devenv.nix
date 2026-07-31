# This repo as its own devenv project: operational scripts that exist on
# PATH whenever you're cd'd into ~/nix-config (direnv loads them; run
# `direnv allow` once per machine). The colon names work because devenv
# sanitizes the DERIVATION name but keeps the script filename verbatim —
# verified empirically after a source-read wrongly said otherwise.
#
# The tools these wrap (sops, rbw, age, nh, the linters) all come from the
# system config, not from this shell — the scripts are ergonomics, not a
# toolchain, so a box that hasn't run direnv still does everything the
# README way.
{ ... }:

{
  scripts = {
    # `sops` on the one file it ever means here.
    "secrets:edit".exec = ''
      exec sops "$DEVENV_ROOT/secrets/secrets.yaml"
    '';

    # The whole of onboarding a machine into secrets: fetch the personal
    # age key from Bitwarden, place the machine copy (root, what
    # activation decrypts with) and the editing copy (user, what `sops`
    # uses), then prove the key matches the recipient in .sops.yaml.
    "age:place".exec = ''
      set -euo pipefail
      note="sops age key - nix-config (all machines)"

      sudo install -d -m 0700 /var/lib/sops-nix
      rbw get -f notes "$note" | sudo tee /var/lib/sops-nix/key.txt >/dev/null
      sudo chmod 0400 /var/lib/sops-nix/key.txt

      install -d -m 0700 "$HOME/.config/sops/age"
      rbw get -f notes "$note" > "$HOME/.config/sops/age/keys.txt"
      chmod 600 "$HOME/.config/sops/age/keys.txt"

      want=$(grep -o 'age1[a-z0-9]*' "$DEVENV_ROOT/.sops.yaml" | head -1)
      got=$(age-keygen -y "$HOME/.config/sops/age/keys.txt")
      if [ "$got" = "$want" ]; then
        echo "key placed and verified: $got"
        echo "next: nh os switch   (or: nh darwin switch)"
      else
        echo "MISMATCH: placed key is $got but .sops.yaml expects $want" >&2
        echo "wrong Bitwarden item? nothing will decrypt until this matches" >&2
        exit 1
      fi
    '';

    # Are the three secret-fed tools actually authenticated. Reads the fly
    # token from /run/secrets itself, so it works in any shell — the
    # interactive export only exists in login shells. All three run even if
    # one fails; nonzero exit if any did.
    "secrets:status".exec = ''
      set -u; fail=0
      echo "── gh"
      gh auth status || fail=1
      echo "── atuin"
      atuin status 2>/dev/null | grep '^Username' || { echo "not logged in"; fail=1; }
      echo "── fly"
      FLY_API_TOKEN="$(cat /run/secrets/fly_token 2>/dev/null)" timeout 15 fly auth whoami || fail=1
      exit "$fail"
    '';

    # The same gate CI runs, locally: format, lint, evaluate every host.
    "config:check".exec = ''
      cd "$DEVENV_ROOT"
      nix fmt
      statix check .
      deadnix --fail .
      nix flake check
    '';

  };
}
