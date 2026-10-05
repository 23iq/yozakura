# AGENTS.md: modules/lockscreen/

## OVERVIEW
Lock screen UI with PAM authentication via WlSessionLockSurface.

## STRUCTURE
```
modules/lockscreen/
├── LockScreen.qml        # WlSessionLockSurface: screencopy, video sync, caps-lock probe, PAM auth (no visuals)
├── LockView.qml          # Host: wallpaper (blur/opacity/saturation from the style), loads the active
│                         # style and places its slots (LockLayout.js); `preview: true` for the settings gallery
├── LockLayout.js         # Pure placement of clock + cluster per arrangement (stack|center|split|column)
├── LockPasswordBase.qml  # Password logic shared by every style: hints, shake, signals LockScreen uses
├── LockMediaBase.qml     # MPRIS state + cava gate (`shown`, `visualizerEnabled`) shared by media cards
├── LockStatusInfo.qml    # Network/battery values for status strips
├── LockAvatar.qml        # ~/.face.icon | ~/.face, rounded, glyph fallback
├── LockClock / LockDigit / LockPasswordPill / LockMediaCard / LockMediaButton /
│   LockStatusRow / LockGlass / LockTextShadow   # parts of the glass style (palette-parametrised)
└── styles/
    ├── LockStyleRegistry.js  # id, labelKey, descKey, icon, file, tones; tone + blur resolution
    ├── LockStyle.qml         # the interface: slots, arrangement, wallpaper treatment, palette
    └── GlassStyle / PaperStyle / TerminalStyle / AuroraStyle / NeonStyle / PosterStyle .qml
```
PAM config: `config/pam/password.conf`.

## STYLES (adding one = one file + one registry entry)
A style extends `styles/LockStyle.qml` and fills five slots with Components declared in the
file (they read `skin.view.*` - the LockView state: `now`, `username`, `hostname`, `atTop`,
`startAnim`, `preview` - and the style's palette by id):
- `backdrop` (fills the screen over the wallpaper), `clock`, `status` (full-width strip)
- `passwordField`: root must be a `LockPasswordBase`, set `field: <its TextField>`, wire
  `Keys.onReleased: event => pw.observeKey(event)`, apply `shakeOffset`, show `hint`/`errorShown`
- `mediaCard`: root must be a `LockMediaBase`; a visualizer uses `configEnabled: media.visualizerEnabled`
  and `shown: media.visualizerShown` (cava runs only while locked, visible and playing)
plus `arrangement`/`clockSide`/`clusterWidth`, `wallpaperBlur/Opacity/Saturation/Zoom` and the
`light`-dependent palette (fixed roles: same look in light and dark schemes). The id of the
style root is `skin` (not `style`: Text has a `style` property that shadows it in inline components).
Register it in `LockStyleRegistry.js` (+ `lockscreen.style.<id>` / `.desc` translations), mirror it
in `assets/sddm/yozakura/styles/`, run `make schema`. `tests/lockscreen.test.py` runs the media,
password and full auth checks against every registered style; `tests/lockscreen-styles.test.cjs`
checks the registry and layout; `tools/render/lockscreen_render.py` renders every style dark/light.

Config (`config/defaults/lockscreen.js`): `style`, `tone` (style|theme|light|dark), `blur`
(-1 = style's own), `position`, `showStatus`, `showMedia`, `showVisualizer`. Settings:
`modules/settings/schema/lockscreen.js` (gallery: `editors/LockStyleGallery.qml`, live LockViews).

## WHERE TO LOOK
| Symbol | Location | Role |
|--------|----------|------|
| `WlSessionLockSurface` | `LockScreen.qml` | Root; handles Wayland session lock protocol |
| `PamContext` | `LockScreen.qml` | PAM authentication via Quickshell.Services.Pam |
| `onAccepted` (Connections on `passwordInput`) | `LockScreen.qml` | Submit: holder <- text, clear field, `pamAuth.start()` |
| `authPasswordHolder` | `LockScreen.qml` | Temp holder for password during PAM auth |
| `playWrongPassword()` / `wrongPasswordFinished` | `LockPasswordBase.qml` | Shake; LockScreen clears field + `authenticating` on finish |
| `unlockTimer` | `LockScreen.qml` | Sets GlobalStates.lockscreenVisible = false after exit animation |
| `capsLockCheck` | `LockScreen.qml` | Reads `/sys/class/leds/*::capslock/brightness` |

`passwordInput`, `passwordInputBox` and `wallpaperBackground` on LockScreen are aliases into LockView
(the active style's TextField, its LockPasswordBase and the wallpaper), so the auth flow reads as
before whatever the style. LockView holds no auth logic; it is rendered offscreen in
`tests/lockscreen.test.py` for every style.

Key behaviors:
- On lock: capture screen (`screencopyBackground.captureFrame()`), `startAnim = true` (LockView fades/scales in), focus password field
- On auth: store password in temp holder, `pamAuth.start()`, respond to PAM messages via `onPamMessage`
- On success: `startAnim = false` (fade out), start unlockTimer, set lockscreenVisible=false
- On failure: shake animation, clear password, update failLock countdown
- `Config.lockscreen.position` (top/bottom) places the media + password cluster; the clock takes the other half (or the other side, per arrangement)

## CONVENTIONS
Same as root AGENTS.md with additions:
- Use `Quickshell.Services.Pam` module for authentication
- Use `WlSessionLockSurface` as root component for lock surfaces
- Store sensitive data (password) in temporary QtObject, clear immediately after auth
- Use Process for system commands (`whoami`, `hostname`, `faillock`)
- Handle PAM message responses in `onPamMessage` signal

## ANTI-PATTERNS
- Never log passwords or send them to debug output
- Don't modify authPasswordHolder after PAM completion (should be cleared)
- Don't call pamAuth.start() while already authenticating (check authenticating flag)
- Don't forget to clear password on both success and failure paths