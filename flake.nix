{
  description = "Yozakura - night-sakura desktop shell for Hyprland";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      yozakuraLib = import ./nix/lib.nix { inherit nixpkgs; };
      version = nixpkgs.lib.removeSuffix "\n" (builtins.readFile ./version);
    in {
      nixosModules.default = { pkgs, lib, ... }: {
        imports = [ ./nix/modules ];
        programs.yozakura.enable = lib.mkDefault true;
        programs.yozakura.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      };

      packages = yozakuraLib.forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          lib = nixpkgs.lib;

          Yozakura = import ./nix/packages {
            inherit pkgs lib self system version;
          };
        in {
          default = Yozakura;
          Yozakura = Yozakura;
          backend = import ./nix/packages/backend.nix {
            inherit pkgs lib version;
          };
        }
      );

      devShells = yozakuraLib.forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          Yozakura = self.packages.${system}.default;
        in {
          default = pkgs.mkShell {
            packages = [ Yozakura ];
            shellHook = ''
              export QML2_IMPORT_PATH="${Yozakura}/lib/qt-6/qml:$QML2_IMPORT_PATH"
              export QML_IMPORT_PATH="$QML2_IMPORT_PATH"
              echo "Yozakura dev environment loaded."
            '';
          };
        }
      );

      apps = yozakuraLib.forAllSystems (system:
        let
          Yozakura = self.packages.${system}.default;
        in {
          default = {
            type = "app";
            program = "${Yozakura}/bin/yozakura";
          };
        }
      );
    };
}
