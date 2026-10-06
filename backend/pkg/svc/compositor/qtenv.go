package compositor

import (
	"os"
	"os/exec"

	"yozakura/backend/pkg/brand"
)

// Qt apps follow the generated palette through qt6ct/qt5ct when
// QT_QPA_PLATFORMTHEME names one. It is set in our generated compositor
// config (the session environment), never in environment.d, which other
// desktops (Plasma, GNOME) read too.

// SessionQtThemeEnv holds the session's own QT_QPA_PLATFORMTHEME: the
// shell start sets qt6ct for Quickshell itself, so the daemon cannot read
// the user's value from QT_QPA_PLATFORMTHEME.
var SessionQtThemeEnv = brand.EnvPrefix + "SESSION_QT_PLATFORMTHEME"

// sessionQtTheme is the user's QT_QPA_PLATFORMTHEME ("" when unset).
func sessionQtTheme() string {
	if v, ok := os.LookupEnv(SessionQtThemeEnv); ok {
		return v
	}
	return os.Getenv("QT_QPA_PLATFORMTHEME")
}

// qtLookPath is exec.LookPath; tests replace it.
var qtLookPath = exec.LookPath

// qtPlatformTheme is the qtct flavour installed ("" for none).
func qtPlatformTheme() string {
	for _, b := range []string{"qt6ct", "qt5ct"} {
		if _, err := qtLookPath(b); err == nil {
			return b
		}
	}
	return ""
}

// QtEnv is the environment the generated config sets for Qt theming
// (apps.theming.qt on): nothing when no qtct is installed or when the
// session already names another platform theme (the user's own choice
// wins; ours is only re-stated when it is what is set).
func QtEnv(on bool) map[string]string {
	theme := qtPlatformTheme()
	if !on || theme == "" {
		return nil
	}
	if cur := sessionQtTheme(); cur != "" && cur != theme {
		return nil
	}
	return map[string]string{"QT_QPA_PLATFORMTHEME": theme}
}
