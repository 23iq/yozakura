# System tools and utilities (backend/pkg/deps/packages.tsv lists what each
# one serves; services like NetworkManager, BlueZ and UPower come from the
# NixOS module, their clients talk to the system daemons over D-Bus)
{ pkgs }:

with pkgs; [
  brightnessctl
  ddcutil
  fontconfig
  git
  curl
  file
  glib
  jq
  python3
  zip
  imagemagick
  inotify-tools

  libnotify
  matugen
  power-profiles-daemon
  sqlite
  upower
  wl-clip-persist
  wl-clipboard
  wlsunset
  wtype
  grim
  slurp
  zenity
  inetutils
  xdg-utils
  xdg-user-dirs

  # Launcher file search
  fd
  plocate

  # Calendar events on the dashboard
  khal

  # GTK and Qt apps follow the palette
  adw-gtk3
  qt6Packages.qt6ct
]
