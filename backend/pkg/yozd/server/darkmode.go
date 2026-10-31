package server

import (
	"context"
	"fmt"
	"strings"

	"yozakura/backend/pkg/proc"
)

func preferredColorScheme() (string, error) {
	out, err := proc.Run(context.Background(), "gsettings", "get", "org.gnome.desktop.interface", "color-scheme")
	if err != nil {
		return "", fmt.Errorf("gsettings get failed: %v", err)
	}
	return strings.Trim(strings.TrimSpace(string(out)), "'"), nil
}

func IsDarkMode() (bool, error) {
	scheme, err := preferredColorScheme()
	if err != nil {
		return false, err
	}
	return scheme == "prefer-dark", nil
}

func SetDarkMode(on bool) error {
	scheme := "prefer-light"
	if on {
		scheme = "prefer-dark"
	}
	if err := proc.Do(context.Background(), "gsettings", "set", "org.gnome.desktop.interface", "color-scheme", scheme); err != nil {
		return fmt.Errorf("gsettings set failed: %v", err)
	}
	return nil
}
