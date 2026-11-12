package daemon

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/envclean"
)

func TestMediaBackend(t *testing.T) {
	env := func(kv map[string]string) func(string) string {
		return func(k string) string { return kv[k] }
	}
	has := func(paths ...string) func(string) bool {
		return func(p string) bool {
			for _, x := range paths {
				if x == p {
					return true
				}
			}
			return false
		}
	}

	assert.Equal(t, "", mediaBackend(env(map[string]string{"QT_MEDIA_BACKEND": "gstreamer"}), has()),
		"the user's choice is kept")
	assert.Equal(t, "gstreamer", mediaBackend(env(nil), has()), "no FFmpeg plugin: GStreamer")
	assert.Equal(t, "ffmpeg", mediaBackend(env(nil), has("/usr/lib/qt6/plugins/multimedia/libffmpegmediaplugin.so")),
		"Arch layout")
	assert.Equal(t, "ffmpeg", mediaBackend(env(map[string]string{"QT_PLUGIN_PATH": "/a::/b"}), has("/b/multimedia/libffmpegmediaplugin.so")),
		"QT_PLUGIN_PATH entries")
	assert.Equal(t, "ffmpeg", mediaBackend(env(map[string]string{brand.EnvPrefix + "NIX_ENV": "/nix/store/x-env"}),
		has("/nix/store/x-env/lib/qt-6/plugins/multimedia/libffmpegmediaplugin.so")), "Nix package env")
}

// The main shell (and yozd, the clipboard watcher: every child) never
// inherits the role of a separate window process the daemon was started
// from (a terminal opened in Settings): it would come up without its
// notification server, shortcuts or idle handling.
func TestQsEnvDropsWindowRole(t *testing.T) {
	for _, k := range envclean.WindowVars {
		t.Setenv(k, "settings")
	}
	for _, kv := range (&Daemon{}).qsEnv() {
		for _, k := range envclean.WindowVars {
			if strings.HasPrefix(kv, k+"=") {
				t.Errorf("qsEnv kept %s", kv)
			}
		}
	}
}
