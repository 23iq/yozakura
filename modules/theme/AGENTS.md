# THEME KNOWLEDGE BASE

## OVERVIEW
Dynamic theming layer providing colors, icons, and style utilities as singletons. Also generates config files for external apps (Kitty, GTK, Discord, etc.) from the active color palette.

## STRUCTURE
| File | Type | Role |
|------|------|------|
| `Colors.qml` | Singleton | Watches `~/.cache/yozakura/colors.json`. Provides reactive palette (`primary`, `secondary`, `surface`, `onSurface`, etc.) |
| `Styling.qml` | Singleton | `radius(offset)`, `fontSize(offset)`, `getStyledRectConfig(variant)`. Animation durations, spacing constants |
| `FontRegistry.qml` + `BundledFonts.js` | Singleton + registry | Loads every bundled UI font (`assets/fonts/ui/**`, OFL) at startup (shell.qml touches it before any surface) so presets can name them; adding a font = files + licence + one `BundledFonts.js` entry (`tests/bundled-fonts.test.*`) |
| `Icons.qml` | Singleton | Character map for Phosphor-Bold icon font (`lock`, `power`, `layout`, etc.) |
| `*Generator.qml` | Components | Translate `Colors` palette into config files for other apps |

### Generators
- `GtkGenerator.qml` — GTK3/4 CSS theme
- `KittyGenerator.qml` — Kitty terminal colors
- `DiscordGenerator.qml` — Discord CSS injection
- `NvChadGenerator.qml` — NvChad/Neovim theme
- `PywalGenerator.qml` — Pywal color export
- `PywalZenGenerator.qml` — Zen Browser userChrome CSS theme
- `QtCtGenerator.qml` — Qt widget theme
- `SddmGenerator.qml` — Syncs wallpaper + palette to the `yozakura` SDDM login theme (`scripts/sddm-sync.sh`, no-op unless installed)
- `DiscordGenerator.qml` also writes `yozakura.css` to Equibop / Equicord / Vencord `themes/` (only when their config dir exists)
- `SpicetifyGenerator.qml` — Spotify: `~/.config/spicetify/Themes/yozakura` (color.ini from roles + `assets/spicetify/yozakura/{user.css,theme.js}`); runs `spicetify -n refresh` when `yozakura` is the active theme, `theme.js` hot-swaps `colors.css` (no Spotify restart)
- `TelegramGenerator.qml` — `~/.cache/yozakura/yozakura.tdesktop-theme` (recolored Telegram "Night" key set from `TelegramBase.js` via `TelegramTheme.js`, blurred wallpaper chat background). Telegram can't hot-reload: user re-opens the file
- `FirefoxGenerator.qml` — `chrome/yozakura.css` + `yozakura-content.css` in default Firefox profiles, `@import`ed from userChrome/userContent, enables the legacy stylesheet pref in `user.js`. Applies on Firefox restart
- `NvimGenerator.qml` — `~/.cache/yozakura/nvim-palette.lua` (`return { dark, base16 = {base00..base0F}, roles = {...} }`), replaced atomically and only when changed. Consumed by a user colorscheme (mini.base16) that watches the cache dir for live reload
- `PapirusGenerator.qml` — maps primary to the nearest papirus-folders color; rootless overlay of symlinks in `~/.local/share/icons/<Papirus theme>/<size>/places` (no index.theme, so `papirus-folders` still manages the system copy)

### Shared JS
- `ColorUtils.js` — OKLab mix/harmonize/ramp/nearest helpers + `palette(Colors)` snapshot + `ansiColors()`. `Colors.red/green/yellow/blue/magenta/cyan` and `light*` come from `ansiColors()` (canonical hues, fixed OKLCH lightness, <=12 deg harmonized to primary), NOT from matugen custom colors: those follow the selected scheme (content/fidelity -> white yellow/cyan, expressive -> rotated hues, monochrome -> all white). Kitty: color4 = harmonized blue, color8 = outline (readable dim text), color16-21 = primary, onPrimary, primaryContainer, onPrimaryContainer, secondary, tertiary (`{role: "#rrggbb"}`); pure JS, testable with node after stripping `.pragma`/`.import` lines
- `TelegramBase.js` / `TelegramTheme.js` — Telegram key list and recolor logic

### Registry (`AppThemes.js`)
One entry per user-facing app toggle (`apps.theming.<id>`): generators it
runs, an sh `detect` condition and `outputs` globs. `Colors.qml` runs
`AppThemes.generatorsFor(Config.apps.theming)` (plus `ALWAYS`: pywal), the
kitty timer and `SddmGenerator.run()` respect the toggles, and
`Colors.regenerateApps()` re-runs them now. Settings > Terminal & Apps shows
install/last-written status from `statusScript()`. Adding an app = one
generator + one entry + its default in `config/defaults/apps.js`
(`tests/app-themes.test.cjs` checks every generator has an owner).
KittyGenerator also writes `font_family`/`font_size` from `apps.kitty`.

### Generator rules
- Pass file contents to `sh -c` as positional args (`["sh","-c",script,"name",arg1,...]`), never by interpolating into the script.
- Bail out silently (exit 0) when the target app is not installed; skip writes when content is unchanged.

## GLASS SYSTEM
Config `theme.glass` (`enabled`, master `amount` 0..1, `referenceAmount`,
`tintRole`, `highlightRole`, `advanced.*`, `surfaces.<windows|terminal|popups|bar|notch|dock|sidebars|lockscreen|settings>.amount`
+ `surfaces.windows.{active,inactive}Opacity`; `-1` = auto/inherit everywhere).
- `GlassCurve.js` — the curated curve: one amount -> opacity, blur size/passes,
  vibrancy, noise, contrast, brightness, tint, edge highlight, shadow softness.
- `GlassModel.js` — resolves config + preset values into effective values.
  A preset's own values (sr* opacities, compositor blur, terminalOpacity) are
  what it shows at its *reference* amount (derived from its opacities), so
  `amount: -1` changes nothing; other amounts scale them along the curve.
- `GlassContrast.js` — WCAG worst case over any wallpaper (black..white
  backdrop); glass never lowers a surface below the AA floor (4.5:1).
- `Glass.qml` — reactive singleton used by StyledRect (`glassSurface` marks a
  surface root), Shadow, LockGlass, KittyGenerator, CompositorTomlWriter /
  CompositorConfig (`Glass.compositor`, `Glass.shellBlur` -> layer rules).
- Settings: Appearance > Glass (`modules/settings/schema/glass.js`); renders:
  `tools/render/glass_render.py`.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Change colors** | `Colors.qml` | Modify `~/.cache/yozakura/colors.json` or change color preset |
| **Add StyledRect variant** | `Styling.qml` → `getStyledRectConfig()` | Returns gradient, border, opacity config per variant |
| **Adjust radius/font** | `Styling.qml` | `radius(offset)` and `fontSize(offset)` apply global scaling |
| **Add icon** | `Icons.qml` | Add Phosphor-Bold unicode mapping |
| **Add app generator** | New `*Generator.qml` | Follow existing generator pattern, read from `Colors.*` |

## CONVENTIONS
- **Color access**: Always use `Colors.<property>` (e.g., `Colors.primary`, `Colors.surface`). Never hardcode hex values.
- **Radius**: Use `Styling.radius(offset)` where offset adjusts from base `Config.roundness`.
- **Font size**: Use `Styling.fontSize(offset)` for consistent text scaling.
- **Generators**: Read-only consumers of `Colors`. Write via `FileView` to app config paths.
- **Palette crossfade**: On `colors.json` change, public `Colors.*` roles ease to the new values (`theme.paletteTransitionDuration`, 0 = snap). Derive new roles from the public (blended) roles, not `adapter.*`, so they fade too; generators already wait for the crossfade to finish.
