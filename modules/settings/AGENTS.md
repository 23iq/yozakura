# SETTINGS KNOWLEDGE BASE

## OVERVIEW
The settings window (`SettingsWindow.qml`, loaded by `shell.qml`) is schema
driven: settings are *declared* in `schema/*.js` and rendered by generic
components. Search, modified/reset state and the audit are all generated from
the same declarations.

## STRUCTURE
```
modules/settings/
├── SettingsWindow.qml      FloatingWindow wrapper (placement on the focused workspace)
├── SettingsShell.qml       sidebar + current page + ChangesBar, keyboard shortcuts
├── SettingsSidebar.qml     brand, search (schema index), grouped categories (NavItem)
├── SettingsPage.qml        renders one schema category (PageHeader + SettingsSection...)
├── SettingsSection.qml     titled card of SettingRow
├── SettingRow.qml          label/description/modified dot/reset + typed control + preview
├── connect/ConnectPage.qml Network/Bluetooth/Sound/Effects pages: the live device panels
├── mods/                   the Mods page (ModsEditor + parts, ModsModel.js)
├── AboutPage / PlaceholderPage / PageHeader / PillButton / NavItem / ChangesBar
├── SchemaUtil.js           pure: keys, conditions, validation, search index (node-tested)
├── SettingsDefaults.js     default of any key, from config/defaults/*.js
├── Registry.js             custom editor / preview name -> file
├── BarModules.js, Ui.js    bar module presentation, small UI helpers
├── PanelsModel.js          pure bar.panels edits (add/remove/style/edge/move module)
├── PanelSketch.js          pure schematic geometry of a panel (PanelsSchematic)
├── schema/Categories.js    information architecture: groups + categories
├── schema/<category>.js    one file per migrated category
├── store/SettingsStore.qml get/set/reset/isModified + change flow (singleton)
├── store/SchemePreviews.qml palettes per matugen scheme (`yozakura schemes`)
├── controls/               typed controls (Toggle, Slider, Selector, Number, Text, Font, ColorRole,
│                           List, Path, Screens, Chips) + ChoiceCard, PreviewStage
├── editors/                rich `custom` editors (one file each, `property var entry`)
├── previews/               live previews shown under an entry (`preview`)
├── presets/                the "Presets" page (preset studio): gallery, mixer, editor,
│                           thumbnails (PresetMiniShell, cached PNGs), session banner/pill/toast;
│                           PresetModel.js holds the pure helpers (node-tested)
└── store/PresetStudio.qml  studio data + actions: every operation is `<app> preset ...`
                            (backend/pkg/presets), trial/edit sessions live in the backend
```

Hand-written pages (`page` in Categories.js) are mapped by name in
`SettingsShell.pages`. The preset studio never writes preset files itself;
a new mixable aspect is one entry in `backend/pkg/presets/aspects.go` (+
`tests/fixtures/preset-aspects.json`, icon in `PresetModel.ASPECT_ICONS`,
`prefs.presets.aspect.<id>[.desc]` strings). Render it with
`tools/render/presets_render.py`.

## ADDING A SETTING
1. Make sure the key exists in `config/defaults/<domain>.js` (run `make
   schema`: it regenerates the typed adapter `config/adapters/<Domain>Adapter.qml`)
   and, for staged domains, the GlobalStates snapshot list - the audit fails
   otherwise.
2. Add one entry to the category's `schema/<category>.js` section:
   ```js
   { "key": "bar.frameThickness", "type": "slider", "min": 0, "max": 40, "step": 1, "unit": "px",
     "visibleWhen": { "key": "bar.frameEnabled", "equals": true },
     "label": "prefs.bar.frame_thickness", "description": "prefs.bar.frame_thickness.desc",
     "keywords": "frame thickness width border" }
   ```
3. Add the label/description keys to `translations/{en,es,ru}.json`.
4. `make schema`: the entry (label, description, options, range,
   `visibleWhen`) becomes part of the settings catalog
   (`assets/schema/*.schema.json`) used by `yozakura config` and the MCP
   tools. Allowed values of `custom` entries (the editor owns them) go in
   `config/meta/<domain>.js`.

Entry fields: `key` (dotted, `domain.prop[.sub]`; `wallpaper.*` keys live in
~/.cache/yozakura/wallpapers.json), `type` (`toggle | selector | slider | number
| text | font | color-role | list | path | screens | multiselect | custom`;
`color-role` = palette swatches + alpha for a color spec, with `gradient:
true` a list of up to 4 stops), `label`, `description`, `keywords`,
`placeholder` (i18n key), `pattern` (regex a `text` value must match before
it is saved), `options`
(`[{value, label, icon}]`), `min/max/step/unit`, `specialValues`
(`[{value, label}]`), `visibleWhen` / `enabledWhen` (declarative:
`{key, equals|notEquals|in|truthy}`, `{all|any: [...]}`, `{not: ...}`),
`preview` (Registry name), `component` (custom editor name), `keys` (every
key a composite entry reads/resets), `sizeKey` (font), `resettable: false`,
`compositor` (entry or section shown only on that compositor, e.g. `"hyprland"`),
`id` (when there is no single `key`), `target` (PageLink), `sizeUnit`
(font).

Collection types (controls/ListControl, PathControl, ScreensControl,
ChipsControl; pure helpers in SchemaUtil: listInsert/Remove/Move/Set,
newListItem, toggleValue):
- `list`: an array. Objects: `fields: [{key, type: text|number|selector|path|toggle,
  label, placeholder, min/max/step/unit, options, monospace, pattern, flex
  (share of the row, e.g. 0.5)}]`, `newItem`, `itemLabel` ("Rule %1"),
  `addLabel`, `emptyLabel`; strings: `itemType: "text" | "path"` (+ `pathKind`).
  Items can be added, removed and reordered (system.idle.listeners,
  notifications.rules, system.disks).
- `path`: text + Browse (zenity/kdialog), `pathKind` "file" | "dir", `filter`.
- `screens`: monitor multi-select (`[]` = every screen), lists connected and
  remembered names.
- `multiselect`: chips over `options`, value = array of option values.

A rich editor: add `editors/<Name>.qml` (root has `property var entry`,
reads/writes through `SettingsStore`), register it in `Registry.js`, use
`"type": "custom", "component": "<Name>"`. Previews likewise in `previews/`.

Section fields: `id`, `title`, `entries`, and `collapsible: true` (+
`collapsed: true` to start folded) for advanced options; a search jump into
a folded section unfolds it. A category file may pull sections from a
sibling file (appearance.js splices in `schema/glass.js`).

## ADDING A CATEGORY
Create `schema/<id>.js` exporting `category = {id, icon, title, description,
keywords, sections: [{id, title, entries: [...]}]}`, import it in
`Categories.js` and put it in the group of the element it controls (one
page per element; a setting is declared on one page only, see
tests/settings-pages.test.cjs). Expert knobs get `"advanced": true`. A page
merged into another keeps its old id working through `MOVED` in
Categories.js; renamed keys keep the user's value through
`config/meta/KeyAliases.js`.

## CHANGE FLOW
`SettingsStore.set()` writes Config immediately (the whole shell previews the
change live). For staged domains it first calls the GlobalStates
`mark{Theme,Shell,Compositor}Changed()` (snapshot + pause auto-save, the same
flow the old panels used); the ChangesBar then applies (`apply*Changes`,
writes the JSON files) or discards (restores the snapshot). Domains without a
snapshot list are saved immediately (`Config.save<Domain>()`), and
`wallpaper.*` keys go straight to the wallpaper manager (wallpapers.json).

## VERIFY
- `make check`: `settings-schema` audit (keys/defaults, translations,
  options/ranges, conditions, registry, snapshot lists),
  `tests/settings-schema.test.cjs` (schema/search/layout helpers),
  `tests/settings-ui.test.py` (renderer behaviour, offscreen).
- `tools/render/settings_render.py [--mode dark|light|both] [--scroll N]
  [--search q] [--size WxH] CATEGORY...` renders pages to PNG in a private
  Xvfb with your real config, palette and wallpapers.
