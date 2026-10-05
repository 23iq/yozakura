# Yozakura Go backend binary and the compositor daemon (yozd)
{ pkgs, lib, version }:

let
  # The whole tree, not just backend/: the CLI tests read the shell sources
  # (config/defaults, presets) through the repo root.
  src = lib.cleanSource ../..;
in
pkgs.buildGoModule {
  pname = "yozakura-backend";
  inherit version;

  inherit src;
  modRoot = "backend";

  # Vendored deps committed in-tree (go mod vendor)
  vendorHash = null;

  subPackages = [ "cmd/yozakura" "cmd/yozd" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
    "-X main.Version=${version}"
  ];

  meta = {
    description = "Yozakura backend daemon, CLI and compositor daemon";
    mainProgram = "yozakura";
  };
}
