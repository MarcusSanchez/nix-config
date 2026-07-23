{
  description = "Marcus's Nix configuration (NixOS-WSL + macOS)";

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

      # Scaffold a per-project dev shell: nix flake init -t /etc/nixos
      # (or -t ~/nix-config on the mac)
      templates.default = {
        path = ./templates/devshell;
        description = "mkShell dev environment with direnv auto-load";
      };

      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/wsl ];
      };

      # Activate with: sudo darwin-rebuild switch --flake ~/nix-config
      # (name matches `scutil --get LocalHostName`, so no #attr needed)
      darwinConfigurations."Marcuss-MacBook-Air" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/mac ];
      };
    };
}
