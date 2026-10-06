package termlook

// Nerd Font glyphs are written as \U escapes on purpose: raw Private-Use
// characters are invisible in most editors and flagged by local hooks.

// SeparatorGlyphs holds the left-pointing-into-next ([0]) and the mirrored
// ([1]) glyph of each separator family.
var SeparatorGlyphs = map[string][2]string{
	"powerline": {"\U0000E0B0", "\U0000E0B2"},
	"rounded":   {"\U0000E0B4", "\U0000E0B6"},
	"slant":     {"\U0000E0BC", "\U0000E0BE"},
	"flame":     {"\U0000E0C0", "\U0000E0C2"},
	"pixel":     {"\U0000E0C4", "\U0000E0C6"},
	"arrow":     {"❯", "❮"},
	"none":      {"", ""},
}

// Frame corners drawn by presets with Frame set.
const (
	frameTop    = "╭─"
	frameBottom = "╰─"
)

// defaultIcons is the Nerd Font icon each segment type shows unless the
// preset overrides it. os and battery icons are dynamic (per distro/state).
var defaultIcons = map[string]string{
	"user":       "\U0000F007",
	"host":       "\U0000F108",
	"dir":        "\U0000F07C",
	"git_branch": "\U0000E725",
	"duration":   "\U0000F252",
	"time":       "\U0000F017",
	"status":     "\U0000F00D",
	"jobs":       "\U0000F013",
}

// lang is one toolchain shown by the "langs" segment.
type lang struct {
	starship string // starship module
	omp      string // oh-my-posh segment type
	icon     string
}

var langs = []lang{
	{"nodejs", "node", "\U0000E718"},
	{"python", "python", "\U0000E73C"},
	{"golang", "go", "\U0000E627"},
	{"rust", "rust", "\U0000E7A8"},
	{"java", "java", "\U0000E738"},
}

// osSymbols are starship [os.symbols] (oh-my-posh ships its own).
var osSymbols = [][2]string{
	{"Alpine", "\U0000F300"},
	{"Arch", "\U0000F303"},
	{"Artix", "\U0000F31F"},
	{"Debian", "\U0000F306"},
	{"EndeavourOS", "\U0000F322"},
	{"Fedora", "\U0000F30A"},
	{"Garuda", "\U0000F337"},
	{"Gentoo", "\U0000F30D"},
	{"Linux", "\U0000F31A"},
	{"Macos", "\U0000F179"},
	{"Manjaro", "\U0000F312"},
	{"Mint", "\U0000F30E"},
	{"NixOS", "\U0000F313"},
	{"openSUSE", "\U0000F314"},
	{"Pop", "\U0000F32A"},
	{"Ubuntu", "\U0000F31B"},
	{"Void", "\U0000F32E"},
}

// Battery state glyphs.
const (
	batteryFull        = "\U0000F240 "
	batteryCharging    = "\U0000F0E7 "
	batteryDischarging = "\U0000F242 "
	batteryEmpty       = "\U0000F244 "
	readOnlyLock       = " \U0000F023"
)

// isPUA reports Private-Use code points (Nerd Font glyph ranges).
func isPUA(r rune) bool {
	return (r >= 0xE000 && r <= 0xF8FF) || (r >= 0xF0000 && r <= 0x10FFFF)
}

func hasPUA(s string) bool {
	for _, r := range s {
		if isPUA(r) {
			return true
		}
	}
	return false
}

// segmentIcon resolves the icon a segment shows: an explicit icon, nothing
// for "none", else the type default when the preset uses a Nerd Font.
func segmentIcon(p Preset, s Segment) string {
	switch {
	case s.Icon == "none":
		return ""
	case s.Icon != "":
		return s.Icon
	case !p.NerdFont:
		return ""
	}
	return defaultIcons[s.Type]
}
