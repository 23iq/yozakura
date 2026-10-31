# A NixOS system with every Yozakura module option on, for CI to evaluate
# (nix eval ... .config.system.build.toplevel.drvPath): catches option
# typos, missing nixpkgs attributes and conflicts with the NixOS modules.
# `tlp = true` checks a laptop with TLP (power-profiles-daemon must stay off).
{ flake, tlp ? false }:

flake.inputs.nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    flake.nixosModules.default
    ({ pkgs, ... }: {
      boot.loader.grub.enable = false;
      fileSystems."/" = { device = "/dev/null"; fsType = "ext4"; };
      system.stateVersion = "25.11";
      nixpkgs.config.allowUnfree = true;
      users.users.alice = { isNormalUser = true; };
      services.tlp.enable = tlp;

      programs.yozakura = {
        users = [ "alice" ];
        compositors.niri = true;
        compositors.mango = true;
        voice.enable = true;
        voice.acceleration = "vulkan";
        depth.enable = true;
        sddm.enable = true;
      };
    })
  ];
}
