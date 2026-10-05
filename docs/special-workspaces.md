# Special workspace indicator

On Hyprland, an open special workspace appears as a centered pill over blurred
normal workspace icons. Its name comes from the monitor's `specialWorkspace`
state, with only the leading `special:` prefix removed. Hovering over the widget
reveals the normal workspace buttons for navigation. Both bar orientations are
supported; vertical bars rotate the label to fit.

Configure `~/.config/yozakura/config/workspaces.json`:

```json
{
    "showSpecialWorkspace": true,
    "specialWorkspaceAnimationDuration": 100,
    "specialWorkspaceFont": ""
}
```

The duration is in milliseconds; zero disables the transition. The global
animation switch and GameMode also disable it. An empty font setting uses the
Qt application's system font. Set a font family explicitly to override it.
The existing theme font size controls the label size.

This indicator does not change normal workspace navigation on other compositors.
Special workspaces are excluded from the dynamic normal-workspace button list.

Run the parsing tests with `node tests/special-workspaces.test.cjs`.

## Special workspaces (scratchpads with apps)

Settings > Special workspaces (also an optional onboarding step; new installs
have none) manages named Hyprland special workspaces. Each one has:

- a display name; the Hyprland name `special:<name>` is derived safely
  (whitespace and `, : [ ] $ ...` become `-`, unique per list). Renaming moves
  its open windows to the new name;
- an icon (`modules/theme/Icons.qml` glyph) and an accent (a palette role);
- a toggle bind and a "send window here" bind, part of the keybinds model:
  they show in the cheatsheet and the keybinds editor, and clash warnings
  include them;
- apps picked from the installed desktop entries (window class from
  `StartupWMClass`, else the desktop id; command from `Exec`; both editable).
  Opening the special launches the apps that are not running straight into
  it (`exec [workspace special:<name> silent]` through `yozd system
  execute-in`) and never twice while one is still mapping its window; late
  windows of a launched app are moved in. Already running elsewhere:
  `nothing` (default) or `move` it in. `rule` adds a permanent window rule;
- `preload`: start its apps hidden at login.

They are global like `binds.json` (`~/.config/yozakura/config/specials.json`,
a private domain): presets never save, show, apply or mix them. The bar
indicator shows a configured special's icon and name. The dashboard lists
them with their window counts; the launcher finds them by name. Other
compositors: the settings page shows a notice and nothing runs.

CLI: `yozakura special list|open|add|set|remove|app add|app remove|import-binds`
(see `yozakura special help`); MCP: `specials_list`, `special_open`,
`special_add`, `special_update`, `special_remove`, `special_app_add`.

`yozakura special import-binds` moves hand-written binds
(`toggle_special("X")` / `workspace = "special:X"` in Lua,
`togglespecialworkspace X` / `movetoworkspace[silent] special:X` in
hyprland.conf syntax) from `~/.config/hypr/custom/*.{lua,conf}` into the
list, comments the source lines out under a marker (the original is kept as
`<file>.bak`) and reports clashes with `binds.json`. Running it again changes
nothing. `--dry-run` shows what it would do.

Tests: `node --test tests/specials.test.cjs`, `python3 tests/specials-ui.test.py`,
`go test ./pkg/specials ./pkg/presets ./cmd/yozakura` (in `backend/`).
