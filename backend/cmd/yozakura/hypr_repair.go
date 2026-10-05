package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/fsutil"
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
func luaLoadLine() string {
	v := brand.AppID
	return fmt.Sprintf(`local %s = loadfile(os.getenv("HOME") .. "%shyprland.lua") if %s then %s() end`, v, dataRel(), v, v)
}

// repairHyprlandEntry keeps an existing Hyprland integration loadable: it
// guards the legacy include line in ~/.config/hypr/hyprland.lua and, when a
// Hyprland config loads the data dir, recreates missing bootstrap files that
// start the shell (bin, absolute). Generated files are never overwritten.
// Runs on every shell start, since `update` leaves compositor configs alone.
func repairHyprlandEntry(home, bin string) {
	hypr := filepath.Join(home, ".config/hypr")
	luaPath := filepath.Join(hypr, "hyprland.lua")
	confPath := filepath.Join(hypr, "hyprland.conf")
	if isHomeManagerManaged(luaPath) || isHomeManagerManaged(confPath) {
		return
	}

	loads := false
	if data, err := os.ReadFile(luaPath); err == nil {
		text := string(data)
		if strings.Contains(text, legacyLuaLoadLine()) {
			text = strings.ReplaceAll(text, legacyLuaLoadLine(), luaLoadLine())
			if err := fsutil.WriteFile(luaPath, []byte(text), 0o644); err != nil {
				fmt.Fprintf(os.Stderr, "Warning: could not update %s: %v\n", luaPath, err)
			}
		}
		loads = strings.Contains(text, dataRel()+"hyprland.lua")
	}
	if data, err := os.ReadFile(confPath); err == nil && strings.Contains(string(data), dataRel()+"hyprland.conf") {
		loads = true
	}
	if !loads {
		return
	}

	dataDir := filepath.Join(home, dataRel())
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
