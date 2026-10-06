package compositor

import (
	"encoding/json"

	"yozakura/backend/pkg/brand"
)

// Input is the JSON-RPC payload the QML shell assembles and passes to the
// compositor service on every regeneration trigger. The shape is
// deliberately flat (no nested JsonAdapter access) so the Go side can be
// tested without depending on Quickshell.
type Input struct {
	Compositor CompositorConfig `json:"compositor"`
	Theme      ThemeConfig      `json:"theme"`
	Bar        BarConfig        `json:"bar"`
	Layout     string           `json:"layout"`
	Keybinds   KeybindsConfig   `json:"keybinds"`
	// Hyprland is the full hl.config() table (general + decoration) the
	// shell applies live. When present it is rendered into the
	// hyprland.{lua,conf} entry files on top of yozd's output so the
	// persisted appearance matches the live one (see hyprland.go).
	Hyprland map[string]any `json:"hyprland,omitempty"`
	// Motion is the resolved motion profile (config/motion/MotionSpec.js):
	// the curves and every animation-tree node, rendered after the
	// appearance table (see motion.go).
	Motion *MotionSpec `json:"motion,omitempty"`
	// SmartGaps adds the no-gaps workspace rule for single tiled windows.
	SmartGaps bool `json:"smartGaps,omitempty"`
	// WindowRules are the shell's own window rules (special workspaces:
	// modules/specials/Specials.js windowRules), rendered as
	// [[window_rules]] for yozd.
	WindowRules []WindowRule `json:"windowRules,omitempty"`
	// Displays are the saved monitor settings (displays.monitors), keyed by
	// the current connector name (the shell resolves saved ids first),
	// rendered as [[monitors]] (see devices.go).
	Displays []DisplayInput `json:"displays,omitempty"`
	// Keyboard is the keyboard domain, rendered as [input.keyboard]. nil
	// (older shells) keeps the historical empty layouts.
	Keyboard *KeyboardInput `json:"keyboard,omitempty"`
	// PolkitCmd starts the polkit agent on niri and Mango (Hyprland's
	// installer line does it there). The backend fills it (PolkitCommand).
	PolkitCmd string `json:"polkitCmd,omitempty"`
}

// WindowRule sends windows matching Match ("class:^(x)$") to Workspace
// ("special:Telegram silent").
type WindowRule struct {
	Match     string `json:"match"`
	Workspace string `json:"workspace"`
}

// MotionSpec mirrors MotionSpec.resolve() in config/motion/MotionSpec.js.
type MotionSpec struct {
	Profile    string            `json:"profile"`
	Enabled    bool              `json:"enabled"`
	Curves     []MotionCurve     `json:"curves"`
	Animations []MotionAnimation `json:"animations"`
}

// MotionCurve is a bezier ({Points}) or a spring ({Mass, Stiffness,
// Dampening}, with Points as the bezier fallback for hyprland.conf).
type MotionCurve struct {
	Name      string      `json:"name"`
	Type      string      `json:"type"`
	Points    [][]float64 `json:"points"`
	Mass      float64     `json:"mass,omitempty"`
	Stiffness float64     `json:"stiffness,omitempty"`
	Dampening float64     `json:"dampening,omitempty"`
}

// MotionAnimation is one Hyprland animation-tree node.
type MotionAnimation struct {
	Leaf    string  `json:"leaf"`
	Enabled bool    `json:"enabled"`
	Speed   float64 `json:"speed"`
	Curve   string  `json:"curve"`
	Kind    string  `json:"kind"`
	Style   string  `json:"style"`
}

type CompositorConfig struct {
	GapsIn              int          `json:"gapsIn"`
	GapsOut             int          `json:"gapsOut"`
	BorderSize          int          `json:"borderSize"`
	Rounding            int          `json:"rounding"`
	SyncBorderColor     bool         `json:"syncBorderColor"`
	BorderColor         string       `json:"borderColor"`
	ActiveBorderColor   []string     `json:"activeBorderColor"`
	ActiveBorderAngle   int          `json:"activeBorderAngle"`
	InactiveBorderColor []string     `json:"inactiveBorderColor"`
	InactiveBorderAngle int          `json:"inactiveBorderAngle"`
	Shadow              ShadowConfig `json:"shadow"`
	Blur                BlurConfig   `json:"blur"`
	Animations          Animations   `json:"animations"`
}

type ShadowConfig struct {
	Enabled       bool    `json:"enabled"`
	Range         int     `json:"range"`
	RenderPower   int     `json:"renderPower"`
	Sharp         bool    `json:"sharp"`
	IgnoreWindow  bool    `json:"ignoreWindow"`
	Color         string  `json:"color"`
	ColorInactive string  `json:"colorInactive"`
	Opacity       float64 `json:"opacity"`
	Offset        string  `json:"offset"`
	Scale         float64 `json:"scale"`
}

type BlurConfig struct {
	Enabled                 bool    `json:"enabled"`
	Size                    int     `json:"size"`
	Passes                  int     `json:"passes"`
	IgnoreOpacity           bool    `json:"ignoreOpacity"`
	ExplicitIgnoreAlpha     bool    `json:"explicitIgnoreAlpha"`
	IgnoreAlphaValue        float64 `json:"ignoreAlphaValue"`
	NewOptimizations        bool    `json:"newOptimizations"`
	Xray                    bool    `json:"xray"`
	Noise                   float64 `json:"noise"`
	Contrast                float64 `json:"contrast"`
	Brightness              float64 `json:"brightness"`
	Vibrancy                float64 `json:"vibrancy"`
	VibrancyDarkness        float64 `json:"vibrancyDarkness"`
	Special                 bool    `json:"special"`
	Popups                  bool    `json:"popups"`
	PopupsIgnorealpha       float64 `json:"popupsIgnorealpha"`
	InputMethods            bool    `json:"inputMethods"`
	InputMethodsIgnorealpha float64 `json:"inputMethodsIgnorealpha"`
}

type Animations struct {
	Enabled        bool   `json:"enabled"`
	WorkspaceStyle string `json:"workspaceStyle"`
}

type ThemeConfig struct {
	SrBarBgOpacity float64 `json:"srBarBgOpacity"`
	SrBgOpacity    float64 `json:"srBgOpacity"`
	ShadowColor    string  `json:"shadowColor"`
	ShadowOpacity  float64 `json:"shadowOpacity"`
	// GlassShellBlur is false when the glass system is switched off
	// (theme.glass.enabled): the shell layers are then not blurred. nil
	// (older shells) keeps the blur.
	GlassShellBlur *bool `json:"glassShellBlur,omitempty"`
}

type BarConfig struct {
	Position string `json:"position"`
}

// KeybindsConfig mirrors the shape Config.keybindsLoader.adapter exposes in
// QML: a flat map of yozakura core binds, a nested system section, and a
// custom array of (keys x actions) binds.
type KeybindsConfig struct {
	Yozakura map[string]Keybind `json:"yozakura"`
	System   map[string]Keybind `json:"system"`
	Custom   []CustomBind       `json:"custom"`
}

// UnmarshalJSON also accepts the legacy root key (brand.LegacyAppID) for
// the core binds, so payloads from an older shell keep working.
func (k *KeybindsConfig) UnmarshalJSON(data []byte) error {
	type plain KeybindsConfig
	var out plain
	if err := json.Unmarshal(data, &out); err != nil {
		return err
	}
	if out.Yozakura == nil {
		var raw map[string]json.RawMessage
		if json.Unmarshal(data, &raw) == nil {
			if legacy, ok := raw[brand.LegacyAppID]; ok {
				if err := json.Unmarshal(legacy, &out.Yozakura); err != nil {
					return err
				}
			}
		}
	}
	*k = KeybindsConfig(out)
	return nil
}

type Keybind struct {
	Modifiers []string `json:"modifiers"`
	Key       string   `json:"key"`
	Action    Action   `json:"action"`
}

// Action is the wire form of a KeybindActions catalog entry, or the legacy
// {dispatcher, argument, flags} triple. Exactly one of ID or Dispatcher is
// populated on a valid action.
type Action struct {
	ID         string         `json:"id,omitempty"`
	Args       map[string]any `json:"args,omitempty"`
	Dispatcher string         `json:"dispatcher,omitempty"`
	Argument   string         `json:"argument,omitempty"`
	Flags      string         `json:"flags,omitempty"`
	Layouts    []string       `json:"layouts,omitempty"`
}

type CustomBind struct {
	Name    string    `json:"name"`
	Keys    []KeySpec `json:"keys"`
	Actions []Action  `json:"actions"`
	Enabled bool      `json:"enabled"`
}

type KeySpec struct {
	Modifiers []string `json:"modifiers"`
	Key       string   `json:"key"`
}
