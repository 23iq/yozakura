# NixOS module for Yozakura: everything other distros get from the
# installer (packages, services, groups, polkit agent, login theme), as
# options. docs/nixos.md shows a full configuration.
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.yozakura;
  sddmDataDir = "/var/lib/yozakura-sddm";
  sddmTheme = import ../packages/sddm-theme.nix {
    inherit pkgs lib;
    version = cfg.package.version or "0";
    dataDir = sddmDataDir;
  };
  # The package with the optional features this module turns on
  finalPackage =
    if cfg.package ? override then
      cfg.package.override {
        withVoice = cfg.voice.enable;
        voiceAcceleration = cfg.voice.acceleration;
        withDepth = cfg.depth.enable;
      }
    else cfg.package;
in {
  options.programs.yozakura = {
    enable = lib.mkEnableOption "Yozakura shell";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The Yozakura package to use";
    };

    finalPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = finalPackage;
      description = "The package with the voice/depth options applied (what gets installed).";
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "alice" ];
      description = ''
        Desktop users added to the groups the shell needs: video
        (backlight), input (keyboard layout and idle detection) and i2c
        (external monitor brightness over DDC/CI).
      '';
    };

    fonts.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install Yozakura fonts (including Phosphor Icons)";
    };

    compositors = {
      hyprland = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Hyprland (started through UWSM).";
      };
      niri = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable niri (with xwayland-satellite for X11 apps).";
      };
      mango = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable MangoWC (programs.mango, nixpkgs 25.11 or newer).";
      };
    };

    voice = {
      enable = lib.mkEnableOption "dictation with a packaged whisper.cpp server (the models are still downloaded from Settings)";
      acceleration = lib.mkOption {
        type = lib.types.enum [ "cpu" "vulkan" "cuda" ];
        default = "cpu";
        description = "whisper.cpp backend: cpu, vulkan (AMD/Intel) or cuda (NVIDIA, unfree).";
      };
    };

    depth.enable = lib.mkEnableOption "the depth clock (Python with rembg; the model is downloaded from Settings)";

    sddm = {
      enable = lib.mkEnableOption "SDDM with the Yozakura login theme, synced with the shell's wallpaper and palette";
      user = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = if cfg.users == [ ] then null else lib.head cfg.users;
        defaultText = lib.literalExpression "lib.head config.programs.yozakura.users";
        description = "The desktop user who owns ${sddmDataDir} (the shell writes the theme state there).";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [{
        assertion = !cfg.sddm.enable || cfg.sddm.user != null;
        message = "programs.yozakura.sddm.enable needs programs.yozakura.sddm.user (or programs.yozakura.users).";
      }];

      # Register fonts with fontconfig (NixOS handles this via fonts.packages)
      fonts.packages = lib.mkIf cfg.fonts.enable (with pkgs; [
        roboto
        roboto-mono
        league-gothic
        terminus_font
        terminus_font_ttf
        dejavu_fonts
        liberation_ttf
        nerd-fonts.symbols-only
        nerd-fonts.iosevka
        noto-fonts
        noto-fonts-color-emoji
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
        (pkgs.callPackage ../packages/phosphor-icons.nix { })
      ]);

      xdg.portal = {
        enable = lib.mkDefault true;
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      };

      # Password prompts for system actions: hyprpolkitagent's user unit,
      # started with the graphical session (niri/Mango start the binary
      # from /run/current-system/sw/libexec themselves).
      security.polkit.enable = lib.mkDefault true;
      environment.systemPackages = [ cfg.finalPackage pkgs.hyprpolkitagent ];
      environment.pathsToLink = [ "/libexec" ];
      systemd.packages = [ pkgs.hyprpolkitagent ];
      systemd.user.services.hyprpolkitagent.wantedBy = lib.mkDefault [ "graphical-session.target" ];

      # gsettings writes (GTK theme, color scheme) need the dconf service
      programs.dconf.enable = lib.mkDefault true;

      # Audio, bluetooth and the rest of the services the panels talk to.
      services.pipewire = {
        enable = lib.mkDefault true;
        pulse.enable = lib.mkDefault true;
        wireplumber.enable = lib.mkDefault true;
      };
      hardware.bluetooth.enable = lib.mkDefault true;
      services.upower.enable = lib.mkDefault true;
      # Not next to TLP or auto-cpufreq (nixpkgs asserts it; the shell has a
      # TLP backend too)
      services.power-profiles-daemon.enable = lib.mkDefault
        (!config.services.tlp.enable && !(config.services.auto-cpufreq.enable or false));
      programs.gpu-screen-recorder.enable = lib.mkDefault true;
      networking.networkmanager.enable = lib.mkDefault true;

      # Backlight without root (udev rules), DDC/CI for external monitors,
      # the file index the launcher searches
      services.udev.packages = [ pkgs.brightnessctl ];
      hardware.i2c.enable = lib.mkDefault true;
      services.locate.enable = lib.mkDefault true;

      users.users = lib.genAttrs cfg.users (_: {
        extraGroups = [ "video" "input" ] ++ lib.optional config.hardware.i2c.enable config.hardware.i2c.group;
      });
    }

    (lib.mkIf cfg.compositors.hyprland {
      # UWSM reaches graphical-session.target, which starts the polkit agent.
      programs.hyprland.enable = lib.mkDefault true;
      programs.hyprland.withUWSM = lib.mkDefault true;
    })

    (lib.mkIf cfg.compositors.niri {
      programs.niri.enable = lib.mkDefault true;
      environment.systemPackages = [ pkgs.xwayland-satellite ];
    })

    (lib.mkIf cfg.compositors.mango {
      programs.mango.enable = lib.mkDefault true;
    })

    (lib.mkIf cfg.sddm.enable {
      services.displayManager.sddm = {
        enable = lib.mkDefault true;
        package = lib.mkDefault pkgs.kdePackages.sddm;
        wayland.enable = lib.mkDefault true;
        theme = "yozakura";
        extraPackages = [ pkgs.kdePackages.qtsvg ];
      };
      environment.systemPackages = [ sddmTheme ];
      # Owned by the desktop user (the shell syncs into it), readable by the
      # greeter
      systemd.tmpfiles.rules = lib.optional (cfg.sddm.user != null) (
        let group = config.users.users.${cfg.sddm.user}.group or "";
        in "d ${sddmDataDir} 0755 ${cfg.sddm.user} ${if group == "" then "users" else group} -"
      );
    })
  ]);
}
