package voice

// Warning codes of Status().warnings (Settings maps them to text).
const (
	WarnDisabled        = "disabled"
	WarnRecorderMissing = "recorder_missing"
	WarnTyperMissing    = "typer_missing"
	WarnVADMissing      = "vad_missing"
	WarnGPUIgnored      = "gpu_ignored"
)

// recorderTool is the first installed recorder ("" when none).
func recorderTool(have func(string) bool) string {
	for _, argv := range captureCommands() {
		if have(argv[0]) {
			return argv[0]
		}
	}
	return ""
}

// typerAvailable reports whether the configured typing method can run
// (mirrors Typer.Type: auto tries wtype, ydotool, then wl-copy + wtype).
func typerAvailable(method string, have func(string) bool) bool {
	switch method {
	case "wtype":
		return have("wtype")
	case "ydotool":
		return have("ydotool")
	case "clipboard":
		return have("wl-copy") && have("wtype")
	case "auto", "":
		return have("wtype") || have("ydotool") || (have("wl-copy") && have("wtype"))
	}
	return false
}

// healthWarnings lists what keeps voice input from working or from doing
// what the settings ask for, given the installed tools and files.
func healthWarnings(cfg Config, backend string, vadPresent bool, have func(string) bool) []string {
	out := []string{}
	if !cfg.Enabled {
		out = append(out, WarnDisabled)
	}
	if recorderTool(have) == "" {
		out = append(out, WarnRecorderMissing)
	}
	if !typerAvailable(cfg.TypingMethod, have) {
		out = append(out, WarnTyperMissing)
	}
	if cfg.ServerVad && !vadPresent {
		out = append(out, WarnVADMissing)
	}
	if cfg.UseGPU && backend == "cpu" {
		out = append(out, WarnGPUIgnored)
	}
	return out
}
