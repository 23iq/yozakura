package apphooks

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// lookPath is exec.LookPath; tests replace it.
var lookPath = exec.LookPath

// Qt theming is no longer a hook: QT_QPA_PLATFORMTHEME is set in the
// generated compositor config (backend/pkg/svc/compositor/qtenv.go), never
// in environment.d, which other desktops read too. Older builds wrote
// environment.d/90-<app>-qt.conf; RemoveLegacyQtEnv takes it away (only
// when it is ours) on upgrade and on goodbye.

// legacyQtEnvFile is where older builds wrote the Qt variable.
func legacyQtEnvFile(env Env) string {
	return filepath.Join(env.ConfigHome, "environment.d", "90-"+env.AppID+"-qt.conf")
}

// RemoveLegacyQtEnv deletes the environment.d file an older build wrote;
// a file of that name the user wrote (without our header) stays. It
// reports the removed path ("" when nothing was removed).
func RemoveLegacyQtEnv(env Env) (string, error) {
	path := legacyQtEnvFile(env)
	data, err := os.ReadFile(path)
	if err != nil || !strings.HasPrefix(string(data), "# Written by "+env.AppID+" ") {
		return "", nil
	}
	if isManaged(path) {
		return "", ErrManaged
	}
	if err := removeFile(path); err != nil {
		return "", err
	}
	return path, nil
}
