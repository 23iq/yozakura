<p align="center">
  <img src="./assets/yozakura/yozakura-logo-color.svg" alt="Yozakura" width="460" />
</p>

<p align="center">
  <b>夜桜 · Night-sakura desktop shell for Hyprland</b><br>
  <sub>Quickshell UI · Go daemon · presets for everything</sub>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-AGPL--3.0-d4709a?style=for-the-badge&labelColor=0b0a0c" alt="AGPL-3.0"></a>
  <img src="https://img.shields.io/badge/Hyprland-%E2%89%A50.56-f4a7c0?style=for-the-badge&labelColor=0b0a0c" alt="Hyprland">
  <img src="https://img.shields.io/badge/Quickshell-Qt%206-f4a7c0?style=for-the-badge&labelColor=0b0a0c" alt="Quickshell">
</p>

---

Yozakura is a Wayland desktop shell for Hyprland: bar, dynamic-island notch,
dock, launcher, dashboard, lockscreen, notifications and desktop widgets, all
driven by one reactive configuration and switchable as a whole through
**presets**. Everything is a setting: every feature can be turned off, every
look can be saved, mixed and shared as a preset, and nothing needs code to
change.

Under the hood a single `yozakura` binary is the daemon: it serves the UI over
IPC, supervises Quickshell and `yozd` (its own compositor daemon: one API over
Hyprland, niri and MangoWC) and writes the compositor config. The same
settings are reachable from the settings window, the CLI and an MCP server,
so AI agents can drive the desktop too.

> [!NOTE]
> Screenshots are coming soon. Until then, the best way to see it is to try it:
> [install](#install) it and flip through the presets with `yozakura preset -l`.

## Features

**Look and layout**
- Presets that switch the whole desktop at once: bar layout, theme, compositor
  appearance, wallpaper. Signature presets, each with its own layout and
  character: *Yozakura Night* (islands), *Neon Tokyo* (dense pro bar), *Sumi-e*
  (notch only), *Kōyō* (bottom taskbar), *Glacier* (menubar + dock), *Kaze*
  (vertical rail), *Shōji* (corner tabs), *Metro* (two bars), *CRT*
  (statusline) and *Yozakura Default*. Their fonts ship with the shell
  (`assets/fonts/ui`, OFL).
- Preset studio: save your own, mix parts of several (layout from one, colors
  from another), try one on before applying, import and export.
- Bar layouts with islands, a slide-out drawer and a compact mode; per-preset
  layouts.
- Dynamic island notch with a panel registry, live activities next to it
  (media, recording, timers, privacy), hover expansion and a cava audio
  visualizer.
- Desktop depth clock that sits *behind* the subject of the wallpaper, also on
  video wallpapers (per-frame mattes, optional GPU), with several clock styles
  and kanji/roman/arabic workspace numerals.
- Shader wallpaper transitions and a crossfaded palette change.
- Lossless compositor appearance: gradients, shadows and blur extras are
  applied exactly as configured on Hyprland.
- Black-glass lockscreen and a matching SDDM login theme, synced to the current
  wallpaper and palette.

**App theming from the wallpaper palette** (Material You via matugen)
- GTK, Qt (qt5ct/qt6ct), kitty, Neovim (base16 palette), starship/fastfetch via
  the terminal palette, Papirus folder colours.
- Discord clients (Vesktop, Equibop, Equicord, Vencord), Spotify (spicetify),
  Telegram, Firefox (userChrome/userContent).

**Tools**
- Launcher with apps, clipboard history (encrypted), emoji, notes, tmux
  sessions and wallpapers.
- AI center: chat with several providers, quick-ask in the notch, selection
  and screen-region actions, CLI agent sessions (Claude Code, Codex,
  OpenCode), and a built-in MCP server (`yozakura mcp`) that lets agents drive
  the desktop.
- Local voice input: push-to-talk dictation and voice-to-AI with whisper.cpp.
- Transfers (downloads, copies, updates), screenshots, screen recording,
  colour picker, OCR, QR/barcode scanner, mirror, weather, calendar, system
  monitor, power profiles, game mode, night light, caffeine.
- Special workspaces (scratchpads) with their own keys, icons and apps: opening
  one starts its apps if they are not running yet ([docs](docs/special-workspaces.md)).
- Schema-driven settings window with search, a first-run wizard, a keybind
  editor with conflict detection and a cheatsheet (`Super + /`), multi-monitor,
  mods with native settings integration ([docs/mods](docs/mods/README.md)).

**Default keys** (all editable in Settings > Input & Keybinds)

| Key | Action | Key | Action |
| --- | --- | --- | --- |
| `Super` | Launcher | `Super + Q` | Close window |
| `Super + T` | Terminal | `Super + D` | Dashboard |
| `Super + A` | AI assistant | `Super + Tab` | Overview |
| `Super + V` | Clipboard | `Super + /` | Keybind cheatsheet |
| `Super + Shift + S` | Screenshot | `Super + L` | Lock |
| `Super + M` (hold) | Talk to AI | `Super + Shift + M` (hold) | Dictation |
| `Super + 1…0` | Workspaces | `Super + Shift + C` | Settings |

## Install

One command on a fresh or existing Arch or Fedora system. Run it as your
user; it asks for sudo once:

```bash
curl -fsSL https://raw.githubusercontent.com/23iq/yozakura/main/install.sh | bash
```

It installs the core only: the shell, one compositor and a login screen.
It asks which compositor you want (Hyprland, niri or Mango; `--compositor
NAME` skips the question), shows the whole plan (distro, GPU, login manager,
packages, services, files it touches) and asks once. Then it installs the
packages (Quickshell, matugen, the PipeWire stack, portals, a polkit agent,
NetworkManager, BlueZ, fonts), clones the sources to `~/.local/src/yozakura`,
builds `yozakura` and its compositor daemon `yozd` there (`make build`),
installs both to `~/.local/bin`, adds the Yozakura block to your compositor
config and ends with `yozakura doctor`; it offers a reboot. On the first
login the setup wizard opens by itself: apps, AI, voice, terminal prompt and
the rest are chosen there. Everything the installer runs is logged to
`~/.cache/yozakura/install.log`.

```bash
curl -fsSL https://raw.githubusercontent.com/23iq/yozakura/main/install.sh | bash -s -- --dry-run   # walk the whole flow, change nothing
curl -fsSL https://raw.githubusercontent.com/23iq/yozakura/main/install.sh | bash -s -- --yes --with-voice
```

| Flag | What it does |
| --- | --- |
| `--with-voice` | Local speech-to-text: builds whisper.cpp (CUDA when available) and downloads the model, ~1 GB (`scripts/voice_setup.sh`) |
| `--with-depth` | Depth clock behind the wallpaper subject: uv venv with rembg plus a model, ~0.7 GB (`scripts/depth_setup.sh`) |
| `--with-sddm` | SDDM with the Yozakura login theme. On by default when no login manager is installed; SDDM is enabled for the next boot |
| `--no-voice` / `--no-depth` / `--no-sddm` | Turn a feature off |
| `-y`, `--yes` | Do not ask; go with the plan (unattended installs) |
| `--dry-run` | Walk the whole install (questions, plan, every step) showing what would run; changes nothing, no sudo |
| `--no-deps` | Skip packages and services: only clone, build and install the binaries |
| `--no-aur` | Arch: no AUR helper; the Phosphor icon font is installed per user instead |
| `--compositor NAME` | `hyprland` (default), `niri` or `mango` (Arch only) |
| `--exclusive` | Hyprland: Yozakura manages the whole Hyprland config (backup first; `yozakura install --restore` undoes it) |
| `--no-compositor-config` (`--no-hyprland`) | Leave the compositor's config files alone |
| `--reboot` / `--no-reboot` | Reboot at the end without asking / do not offer it |
| `--verbose` | Show command output instead of spinners |
| `--dir PATH` / `--bin-dir PATH` / `--branch NAME` | Source checkout, binary location, git branch |

Piped without a terminal (CI, containers) it never waits for input: it goes
with the plan and its defaults. `YOZAKURA_REPO_URL` points it at another git
remote (a fork or a local path). Optional features can also be set up later
with their scripts in `~/.local/src/yozakura/scripts/`.

### Per distribution

- **Arch** (primary target): official repos with `pacman -Syu --needed`;
  the Phosphor icon font comes from the AUR (`paru`/`yay` when present,
  otherwise `yay-bin` is bootstrapped; `--no-aur` skips that). Packages that
  clash with something you already run (power-profiles-daemon next to tlp or
  tuned, pipewire-pulse next to PulseAudio, `-git` builds of quickshell or
  Hyprland) are skipped.
- **Fedora**: enables the `lionheartp/Hyprland` COPR (Hyprland, quickshell,
  matugen, portals, hyprpolkitagent, kitty) and installs the rest with dnf.
- **NixOS**: use the flake. The NixOS module installs the package and enables
  Hyprland (with UWSM and its session), portals, polkit and its agent,
  PipeWire, Bluetooth, NetworkManager, UPower and the fonts:

  ```nix
  # flake.nix
  inputs.yozakura.url = "github:23iq/yozakura";
  # in your nixosSystem modules:
  yozakura.nixosModules.default
  ```

  Then run `yozakura install hyprland` once. Run on NixOS, the script adds the
  flake package to your nix profile instead (no system services).
- **Others**: the script builds and installs Yozakura and leaves the packages
  to you; `yozakura doctor` lists what is missing.

The binaries go to `~/.local/bin`; when that is not on your `PATH` the
installer links them into `/usr/local/bin` so Hyprland's `exec-once` finds them.

### Requirements

The complete list, with the package for each distribution, is
[`backend/pkg/deps/packages.tsv`](backend/pkg/deps/packages.tsv); the
installer installs from it and `yozakura doctor` checks it.

| What | Arch packages | Needed for |
| --- | --- | --- |
| Compositor and UI | `hyprland` (≥ 0.56), `quickshell`, Qt 6 (`qt6-base`, `qt6-wayland`, `qt6-declarative`, `qt6-svg`, `qt6-multimedia`, `qt6-imageformats`), `yozd` (built from this repo) | everything |
| Build | `go` (≥ 1.26), `make`, `git` | the binaries |
| Theming | `matugen`, `adw-gtk-theme`, Phosphor icons, Noto (CJK, emoji), bundled fonts in `assets/fonts` | colors, icons, text |
| Desktop integration | `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`, `hyprpolkitagent`, `xdg-utils` | screen sharing, file pickers, password prompts |
| Audio and media | `pipewire`, `pipewire-pulse`, `wireplumber`, `playerctl`, `cava`, `ffmpeg`, GStreamer plugins, `gpu-screen-recorder` | media, visualizer, video wallpapers, recording |
| System panels | `networkmanager`, `bluez`, `brightnessctl`, `ddcutil`, `upower`, `power-profiles-daemon` | network, bluetooth, brightness, battery, power |
| Tools | `wl-clipboard`, `wtype`, `grim`, `slurp`, `jq`, `python`, `glib2`, `libnotify`, `tesseract`, `fd`, `plocate`, `zenity`, `imagemagick`, `kitty`, `tmux` | clipboard, typing, screenshots, OCR, search, dialogs |
| Optional | `cmake` (voice), `uv` (depth clock), `sddm` (login theme) | opt-in features |

### Update, check and uninstall

```bash
yozakura update     # pull, rebuild and reinstall both binaries (runs install.sh --update)
yozakura reload     # restart the shell on the new version
yozakura doctor     # every dependency, what is missing and the command that installs it
yozakura goodbye    # remove the binaries and the compositor blocks; asks about source and config
```

Re-running the one-liner also updates. Local changes in the checkout are kept
(and built); the installer prints how to reset to upstream.

`yozakura install hyprland` adds one block to `~/.config/hypr/hyprland.lua`:

```lua
-- Yozakura
loadfile(os.getenv("HOME") .. "/.local/share/yozakura/hyprland.lua")()

-- OVERRIDES
-- Down here you can write or source anything that you want to override from Yozakura's settings.
```

The generated file is rewritten on every theme, gaps or binds change; put your
own settings below the block. Nothing else in your config is touched.

Useful commands: `yozakura preset -l`, `yozakura preset "Yozakura Night"`,
`yozakura wallpaper <file>`, `yozakura run launcher`, `yozakura reload`,
`yozakura help`. Settings live in `~/.config/yozakura`.

### Manual install

```bash
git clone https://github.com/23iq/yozakura ~/.local/src/yozakura
cd ~/.local/src/yozakura
make build                                  # ./yozakura and ./yozd (Go >= 1.26)
install -Dm755 -t ~/.local/bin yozakura yozd
yozakura install hyprland
yozakura                                    # first start
```

### Migrating an existing setup

Settings from an Ambxst install are picked up automatically: stop it first
(`ambxst quit`), then install as above. The first start copies settings,
presets and data (the originals are never modified) and switches the Hyprland
config over, keeping `.pre-yozakura` backups.

## Development

```bash
make check     # parse, lint, format, audit and tests (QML tests run headless)
make run       # build and start from the checkout
```

See [AGENTS.md](AGENTS.md) for the architecture and the definition of done.

## Credits

Built on [Quickshell](https://quickshell.org/) by
[outfoxxed](https://outfoxxed.me/) and [matugen](https://github.com/InioX/matugen).
Parts of Yozakura, including `yozd`, derive from
[Ambxst](https://github.com/Axenide/Ambxst) and
[axctl](https://github.com/Axenide/axctl) by Axenide (AGPL-3.0); see
[NOTICE](NOTICE).

## License

[AGPL-3.0](LICENSE). If you run a modified version for others, you must offer
them its source. Bundled fonts and assets keep their own licenses (see the files next to them).
