# The SDDM login theme (scripts/install-sddm-theme.sh on other distros).
# theme.conf.user points at the shared data dir the shell keeps in sync
# (scripts/sddm-sync.sh): the NixOS module creates it, owned by the user.
{ pkgs, lib, version, dataDir ? "/var/lib/yozakura-sddm" }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "yozakura-sddm-theme";
  inherit version;
  src = lib.cleanSource ../../assets/sddm/yozakura;
  dontBuild = true;
  installPhase = ''
    dir=$out/share/sddm/themes/yozakura
    mkdir -p "$dir"
    cp -r . "$dir"/
    rm -f "$dir/theme.conf.user"
    ln -s ${dataDir}/theme.conf "$dir/theme.conf.user"
  '';
  meta.platforms = lib.platforms.linux;
}
