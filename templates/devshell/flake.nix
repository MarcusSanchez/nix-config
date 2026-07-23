{
  description = "Project dev shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      # Same shell on the mac and on WSL
      forAllSystems = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "x86_64-linux"
      ];
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              # project-specific tools, e.g.:
              # go
              # sqlc
              # postgresql # just the client tools
            ];

            # env vars, e.g.:
            # DATABASE_URL = "postgres://localhost:5432/dev";
          };
        }
      );
    };
}
