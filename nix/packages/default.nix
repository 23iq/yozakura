# Main Yozakura package. Optional features are package arguments, so
# `pkg.override { withVoice = true; }` (or the NixOS module options) turns
# them on without forking the flake.
{ pkgs
, lib
, self
, version
  # Dictation: a packaged whisper.cpp server instead of a source build
, withVoice ? false
  # "cpu", "vulkan" (AMD/Intel) or "cuda" (NVIDIA, unfree)
, voiceAcceleration ? "cpu"
  # Depth clock: Python with rembg instead of a pip venv
, withDepth ? false
}:

assert lib.assertOneOf "voiceAcceleration" voiceAcceleration [ "cpu" "vulkan" "cuda" ];

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

  whisperPkg = pkgs.whisper-cpp.override {
    vulkanSupport = voiceAcceleration == "vulkan";
    cudaSupport = voiceAcceleration == "cuda";
  };

  depthPython = pkgs.python3.withPackages (ps: with ps; [ rembg onnxruntime pillow numpy ]);

  # Combine all packages (NixOS-specific deps handled by the module)
  baseEnv = corePkgs
    ++ toolsPkgs
    ++ mediaPkgs
    ++ appsPkgs
    ++ fontsPkgs
    ++ tesseractPkgs
    ++ [ pkgs.gsettings-desktop-schemas ];

  envYozakura = pkgs.buildEnv {
    name = "yozakura-env";
    paths = baseEnv;
  };

  # The system fontconfig setup plus the bundled fonts (FONTCONFIG_PATH would
  # replace the whole config dir and hide the system fonts)
  fontsConf = pkgs.writeText "yozakura-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
      <dir>${envYozakura}/share/fonts</dir>
      <cachedir prefix="xdg">fontconfig</cachedir>
    </fontconfig>
  '';

  # Build the Go backend (daemon + CLI) and the compositor daemon
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

  schemasDir = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}";

  # Quickshell with the Qt plugins (multimedia, image formats), QML modules
  # and GStreamer plugins it needs, prepended so the session's own values
  # (NixOS sets QT_PLUGIN_PATH) cannot hide them. Only Quickshell gets them.
  qsWrapper = pkgs.writeShellScript "yozakura-qs" ''
    export QT_PLUGIN_PATH="${envYozakura}/lib/qt-6/plugins''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
    export QML2_IMPORT_PATH="${envYozakura}/lib/qt-6/qml''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
    export QML_IMPORT_PATH="$QML2_IMPORT_PATH"
    export GST_PLUGIN_SYSTEM_PATH_1_0="${envYozakura}/lib/gstreamer-1.0''${GST_PLUGIN_SYSTEM_PATH_1_0:+:$GST_PLUGIN_SYSTEM_PATH_1_0}"
    export QT_MEDIA_BACKEND="''${QT_MEDIA_BACKEND:-gstreamer}"
    exec ${quickshellPkg}/bin/qs "$@"
  '';

  launcher = pkgs.writeShellScriptBin "yozakura" (''
    # The stable command that starts this package (profile symlink), written
    # into compositor autostart and binds; never the store path, which
    # changes on every update and is garbage-collected later.
    self="$(readlink -f "$0")"
    launcher="$self"
    for cand in "$(command -v yozakura 2>/dev/null)" \
        "/etc/profiles/per-user/''${USER:-$(id -un)}/bin/yozakura" \
        "$HOME/.nix-profile/bin/yozakura" \
        "/run/current-system/sw/bin/yozakura"; do
        case "$cand" in "" | /nix/store/*) continue ;; esac
        if [ -x "$cand" ] && [ "$(readlink -f "$cand")" = "$self" ]; then
            launcher="$cand"
            break
        fi
    done
    export YOZAKURA_LAUNCHER="$launcher"

    export YOZAKURA_QS="${qsWrapper}"
    export YOZAKURA_SHELL="${shellSrc}"
    export YOZAKURA_DAEMON_BIN="${backendPkg}/bin/yozd"
    export YOZAKURA_NIX_ENV="${envYozakura}"
    export YOZAKURA_XKB_ROOT="${pkgs.xkeyboard_config}/share/X11/xkb"
    # NixOS's setuid/setgid wrappers (plocate from services.locate,
    # gpu-screen-recorder, ...) before the plain store binaries
    export PATH="/run/wrappers/bin:${envYozakura}/bin:$PATH"

    # Bundled apps, icons, GTK themes and the GNOME interface schemas
    # (gsettings reads icon-theme and color-scheme)
    export XDG_DATA_DIRS="''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:${envYozakura}/share:${schemasDir}"
    export GIO_EXTRA_MODULES="''${GIO_EXTRA_MODULES:-${pkgs.dconf.lib}/lib/gio/modules}"

    # Kept when the user set their own; replaced when it is an older copy
    # of this one (a reload from an environment started before an update)
    case "''${FONTCONFIG_FILE:-}" in
        "" | /nix/store/*-yozakura-fonts.conf) export FONTCONFIG_FILE="${fontsConf}" ;;
    esac
  '' + lib.optionalString withVoice ''
    export YOZAKURA_WHISPER_BIN_DIR="${whisperPkg}/bin"
    export YOZAKURA_WHISPER_BACKEND="${voiceAcceleration}"
  '' + lib.optionalString withDepth ''
    export YOZAKURA_DEPTH_PYTHON="${depthPython}/bin/python3"
  '' + ''

    # Delegate execution to the Go backend
    exec ${backendPkg}/bin/yozakura "$@"
  '');

in pkgs.buildEnv {
  name = "yozakura-${version}";
  paths = [ envYozakura launcher ];
  # Commands and data only: Qt plugins and QML modules stay private to the
  # Quickshell wrapper instead of landing in the system profile's
  # lib/qt-6, which every Qt app of the session reads
  pathsToLink = [ "/bin" "/share" ];
  # yozd next to the launcher: the daemon resolves `yozakura`/`yozd` exec
  # binds from the launcher's directory
  postBuild = ''
    ln -s ${backendPkg}/bin/yozd $out/bin/yozd
  '';
  passthru = { inherit backendPkg envYozakura shellSrc qsWrapper; };
  meta = {
    description = "Yozakura desktop shell for Hyprland, niri and MangoWC";
    mainProgram = "yozakura";
    platforms = lib.platforms.linux;
  };
}
