# The super tier: secrets whose file (secrets/super.yaml) only the
# trusted machines' own keys can open — never the roaming master from
# Bitwarden, so a vault compromise cannot reach them. Wired per-attr in
# flake.nix onto exactly the machines that hold such a key; there is no
# option or tier switch, the flake line IS the declaration. It must
# track key reality: a box that declares this without a super-capable
# key loses ALL its secrets, because sops-install-secrets aborts the
# whole install on the first file it cannot decrypt.
#
# Nothing unreissuable ever goes in super.yaml — a lost super secret
# must be re-creatable at its provider (atuin's E2E key stays in the
# lower tier, Bitwarden-recoverable, for exactly this reason).
{ config, ... }:

{
  # fly_token: a fly ORG token (`fly tokens create org`), static unlike
  # the session macaroon `fly auth login` leaves behind; exported as
  # FLY_API_TOKEN by home/marcus/common/secrets.nix, whose read-guard
  # makes boxes without it skip the export with no home-layer branching.
  sops.secrets.fly_token = {
    sopsFile = ../../secrets/super.yaml;
    owner = config.identity.username;
    mode = "0400";
  };
}
