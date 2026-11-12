package compositor

import (
	"encoding/json"
	"os"
)

// FallbackVerb is the CLI verb that starts the external polkit agent only
// when the shell does not register its own (the shell reports it to the
// daemon, polkitState): startup lines that cannot know at write time (the
// niri/Mango bootstrap, exclusive mode, the installer's Hyprland line) run
// `<app> polkit-fallback`.
const FallbackVerb = "polkit-fallback"

// FallbackCommand is the startup command for bin (the launcher path):
// `<bin> polkit-fallback`, or "" when no external agent is installed (the
// verb would have nothing to start).
func FallbackCommand(bin string) string {
	if PolkitCommand() == "" {
		return ""
	}
	return bin + " " + FallbackVerb
}

// startupPolkit is the external agent the generated config starts: none
// while the shell's own agent takes the prompts, else the one the shell
// sent or the installed one (find).
func startupPolkit(in Input, find func() string) string {
	if in.ShellPolkit {
		return ""
	}
	if in.PolkitCmd != "" {
		return in.PolkitCmd
	}
	return find()
}

// ShellAgentEnabled reads system.polkitAgent; a missing or unreadable file
// or key is the default, on.
func ShellAgentEnabled(systemFile string) bool {
	data, err := os.ReadFile(systemFile)
	if err != nil {
		return true
	}
	var doc struct {
		PolkitAgent *bool `json:"polkitAgent"`
	}
	if json.Unmarshal(data, &doc) != nil || doc.PolkitAgent == nil {
		return true
	}
	return *doc.PolkitAgent
}
