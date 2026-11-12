package compositor

import (
	"encoding/json"
	"os"
	"strings"
)

// FallbackVerb is the CLI verb that starts the external polkit agent only
// when the shell does not register its own (the shell reports it to the
// daemon, polkitState): startup lines that cannot know at write time (the
// niri/Mango bootstrap, exclusive mode, the installer's Hyprland line) run
// `<app> polkit-fallback`.
const FallbackVerb = "polkit-fallback"

// FallbackCommand is the startup shell command for bin (the launcher
// path): `<bin> polkit-fallback` with bin quoted for sh when it needs it,
// or "" when no external agent is installed (the verb would have nothing
// to start). Lines that spawn argv (niri) use FallbackArgv.
func FallbackCommand(bin string) string {
	if PolkitCommand() == "" {
		return ""
	}
	return FallbackShellCommand(bin)
}

// FallbackShellCommand is `<bin> polkit-fallback` as an sh command line,
// whether or not an external agent is installed.
func FallbackShellCommand(bin string) string {
	return ShellWord(bin) + " " + FallbackVerb
}

// FallbackArgv is FallbackCommand as argv: nil when no external agent is
// installed.
func FallbackArgv(bin string) []string {
	if PolkitCommand() == "" {
		return nil
	}
	return []string{bin, FallbackVerb}
}

// ShellWord quotes s as one sh word: unchanged when it holds only
// characters sh never splits or expands, else single-quoted (install.sh's
// polkit_autostart writes the same text).
func ShellWord(s string) string {
	if s != "" && strings.Trim(s, shellSafe) == "" {
		return s
	}
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}

const shellSafe = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_@%+=:,./-"

// HyprlangValue escapes a value for a hyprlang line, where # starts a
// comment unless doubled.
func HyprlangValue(s string) string {
	return strings.ReplaceAll(s, "#", "##")
}

// startupPolkit is what the generated config starts on niri and Mango for
// polkit. While the shell's own agent takes the prompts it is
// `<launcher> polkit-fallback` (what the Hyprland installer line runs):
// the external agent then starts only when the shell does not register
// its own in time, so a shell that never comes up still leaves an agent.
// Nothing when no external agent is installed (find). With the shell's
// agent off: the one the shell sent, else the installed one.
func startupPolkit(in Input, find func() string) string {
	if in.ShellPolkit {
		if find() == "" {
			return ""
		}
		return FallbackShellCommand(shellBinary())
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
