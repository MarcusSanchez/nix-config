{
  description = "Marcus's Nix configuration (NixOS-WSL + macOS + bare-metal NixOS)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # darwin rides nixpkgs-unstable: same trunk as nixos-unstable, but the
    # darwin binary caches populate here first
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    # Installs and owns the Homebrew prefix itself. nix-darwin's homebrew.*
    # options only drive `brew bundle` and assume brew is already there, so
    # this is the piece that makes a fresh mac reproducible. No follows:
    # its only input is the brew source it pins, and it has no nixpkgs.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # claude-code deliberately does NOT follow the flake's nixpkgs: its binary cache
    # is built against its own pin, and a follows would force local rebuilds
    claude-code.url = "github:sadjow/claude-code-nix";
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # prebuilt weekly nix-index databases (both platforms) — what makes
    # comma work without ever running `nix-index` by hand
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # decrypts secrets/ into place at activation, so CLIs come up already
    # authenticated — see home/marcus/common/secrets.nix
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ONLY for nixosModules.greeter (the dms-greeter greetd module nixpkgs
    # lacks) — the shell itself is nixpkgs' dms-shell so it rides the
    # binary cache. Don't collapse the split.
    dank-material-shell = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Secure Boot signing for the dual-boot desktop (naut-dt only —
    # Windows on the same machine effectively requires SB). Pinned to a
    # release tag on purpose; bump deliberately, not via flake update.
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      nixpkgs-darwin,
      nix-darwin,
      ...
    }:
    {
      # `nix fmt` formats the whole tree
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
      formatter.aarch64-darwin = nixpkgs-darwin.legacyPackages.aarch64-darwin.nixfmt-tree;

      # hostname -> the module LIST that shapes it. Attribute names ARE the
      # hostnames: each is passed to its modules as `hostName` via specialArgs
      # and assigned there, so the two can't drift the way they would if the
      # module hardcoded its own name. Several entries may share a kind —
      # that's how a second identical WSL box gets added, as one line here
      # and nothing else — and a per-machine fact that isn't hardware truth
      # (the rustdesk bridge on the remotely-controlled PCs) rides the
      # entry's list instead of forking the kind.
      nixosConfigurations =
        let
          cfgs =
            nixpkgs.lib.mapAttrs
              (
                hostName: hostModules:
                nixpkgs.lib.nixosSystem {
                  specialArgs = { inherit inputs hostName; };
                  modules = hostModules;
                }
              )
              {
                # secrets-super on an entry = this machine holds its own age
                # key, a recipient of secrets/super.yaml. The line must track
                # key reality — see modules/common/secrets-super.nix.
                naut-box = [
                  ./hosts/wsl
                  ./modules/common/secrets-super.nix
                ];

                framework-dt = [
                  ./hosts/wsl
                  ./modules/wsl/rustdesk-bridge.nix
                ];
                office-one = [
                  ./hosts/wsl
                  ./modules/wsl/rustdesk-bridge.nix
                ];
                office-two = [
                  ./hosts/wsl
                  ./modules/wsl/rustdesk-bridge.nix
                ];

                tuf-laptop = [
                  ./hosts/tuf-laptop
                  ./modules/common/secrets-super.nix
                ];
                naut-dt = [
                  ./hosts/naut-dt
                  ./modules/common/secrets-super.nix
                ];
              };
        in
        cfgs
        # TRANSITION aliases: a machine resolves its config by its CURRENT
        # hostname, so until each box has activated a new-name generation
        # (and, on WSL, restarted the distro so wsl.conf applies it) the
        # old attribute must keep working. Each alias IS the new-name
        # config — activating it renames the machine, so every box
        # self-migrates on its next switch/autoUpgrade. Delete a line once
        # its machine reports the new hostname.
        // {
          bedroom-wsl = cfgs.naut-box;
          framework-wsl = cfgs.framework-dt;
          office-lite-wsl-1 = cfgs.office-one;
          office-lite-wsl-2 = cfgs.office-two;
          tuf-nixos = cfgs.tuf-laptop;
          bedroom-nixos = cfgs.naut-dt;
        };

      # Same shape as above: the attribute IS the hostname, passed down as
      # `hostName`. Bare `sudo darwin-rebuild switch` resolves
      # darwinConfigurations.<scutil --get LocalHostName>, so the two must
      # agree — deriving it means they can't drift.
      darwinConfigurations =
        nixpkgs.lib.mapAttrs
          (
            hostName: hostModules:
            nix-darwin.lib.darwinSystem {
              specialArgs = { inherit inputs hostName; };
              modules = hostModules;
            }
          )
          {
            macbook-air = [
              ./hosts/darwin
              ./modules/common/secrets-super.nix
            ];
          };
    };
}
