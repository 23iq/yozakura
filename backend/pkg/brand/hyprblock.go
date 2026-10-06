package brand

import "fmt"

// DataRel is the data dir relative to $HOME, with leading and trailing
// slashes: "/.local/share/<app>/".
func DataRel() string { return "/.local/share/" + AppID + "/" }

// HyprLuaLoadLine loads the generated Hyprland Lua config only when it
// exists. It stays a single line so the installer can drop it exactly.
func HyprLuaLoadLine() string {
	v := AppID
	return fmt.Sprintf(`local %s = loadfile(os.getenv("HOME") .. "%shyprland.lua") if %s then %s() end`, v, DataRel(), v, v)
}

// HyprConfBlock is the block the installer appends to hyprland.conf.
func HyprConfBlock() string {
	return ConfigBlockMarker("#") + "\nsource = ~" + DataRel() + "hyprland.conf\n\n# OVERRIDES\n" + ConfigOverridesNote("#", "source") + "\n"
}

// HyprLuaBlock is the block the installer appends to hyprland.lua.
func HyprLuaBlock() string {
	return ConfigBlockMarker("--") + "\n" + HyprLuaLoadLine() + "\n\n-- OVERRIDES\n" + ConfigOverridesNote("--", "source") + "\n"
}
