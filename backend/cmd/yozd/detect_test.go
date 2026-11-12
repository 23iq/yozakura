package main

import (
	"os"
	"path/filepath"
	"testing"

	"yozakura/backend/pkg/yozd/client"
)

func clearCompositorEnv(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", dir)
	for _, v := range []string{"HYPRLAND_INSTANCE_SIGNATURE", "MANGO_INSTANCE_SIGNATURE", "NIRI_SOCKET"} {
		t.Setenv(v, "")
	}
	return dir
}

// No compositor named anywhere (a sway or GNOME session): the slow
// "no compositor" status.
func TestDetectFailureStatusNoCompositor(t *testing.T) {
	clearCompositorEnv(t)
	if got := detectFailureStatus(); got != client.ExitNoCompositor {
		t.Fatalf("status %d, want %d", got, client.ExitNoCompositor)
	}
}

// A compositor that is indicated but could not be reached (MangoWC's IPC
// socket not accepting yet) is an ordinary failure: fast restarts.
func TestDetectFailureStatusIndicatedButUnreachable(t *testing.T) {
	for _, v := range []string{"HYPRLAND_INSTANCE_SIGNATURE", "MANGO_INSTANCE_SIGNATURE", "NIRI_SOCKET"} {
		t.Run(v, func(t *testing.T) {
			clearCompositorEnv(t)
			t.Setenv(v, "sig")
			if got := detectFailureStatus(); got == client.ExitNoCompositor || got == 0 {
				t.Fatalf("status %d, want an ordinary failure", got)
			}
		})
	}
	t.Run("niri socket in runtime dir", func(t *testing.T) {
		dir := clearCompositorEnv(t)
		if err := os.WriteFile(filepath.Join(dir, "niri.wayland-1.42.sock"), nil, 0o600); err != nil {
			t.Fatal(err)
		}
		if got := detectFailureStatus(); got == client.ExitNoCompositor || got == 0 {
			t.Fatalf("status %d, want an ordinary failure", got)
		}
	})
}
