package ipc

// SkippedBind is a bind the compositor config generator could not express
// and therefore did not write (a silent drop would hide it from the user).
// Name is the shell's label ("Yozakura: launcher", "Custom Bind 2").
type SkippedBind struct {
	Name       string   `json:"name"`
	Modifiers  []string `json:"modifiers"`
	Key        string   `json:"key"`
	Dispatcher string   `json:"dispatcher"`
	Reason     string   `json:"reason"`
}

// BindSkipper is implemented by config generators that can drop binds;
// SkippedKeybinds lists exactly what GenerateKeybinds leaves out.
// Answered over `Config.SkippedBinds` (`yozd config skipped-binds`).
type BindSkipper interface {
	SkippedKeybinds(config ConfigKeybinds) []SkippedBind
}
