package daemon

import (
	"os"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/brand"
)

// QtMultimedia backend for Quickshell (video wallpapers, previews) when the
// user did not set QT_MEDIA_BACKEND.
//
// The FFmpeg backend decodes with VA-API/VDPAU/CUDA when the GPU offers it
// and hands the frames to the scene graph as textures. The GStreamer
// backend needs a GL context shared with the Wayland surface; under
// Quickshell it fails ("Could not create display context ...
// EGL_BAD_CONTEXT") and falls back to software decoding plus a CPU colour
// conversion of every frame: a 4K H.264 loop costs ~50% of a core there
// against ~2% with VA-API (`ffmpeg -benchmark` on the same file). So FFmpeg
// is preferred whenever Qt ships its plugin, GStreamer stays the fallback.
const (
	mediaFFmpeg    = "ffmpeg"
	mediaGStreamer = "gstreamer"
	ffmpegPlugin   = "multimedia/libffmpegmediaplugin.so"
)

// mediaPluginDirs are the Qt plugin folders Quickshell may load from:
// QT_PLUGIN_PATH, the Nix package env (its Quickshell wrapper prepends it),
// and the distribution defaults.
func mediaPluginDirs(getenv func(string) string) []string {
	var dirs []string
	for _, d := range strings.Split(getenv("QT_PLUGIN_PATH"), ":") {
		if d != "" {
			dirs = append(dirs, d)
		}
	}
	if env := getenv(brand.EnvPrefix + "NIX_ENV"); env != "" {
		dirs = append(dirs, filepath.Join(env, "lib/qt-6/plugins"))
	}
	return append(dirs,
		"/usr/lib/qt6/plugins",
		"/usr/lib64/qt6/plugins",
		"/usr/lib/x86_64-linux-gnu/qt6/plugins",
		"/usr/lib/aarch64-linux-gnu/qt6/plugins",
		"/run/current-system/sw/lib/qt-6/plugins",
	)
}

// mediaBackend is the QT_MEDIA_BACKEND value to give Quickshell, "" to keep
// the one the user set.
func mediaBackend(getenv func(string) string, exists func(string) bool) string {
	if getenv("QT_MEDIA_BACKEND") != "" {
		return ""
	}
	for _, d := range mediaPluginDirs(getenv) {
		if exists(filepath.Join(d, ffmpegPlugin)) {
			return mediaFFmpeg
		}
	}
	return mediaGStreamer
}

func pathExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
