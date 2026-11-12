package main

import (
	"os"
	"path/filepath"

	"yozakura/backend/pkg/yozd/client"
)

// detectFailureStatus is the exit status of `daemon` when every compositor
// probe failed. client.ExitNoCompositor (the supervisor then retries
// slowly) only when the session indicates no supported compositor at all;
// one that is indicated but could not be reached (MangoWC's IPC socket not
// accepting yet at login, a failed probe query) is an ordinary failure, so
// the fast restart backoff applies.
func detectFailureStatus() int {
	if compositorIndicated() {
		return 1
	}
	return client.ExitNoCompositor
}

// compositorIndicated reports whether the environment names a supported
// compositor: the variables the probes read, or the niri socket the niri
// probe would find without NIRI_SOCKET.
func compositorIndicated() bool {
	for _, v := range []string{"HYPRLAND_INSTANCE_SIGNATURE", "MANGO_INSTANCE_SIGNATURE", "NIRI_SOCKET"} {
		if os.Getenv(v) != "" {
			return true
		}
	}
	matches, err := filepath.Glob(filepath.Join(os.Getenv("XDG_RUNTIME_DIR"), "niri*.sock"))
	return err == nil && len(matches) > 0
}
