package brand

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// DataRel is the default data dir relative to $HOME, with leading and
// trailing slashes: "/.local/share/<app>/". Blocks written before the data
// dir followed XDG_DATA_HOME always spell it this way, so it also serves to
// recognise them.
func DataRel() string { return "/.local/share/" + AppID + "/" }

// UserHome is the home dir, "/tmp" when it cannot be resolved.
func UserHome() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return "/tmp"
	}
	return home
}

// XDGBase is the XDG base dir named by env (e.g. XDG_DATA_HOME), or
// <home>/<def> when it is unset or empty. Package paths resolves every
// app dir through it, so configs that point at those dirs agree with it.
func XDGBase(home, env, def string) string {
	if v := os.Getenv(env); v != "" {
		return v
	}
	return filepath.Join(home, def)
}

// DataDirIn is the app data dir (<XDG_DATA_HOME>/<app>) for home.
func DataDirIn(home string) string {
	return filepath.Join(XDGBase(home, "XDG_DATA_HOME", ".local/share"), AppID)
}

// DataRelTo spells dataDir relative to home ("/.local/share/<app>/") when
// it lies under home; ok is false otherwise.
func DataRelTo(home, dataDir string) (string, bool) {
	if home == "" || !filepath.IsAbs(home) || !filepath.IsAbs(dataDir) {
		return "", false
	}
	rel, err := filepath.Rel(home, dataDir)
	if err != nil || rel == "." || rel == ".." || strings.HasPrefix(rel, "../") {
		return "", false
	}
	return "/" + filepath.ToSlash(rel) + "/", true
}

// HyprLuaLoadLine loads the generated Hyprland Lua config only when it
// exists. It stays a single line so the installer can drop it exactly.
func HyprLuaLoadLine() string { return HyprLuaLoadLineFor(UserHome(), DataDirIn(UserHome())) }

// HyprLuaLoadLineFor is HyprLuaLoadLine for an explicit home and data dir:
// relative to $HOME when the data dir is under home (the historical,
// byte-identical form), else its absolute path.
func HyprLuaLoadLineFor(home, dataDir string) string {
	v := AppID
	if rel, ok := DataRelTo(home, dataDir); ok {
		return fmt.Sprintf(`local %s = loadfile(os.getenv("HOME") .. "%shyprland.lua") if %s then %s() end`, v, rel, v, v)
	}
	return fmt.Sprintf(`local %s = loadfile(%q) if %s then %s() end`, v, filepath.Join(dataDir, "hyprland.lua"), v, v)
}

// HyprConfSourceLineFor is the line of the hyprland.conf block that sources
// the generated config from dataDir ("~/..." when it is under home).
func HyprConfSourceLineFor(home, dataDir string) string {
	if rel, ok := DataRelTo(home, dataDir); ok {
		return "source = ~" + rel + "hyprland.conf"
	}
	return "source = " + filepath.Join(dataDir, "hyprland.conf")
}

// HyprConfBlock is the block the installer appends to hyprland.conf.
func HyprConfBlock() string { return HyprConfBlockFor(UserHome(), DataDirIn(UserHome())) }

// HyprConfBlockFor is HyprConfBlock for an explicit home and data dir.
func HyprConfBlockFor(home, dataDir string) string {
	return ConfigBlockMarker("#") + "\n" + HyprConfSourceLineFor(home, dataDir) + "\n\n# OVERRIDES\n" + ConfigOverridesNote("#", "source") + "\n"
}

// HyprLuaBlock is the block the installer appends to hyprland.lua.
func HyprLuaBlock() string { return HyprLuaBlockFor(UserHome(), DataDirIn(UserHome())) }

// HyprLuaBlockFor is HyprLuaBlock for an explicit home and data dir.
func HyprLuaBlockFor(home, dataDir string) string {
	return ConfigBlockMarker("--") + "\n" + HyprLuaLoadLineFor(home, dataDir) + "\n\n-- OVERRIDES\n" + ConfigOverridesNote("--", "source") + "\n"
}
