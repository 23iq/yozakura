.pragma library
.import "theme.js" as Theme
.import "bar.js" as Bar
.import "compositor.js" as Compositor
.import "desktop.js" as Desktop
.import "dock.js" as Dock
.import "notch.js" as Notch
.import "ai.js" as Ai
.import "system.js" as System
.import "voice.js" as Voice
.import "notifications.js" as Notifications
.import "apps.js" as Apps
.import "workspaces.js" as Workspaces
.import "misc.js" as Misc
.import "specials.js" as Specials

// Catalog metadata of every config domain: the part of the settings catalog
// that config/defaults/*.js (values, types) and modules/settings/schema/*.js
// (labels, descriptions, options, ranges, conditions of the settings UI) do
// not already say. tools/schema/gen_schema.cjs merges the three into
// assets/schema/*.schema.json (JSON Schema 2020-12), which `yozakura config`,
// `yozakura mcp` and docs/ai-guide.md are built on. Run `make schema` after
// changing any of them; the `schema-fresh` audit fails on a stale catalog.
//
// Per domain: {description, keys}. `keys` maps a dotted path inside the
// domain ("*" matches one segment, exact paths win over patterns) to:
//   title, description   English text (the settings schema's label and
//                        description, when declared, take precedence)
//   enum                 allowed values (string/number keys)
//   min, max, unit       hard range enforced by the CLI/MCP (overrides the
//                        settings slider range, which is only the UI range)
//   pattern              regex a string value must match
//   items                schema of array items ({type} or {enum})
//   uniqueItems          array items must be distinct
//   format               hint: color, gradient, border, font-family, path,
//                        command, uri, icon, regex
//   secret               value is a credential (masked by the CLI)
//   local                machine specific (endpoints, personal paths): never
//                        saved/exported/shown by presets, kept on apply.
//                        Secrets, format "command" keys and the domains of
//                        catalog.LocalDomains are machine-local implicitly
//   readOnly             not meant to be edited
//   special              sentinels accepted besides the range, e.g.
//                        [{value: -1, label: "Auto"}] (-1 = inherit/auto)
// Every path must exist in config/defaults (gen_schema.cjs fails otherwise).

var domains = {
    "theme": Theme,
    "bar": Bar,
    "compositor": Compositor,
    "desktop": Desktop,
    "dock": Dock,
    "notch": Notch,
    "ai": Ai,
    "system": System,
    "voice": Voice,
    "notifications": Notifications,
    "apps": Apps,
    "workspaces": Workspaces,
    "specials": Specials,
    "general": Misc.general,
    "lockscreen": Misc.lockscreen,
    "overview": Misc.overview,
    "performance": Misc.performance,
    "prefix": Misc.prefix,
    "weather": Misc.weather
};
