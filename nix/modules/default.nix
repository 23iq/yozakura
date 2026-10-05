# NixOS module for Yozakura
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.yozakura;
in {
  options.programs.yozakura = {
    enable = lib.mkEnableOption "Yozakura shell";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The Yozakura package to use";
    };

    fonts.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install Yozakura fonts (including Phosphor Icons)";
    };
  };

  config = lib.mkIf cfg.enable {

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
      noto-fonts
      noto-fonts-color-emoji
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      (pkgs.callPackage ../packages/phosphor-icons.nix { })
    ]);

    # The compositor itself, with its portal and display-manager session.
    # UWSM reaches graphical-session.target, which starts the polkit agent.
    programs.hyprland.enable = lib.mkDefault true;
    programs.hyprland.withUWSM = lib.mkDefault true;
    xdg.portal = {
      enable = lib.mkDefault true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    # Password prompts for system actions: hyprpolkitagent's user unit,
    # started with the graphical session.
    security.polkit.enable = lib.mkDefault true;
    environment.systemPackages = [ cfg.package pkgs.hyprpolkitagent ];
    systemd.packages = [ pkgs.hyprpolkitagent ];
    systemd.user.services.hyprpolkitagent.wantedBy = lib.mkDefault [ "graphical-session.target" ];

    # Audio, bluetooth and the rest of the services the panels talk to.
    services.pipewire = {
      enable = lib.mkDefault true;
      pulse.enable = lib.mkDefault true;
      wireplumber.enable = lib.mkDefault true;
    };
    hardware.bluetooth.enable = lib.mkDefault true;
    services.upower.enable = lib.mkDefault true;
    services.power-profiles-daemon.enable = lib.mkDefault true;
    programs.gpu-screen-recorder.enable = lib.mkDefault true;
    networking.networkmanager.enable = lib.mkDefault true;
  };
}
