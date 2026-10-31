{
  description = "Yozakura - night-sakura desktop shell for Hyprland, niri and MangoWC";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      yozakuraLib = import ./nix/lib.nix { inherit nixpkgs; };
      version = nixpkgs.lib.removeSuffix "\n" (builtins.readFile ./version);
      lib = nixpkgs.lib;

      pkgsFor = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      # programs.yozakura.* (docs/nixos.md)
      nixosModules.default = { pkgs, lib, ... }: {
        imports = [ ./nix/modules ];
        programs.yozakura.enable = lib.mkDefault true;
        programs.yozakura.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      };

      packages = yozakuraLib.forAllSystems (system:
        let
          pkgs = pkgsFor system;
          # .override { withVoice = true; voiceAcceleration = "vulkan"; withDepth = true; }
          Yozakura = lib.makeOverridable (import ./nix/packages) {
            inherit pkgs lib self version;
          };
        in {
          default = Yozakura;
          Yozakura = Yozakura;
          backend = import ./nix/packages/backend.nix {
            inherit pkgs lib version;
          };
          sddm-theme = import ./nix/packages/sddm-theme.nix {
            inherit pkgs lib version;
          };
        }
      );

      # Development: `nix develop`, then `make build && ./yozakura`
      devShells = yozakuraLib.forAllSystems (system:
        let
          pkgs = pkgsFor system;
          Yozakura = self.packages.${system}.default;
        in {
          default = pkgs.mkShell {
            packages = [ Yozakura ] ++ (with pkgs; [
              go_1_26
              gnumake
              nodejs
              python3
              shellcheck
              ruff
              go-tools
              qt6.qtdeclarative
            ]);
            # A terminal opened from the installed shell inherits its
            # packaging variables: the checkout must run its own sources,
            # yozd and binary instead
            shellHook = ''
              unset YOZAKURA_SHELL YOZAKURA_LAUNCHER YOZAKURA_DAEMON_BIN YOZAKURA_BIN
              export YOZAKURA_QS="${Yozakura.qsWrapper}"
              export YOZAKURA_NIX_ENV="${Yozakura.envYozakura}"
              export QML2_IMPORT_PATH="${Yozakura.envYozakura}/lib/qt-6/qml''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
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
