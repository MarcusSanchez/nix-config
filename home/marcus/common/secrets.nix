# User-side wiring for the credentials that modules/common/secrets.nix
# decrypts. The sops module itself is the SYSTEM one, not the home-manager
# one — that choice matters:
#
#   * the HM module registers its activation entry as a bare string, which
#     home-manager coerces to entryAnywhere — no ordering guarantees at
#     all (sops-nix#581, open). Consumers routinely run before the secrets
#     exist. The system module decrypts before any user activation.
#
# So this file holds only the parts that are genuinely user-scoped.
{ config, lib, ... }:

{
  # flyctl reads FLY_API_TOKEN ahead of its config file, which leaves
  # ~/.fly/config.yml entirely to flyctl — free to persist wireguard peer
  # state and refresh its own tokens without us clobbering them. Installing
  # the token isn't an option: `fly auth login -t <token>` lists the flag in
  # --help but ignores it and opens a browser (tested 2026-07-29).
  #
  # Guarded so a machine whose secrets aren't decrypted yet starts without
  # the variable rather than erroring. Bare token since 2026-07-31 — the
  # old fly_config held a whole config.yml and needed sed.
  # croc takes its code phrase from CROC_SECRET, so with the same value
  # exported everywhere, bare `croc send <file>` and bare `croc` pair up
  # across machines with no code to read out. $(cat) drops the trailing
  # newline, which would otherwise make the phrases not match.
  home.sessionVariablesExtra = ''
    if [ -r /run/secrets/fly_token ]; then
      export FLY_API_TOKEN="$(cat /run/secrets/fly_token)"
    fi
    if [ -r /run/secrets/croc_secret ]; then
      export CROC_SECRET="$(cat /run/secrets/croc_secret)"
    fi
  '';

  # atuin keeps its session as a hub_session row in meta.db rather than a
  # file, so unlike the key there's nothing to point it at — session_path
  # was removed in 18.x, leaving only a one-time legacy-file migration. So
  # the session still needs one login per machine. The key itself comes
  # from key_path (see shell.nix), so -k isn't needed here.
  #
  # entryAfter "writeBoundary" is enough now: the system module decrypts
  # during system activation, well before home-manager runs.
  home.activation.atuinLogin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    atuin=${config.programs.atuin.package}/bin/atuin
    if [ ! -r /run/secrets/atuin_password ]; then
      echo "atuin: secrets not decrypted — skipping login" >&2
    elif ! timeout 10 "$atuin" status 2>/dev/null | grep -q '^Username:'; then
      echo "atuin: not logged in on this machine — logging in" >&2
      # </dev/null is load-bearing: even with -u and -p, `atuin login`
      # still prompts "enter encryption key [blank to use existing key
      # file]". With no stdin it hangs until the timeout kills it, which
      # is why this silently did nothing on the mac. Feeding it EOF takes
      # the blank default — i.e. the key from key_path, which is the sops
      # secret.
      timeout 30 "$atuin" login \
        -u "$(cat /run/secrets/atuin_username)" \
        -p "$(cat /run/secrets/atuin_password)" </dev/null >/dev/null 2>&1 \
        || echo "atuin: login failed (offline, or the stored password is stale)" >&2
    fi
  '';
}
