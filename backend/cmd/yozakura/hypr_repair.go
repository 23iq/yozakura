package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/exclusive"
	"yozakura/backend/pkg/fsutil"
	"yozakura/backend/pkg/svc/compositor"
)

// legacyLuaLoadLine is the include line older installs wrote into
// hyprland.lua. Calling loadfile's result directly raises when the data
// file is missing, which aborts the user's whole Hyprland config: no binds,
// no autostart, only Hyprland's default wallpaper.
func legacyLuaLoadLine() string {
	return `loadfile(os.getenv("HOME") .. "` + dataRel() + `hyprland.lua")()`
}

// luaLoadLine loads the generated config only when it exists. It stays a
// single line so removeBlock can drop it exactly.
func luaLoadLine() string { return brand.HyprLuaLoadLine() }

// hyprDirIn is <XDG_CONFIG_HOME>/hypr for home (paths.HyprDir for $HOME).
func hyprDirIn(home string) string {
	return filepath.Join(brand.XDGBase(home, "XDG_CONFIG_HOME", ".config"), "hypr")
}

// lineFix replaces an include line an entry may still carry.
type lineFix struct{ from, to string }

// staleEntryLines lists, per entry file, the include lines to replace by
// the one that loads dataDir: the unguarded legacy loadfile line, and the
// lines written before the data dir followed XDG_DATA_HOME (they always
// spelled ~/.local/share/<app>; with the default data dir they already are
// the current lines and are left alone).
func staleEntryLines(home, dataDir string) (lua, conf []lineFix) {
	defData := filepath.Join(home, dataRel())
	luaLine := brand.HyprLuaLoadLineFor(home, dataDir)
	lua = []lineFix{{legacyLuaLoadLine(), luaLine}, {brand.HyprLuaLoadLineFor(home, defData), luaLine}}
	conf = []lineFix{{brand.HyprConfSourceLineFor(home, defData), brand.HyprConfSourceLineFor(home, dataDir)}}
	return lua, conf
}

// dataRefs are the spellings of <data dir>/name an entry may load: the
// historical ~/.local/share/<app> one and the one for dataDir.
func dataRefs(home, dataDir, name string) []string {
	ref := filepath.Join(dataDir, name)
	if rel, ok := brand.DataRelTo(home, dataDir); ok {
		ref = rel + name
	}
	// the Lua entry spells it as a string literal (escaped quotes, backslashes)
	return []string{dataRel() + name, ref, brand.LuaQuote(ref)}
}

// fixEntry applies fixes to the entry at path (when it exists) and reports
// whether it loads one of refs afterwards. When unsafe is set (the data dir
// cannot be spelled in the entry's language) the entry is left untouched
// and the reason is logged if a fix would have applied.
func fixEntry(path string, fixes []lineFix, refs []string, unsafe error) bool {
	data, err := os.ReadFile(path)
	if err != nil {
		return false
	}
	text := string(data)
	for _, f := range fixes {
		if f.from != f.to && strings.Contains(text, f.from) {
			text = strings.ReplaceAll(text, f.from, f.to)
		}
	}
	if text != string(data) && unsafe != nil {
		fmt.Fprintf(os.Stderr, "Warning: not updating %s: %v\n", path, unsafe)
		text = string(data)
	}
	if text != string(data) {
		if err := fsutil.WriteFile(path, []byte(text), 0o644); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: could not update %s: %v\n", path, err)
		}
	}
	for _, ref := range refs {
		if strings.Contains(text, ref) {
			return true
		}
	}
	return false
}

// repairHyprlandEntry keeps an existing Hyprland integration loadable: it
// guards the legacy include line in <XDG_CONFIG_HOME>/hypr/hyprland.lua,
// points include lines written for ~/.local/share/<app> at the data dir in
// use (XDG_DATA_HOME, as package paths resolves it) and, when a Hyprland
// config loads the data dir, recreates missing bootstrap files that start
// the shell (bin, absolute). The installer's old polkit line, and the one
// exclusive mode's minimal entry wrote, become `<bin> polkit-fallback`
// (migratePolkitLine, exclusive.UpdatePolkit). Generated files are never
// overwritten. Runs on every shell start, since `update` leaves compositor
// configs alone.
func repairHyprlandEntry(home, bin string) {
	hypr := hyprDirIn(home)
	luaPath := filepath.Join(hypr, "hyprland.lua")
	confPath := filepath.Join(hypr, "hyprland.conf")
	if isHomeManagerManaged(luaPath) || isHomeManagerManaged(confPath) {
		return
	}
	for _, p := range []string{luaPath, confPath} {
		if _, err := migratePolkitLine(p, bin); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: could not update the polkit line in %s: %v\n", p, err)
		}
	}
	// Exclusive mode's minimal entry started the external agent itself.
	if _, err := exclusive.UpdatePolkit(hypr, compositor.ExternalPolkitCommands(), compositor.FallbackShellCommand(bin)); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: could not update the polkit line of the exclusive mode entry: %v\n", err)
	}

	dataDir := brand.DataDirIn(home)
	luaFixes, confFixes := staleEntryLines(home, dataDir)
	loadsLua := fixEntry(luaPath, luaFixes, dataRefs(home, dataDir, "hyprland.lua"), brand.HyprLuaDataDirError(dataDir))
	loadsConf := fixEntry(confPath, confFixes, dataRefs(home, dataDir, "hyprland.conf"), brand.HyprConfDataDirError(dataDir))
	if !loadsLua && !loadsConf {
		return
	}

	if err := os.MkdirAll(dataDir, 0o755); err != nil {
		return
	}
	note := "Bootstrap written by " + brand.DisplayName + "; replaced on the first start."
	stubs := map[string]string{
		"hyprland.lua":  fmt.Sprintf("-- %s\nhl.on(\"hyprland.start\", function()\n    hl.exec_cmd(%q)\nend)\n", note, bin),
		"hyprland.conf": fmt.Sprintf("# %s\nexec-once = %s\n", note, bin),
		// The hyprlang entry sources the daemon's output unconditionally,
		// so a missing one would leave the session without autostart.
		"hyprland." + brand.Daemon + ".conf": fmt.Sprintf("# %s\nexec-once = %s\n", note, bin),
	}
	for name, body := range stubs {
		path := filepath.Join(dataDir, name)
		if _, err := os.Stat(path); err == nil {
			continue
		}
		if err := fsutil.WriteFile(path, []byte(body), 0o644); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: could not write %s: %v\n", path, err)
		}
	}
}
