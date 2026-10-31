# Applications: terminal, launcher, control panels
{ pkgs }:

with pkgs; [
  # Default terminal (Config.general.terminal picks another one)
  kitty
  tmux

  # Control panels
  networkmanagerapplet
  blueman
  pavucontrol
  easyeffects
  gradia

  # Icons
  kdePackages.breeze-icons
  hicolor-icon-theme
]
