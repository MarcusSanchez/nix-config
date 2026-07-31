# The sops.* options exist on this platform because of this import; every
# value set on them lives in modules/common/secrets.nix, shared with NixOS.
{ inputs, ... }:

{
  imports = [ inputs.sops-nix.darwinModules.sops ];
}
