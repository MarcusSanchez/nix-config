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
    # claude-code deliberately does NOT follow our nixpkgs: its binary cache
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

      # hostname -> which host module shapes it. Attribute names ARE the
      # hostnames: each is passed to its module as `hostName` via specialArgs
      # and assigned there, so the two can't drift the way they would if the
      # module hardcoded its own name. Several entries may share a module —
      # that's how a second identical WSL box gets added, as one line here
      # and nothing else.
      nixosConfigurations =
        nixpkgs.lib.mapAttrs
          (
            hostName: hostModule:
            nixpkgs.lib.nixosSystem {
              specialArgs = { inherit inputs hostName; };
              modules = [ hostModule ];
            }
          )
          {
            bedroom-wsl = ./hosts/wsl;
            nixos-lite = ./hosts/wsl-lite;
            office-lite-wsl-1 = ./hosts/wsl-lite;
            office-lite-wsl-2 = ./hosts/wsl-lite;
            tuf-nixos = ./hosts/tuf;
          };

      # Same shape as above: the attribute IS the hostname, passed down as
      # `hostName`. Bare `sudo darwin-rebuild switch` resolves
      # darwinConfigurations.<scutil --get LocalHostName>, so the two must
      # agree — deriving it means they can't drift.
      darwinConfigurations = nixpkgs.lib.mapAttrs (
        hostName: hostModule:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit inputs hostName; };
          modules = [ hostModule ];
        }
      ) { "macbook-air" = ./hosts/mac; };
    };
}
