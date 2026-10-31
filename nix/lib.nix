# Utility functions for Yozakura flake
{ nixpkgs }:

let
  linuxSystems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
in {
  inherit linuxSystems;

  # Iterate over all supported Linux systems
  forAllSystems = f:
    builtins.foldl' (acc: system: acc // { ${system} = f system; }) {} linuxSystems;
}
