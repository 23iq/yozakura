# Main Yozakura package
{ pkgs, lib, self, system, version }:

let
  quickshellPkg = pkgs.quickshell;

  # Import sub-packages
  ttf-phosphor-icons = import ./phosphor-icons.nix { inherit pkgs; };

  # Import modular package lists
  corePkgs = import ./core.nix { inherit pkgs quickshellPkg; };
  toolsPkgs = import ./tools.nix { inherit pkgs; };
  mediaPkgs = import ./media.nix { inherit pkgs; };
  appsPkgs = import ./apps.nix { inherit pkgs; };
  fontsPkgs = import ./fonts.nix { inherit pkgs ttf-phosphor-icons; };
  tesseractPkgs = import ./tesseract.nix { inherit pkgs; };

  # Combine all packages (NixOS-specific deps handled by the module)
  baseEnv = corePkgs
    ++ toolsPkgs
    ++ mediaPkgs
    ++ appsPkgs
    ++ fontsPkgs
    ++ tesseractPkgs;

  envYozakura = pkgs.buildEnv {
    name = "Yozakura-env";
    paths = baseEnv;
  };

  # Create fontconfig configuration to find bundled fonts
  fontconfigConf = pkgs.writeTextDir "etc/fonts/conf.d/99-yozakura-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <dir>${envYozakura}/share/fonts</dir>
    </fontconfig>
  '';

  # Build the Go backend (daemon + CLI) and the compositor daemon; both land
  # in the same bin/, where the backend looks for the daemon first
  backendPkg = import ./backend.nix { inherit pkgs lib version; };

  # Copy shell sources to the Nix store
  shellSrc = pkgs.stdenv.mkDerivation {
    pname = "yozakura-shell";
    inherit version;
    src = lib.cleanSource self;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r . $out/
    '';
  };

  launcher = pkgs.writeShellScriptBin "yozakura" ''
    export YOZAKURA_QS="${quickshellPkg}/bin/qs"
    export YOZAKURA_SHELL="${shellSrc}"
    export PATH="${envYozakura}/bin:$PATH"

    # Set QML2_IMPORT_PATH to include modules from envYozakura (like syntax-highlighting)
    export QML2_IMPORT_PATH="${envYozakura}/lib/qt-6/qml:$QML2_IMPORT_PATH"
    export QML_IMPORT_PATH="$QML2_IMPORT_PATH"

    # QtMultimedia: force the GStreamer backend and its plugin dir
    export QT_MEDIA_BACKEND="''${QT_MEDIA_BACKEND:-gstreamer}"
    export GST_PLUGIN_SYSTEM_PATH="''${GST_PLUGIN_SYSTEM_PATH:-${envYozakura}/lib/gstreamer-1.0}"
    export QT_PLUGIN_PATH="''${QT_PLUGIN_PATH:-${envYozakura}/lib/qt-6/plugins}"

    # Make bundled fonts available to fontconfig
    export FONTCONFIG_PATH="${fontconfigConf}/etc/fonts:''${FONTCONFIG_PATH:-}"

    # Delegate execution to the Go backend
    exec ${backendPkg}/bin/yozakura "$@"
  '';

in pkgs.buildEnv {
  name = "Yozakura-${version}";
  paths = [ envYozakura launcher ];
  meta.mainProgram = "yozakura";
}
