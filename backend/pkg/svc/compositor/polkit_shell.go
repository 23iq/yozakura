package compositor

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
)

// FallbackVerb is the CLI verb that starts the external polkit agent only
// when the shell does not register its own (see ShellAgent): startup lines
// that cannot know at write time (the niri/Mango bootstrap, exclusive mode,
// the installer's Hyprland line) run `<app> polkit-fallback`.
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

// ShellAgent reports whether the shell registers its own polkit agent:
// system.polkitAgent is on (the default) in systemFile (the system domain's
// config file) and Quickshell has its Quickshell.Services.Polkit module.
func ShellAgent(systemFile string) bool {
	return ShellAgentEnabled(systemFile) && polkitModule(qmlImportDirs())
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

// polkitModuleDir is the module's directory under a QML import dir.
const polkitModuleDir = "Quickshell/Services/Polkit"

// polkitModule reports a Quickshell Polkit module (its qmldir) in one of
// dirs. Quickshell builds without polkit do not install it.
func polkitModule(dirs []string) bool {
	for _, d := range dirs {
		if d == "" {
			continue
		}
		if st, err := os.Stat(filepath.Join(d, polkitModuleDir, "qmldir")); err == nil && !st.IsDir() {
			return true
		}
	}
	return false
}

// qmlImportDirs lists where a Quickshell build installs its QML modules:
// the import path variables, the prefix of the qs binary on PATH (lib/qt6
// on distribution packages, lib/qt-6 on source builds) and the usual
// system dirs.
func qmlImportDirs() []string {
	var dirs []string
	for _, v := range []string{"QML_IMPORT_PATH", "QML2_IMPORT_PATH", "NIXPKGS_QT6_QML_IMPORT_PATH"} {
		dirs = append(dirs, filepath.SplitList(os.Getenv(v))...)
	}
	if qs, err := exec.LookPath("qs"); err == nil {
		if real, err := filepath.EvalSymlinks(qs); err == nil {
			dirs = append(dirs, prefixQMLDirs(filepath.Dir(filepath.Dir(real)))...)
		}
	}
	for _, prefix := range []string{"/usr", "/usr/local", "/run/current-system/sw"} {
		dirs = append(dirs, prefixQMLDirs(prefix)...)
	}
	return append(dirs, "/usr/lib/x86_64-linux-gnu/qt6/qml", "/usr/lib/aarch64-linux-gnu/qt6/qml")
}

func prefixQMLDirs(prefix string) []string {
	var out []string
	for _, lib := range []string{"lib", "lib64"} {
		for _, qt := range []string{"qt6", "qt-6"} {
			out = append(out, filepath.Join(prefix, lib, qt, "qml"))
		}
	}
	return out
}
