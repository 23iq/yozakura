# Yozakura on NixOS

The flake ships everything the installer sets up on other distributions:
the package (shell, backend, `yozd` and every runtime tool), and a NixOS
module for the system part (compositor, services, groups, polkit agent,
login theme). Nothing at runtime writes to `/usr` or `/etc`. The shell
detects NixOS and points to these options instead.

## Install

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    yozakura = {
      url = "github:23iq/yozakura";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, yozakura, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        yozakura.nixosModules.default
        {
          programs.yozakura = {
            users = [ "alice" ];          # groups video, input, i2c
            compositors.niri = true;      # Hyprland is on by default
            voice.enable = true;          # dictation (whisper.cpp)
            voice.acceleration = "vulkan"; # or "cpu", "cuda"
            depth.enable = true;          # depth clock (rembg)
            sddm.enable = true;           # login screen in the shell's look
          };
        }
      ];
    };
  };
}
```

`inputs.nixpkgs.follows` keeps one Qt in the system. Without it the shell
still works but brings its own nixpkgs, and apps started from the launcher
inherit Quickshell's Qt plugin and QML paths from that other Qt, which Qt
apps of your own nixpkgs may refuse ("Cannot mix incompatible Qt library").

Then rebuild, log into Hyprland (or niri/MangoWC) and run once:

```sh
yozakura install hyprland   # or: niri, mango
```

This writes the compositor config the shell manages
(`~/.local/share/yozakura/`) and the autostart line. The autostart runs
the profile command (`/etc/profiles/per-user/<you>/bin/yozakura` or
`/run/current-system/sw/bin/yozakura`), never a `/nix/store` path, so it
keeps working across updates and garbage collection.

## Module options

| Option | Default | What it does |
|--------|---------|--------------|
| `programs.yozakura.enable` | `true` with the module | Installs the package and the services below |
| `package` | the flake's | The Yozakura package |
| `users` | `[ ]` | Users added to `video`, `input`, `i2c` |
| `fonts.enable` | `true` | Registers the shell's fonts system-wide |
| `compositors.hyprland` | `true` | `programs.hyprland` with UWSM |
| `compositors.niri` | `false` | `programs.niri` + `xwayland-satellite` |
| `compositors.mango` | `false` | `programs.mango` |
| `voice.enable` | `false` | Packaged `whisper-server`; Settings only downloads the models |
| `voice.acceleration` | `"cpu"` | `"vulkan"` (AMD/Intel) or `"cuda"` (NVIDIA, unfree) |
| `depth.enable` | `false` | Python with rembg for the depth clock; Settings downloads the model |
| `sddm.enable` | `false` | SDDM (Qt 6, Wayland) with the `yozakura` theme |
| `sddm.user` | first of `users` | Owner of `/var/lib/yozakura-sddm`, which the shell keeps in sync |

The module also enables (each with `mkDefault`, so your own settings win):
portals (`xdg-desktop-portal-gtk`), polkit and `hyprpolkitagent` (its user
unit, started with the graphical session), dconf, PipeWire, Bluetooth,
UPower, power-profiles-daemon (left off when TLP or auto-cpufreq is on: the
shell's power profiles then use TLP), NetworkManager,
`gpu-screen-recorder` (setuid wrapper), brightnessctl's udev rules, I2C for
DDC/CI and `services.locate` for the launcher's file search.

Without the module (a nix profile install on another distribution), the
package alone works too. System services are then up to the host
distribution.

## Updating

```sh
nix flake update yozakura      # in your system flake
sudo nixos-rebuild switch --flake .#myhost
yozakura reload                # restart the shell on the new version
```

`yozakura update` only prints this hint on Nix. For a nix profile install
(`nix profile add github:23iq/yozakura`), `yozakura refresh` upgrades the
profile entry.

## Home Manager and hand-written configs

- **Hyprland config from Home Manager**: if `wayland.windowManager.hyprland`
  writes `~/.config/hypr/hyprland.conf`, the file is a read-only store link
  and `yozakura install hyprland` cannot add its line. Add it yourself:

  ```nix
  wayland.windowManager.hyprland.extraConfig = ''
    source = ~/.local/share/yozakura/hyprland.conf
  '';
  ```

  App configs managed by Home Manager (kitty, fish, ...) are detected as
  "managed" and left alone. Theme them through Home Manager instead.
- **Login shell**: the terminal setup can't run `chsh` on NixOS. Set it
  declaratively:

  ```nix
  programs.fish.enable = true;
  users.users.alice.shell = pkgs.fish;
  ```

- **Keyboard layouts and monitors** set from Settings are written into the
  compositor config the shell manages, as on other distributions.

## Development

```sh
nix develop           # Go, make, node, linters and the runtime env
make build && ./yozakura
```

The dev shell drops the installed package's `YOZAKURA_SHELL`,
`YOZAKURA_LAUNCHER` and `YOZAKURA_DAEMON_BIN` (a terminal opened from the
shell inherits them), so `./yozakura` runs the checkout's QML, `yozd` and
binary.

`yozakura doctor` on NixOS checks the profile paths
(`/run/current-system/sw`, `/etc/profiles/per-user/<you>`,
`~/.nix-profile`) and the package's own environment.

## How it fits together

- `bin/yozakura` is a wrapper. It finds its own profile command
  (`YOZAKURA_LAUNCHER`) and exports the paths the backend and Quickshell
  need: `YOZAKURA_QS`, `YOZAKURA_SHELL`, `YOZAKURA_NIX_ENV`, `YOZAKURA_XKB_ROOT`,
  `YOZAKURA_WHISPER_BIN_DIR` and `YOZAKURA_DEPTH_PYTHON`. Then it runs the
  backend.
- Quickshell runs through a second wrapper. That wrapper prepends the Qt
  plugins (multimedia, image formats), the QML modules and the GStreamer
  plugins, so video wallpapers and media work whatever the session sets.
  The package links only `bin/` and `share/` into profiles, so these Qt
  files never reach the system profile's `lib/qt-6`.
- `PATH` puts `/run/wrappers/bin` first, so NixOS's privileged wrappers
  (`plocate` for the launcher's file search, `gpu-screen-recorder`) win
  over the plain store binaries.
- Fonts come from `FONTCONFIG_FILE`. It includes `/etc/fonts/fonts.conf`
  plus the bundled fonts, so system and user fonts stay visible.
