# The sops.* options exist on this platform because of this import; every
# value set on them lives in modules/common/secrets.nix, shared with darwin.
{ inputs, ... }:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];
}
