package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/presets"
)

// validMatugenSchemes are the matugen schemes the shell can generate a
// palette with (shared with presets, which carry the scheme). Kept
// server-side so `yozakura wallpaper -scheme X` can validate the input
// without having to talk to Quickshell first.
var validMatugenSchemes = presets.MatugenSchemes

// wallpaperUsage is the one-line usage of the wallpaper command.
var wallpaperUsage = "Usage: " + brand.AppID + " wallpaper <file> [-scheme <scheme>] [-oled] [-tint] [-monitor <id|name>]"

// runWallpaper implements `yozakura wallpaper <file> [-scheme ...] [-oled]
// [-tint] [-monitor ...]`. It resolves the file path, validates flags,
// then dispatches the request to the daemon via the wallpaper.set IPC
// method. The daemon broadcasts it to the QML side, which actually
// applies the change.
func runWallpaper(args []string) int {
	fs, err := parseWallpaperFlags(args)
	if err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		return 2
	}
	if !isAlive() {
		fmt.Fprintln(os.Stderr, "Error: "+brand.DisplayName+" is not running")
		return 1
	}

	abs, err := filepath.Abs(expandTilde(fs.path))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: invalid path: %v\n", err)
		return 1
	}
	if _, err := os.Stat(abs); err != nil {
		fmt.Fprintf(os.Stderr, "Error: wallpaper not found: %s\n", abs)
		return 1
	}

	params := map[string]any{"path": abs}
	if fs.scheme != "" {
		params["scheme"] = fs.scheme
	}
	if fs.oledSet {
		params["oled"] = fs.oled
	}
	if fs.tintSet {
		params["tint"] = fs.tint
	}
	if fs.monitor != "" {
		params["monitor"] = fs.monitor
	}

	res, err := newClient().Call("wallpaper.set", params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		return 1
	}
	if len(res) > 0 {
		fmt.Println(string(res))
	}
	fmt.Printf("Wallpaper set: %s\n", abs)
	return 0
}

type wallpaperFlags struct {
	path    string
	scheme  string
	oledSet bool
	oled    bool
	tintSet bool
	tint    bool
	monitor string
}

func parseWallpaperFlags(args []string) (*wallpaperFlags, error) {
	fs := &wallpaperFlags{}
	i := 0
	for i < len(args) {
		a := args[i]
		switch a {
		case "-scheme", "--scheme":
			if i+1 >= len(args) {
				return nil, errors.New(wallpaperUsage)
			}
			fs.scheme = args[i+1]
			if !isValidScheme(fs.scheme) {
				return nil, fmt.Errorf("Error: unknown scheme %q. Available: %s", fs.scheme, strings.Join(validMatugenSchemes, ", "))
			}
			i += 2
		case "-oled", "--oled":
			fs.oledSet = true
			fs.oled = true
			i++
		case "-tint", "--tint":
			fs.tintSet = true
			fs.tint = true
			i++
		case "-monitor", "--monitor", "-m":
			if i+1 >= len(args) {
				return nil, errors.New(wallpaperUsage)
			}
			fs.monitor = args[i+1]
			i += 2
		default:
			if strings.HasPrefix(a, "-") {
				return nil, fmt.Errorf("Error: unknown flag %s", a)
			}
			if fs.path != "" {
				return nil, fmt.Errorf("Error: multiple wallpaper paths provided (%s and %s)", fs.path, a)
			}
			fs.path = a
			i++
		}
	}
	if fs.path == "" {
		return nil, errors.New(wallpaperUsage)
	}
	return fs, nil
}

func isValidScheme(scheme string) bool {
	for _, s := range validMatugenSchemes {
		if s == scheme {
			return true
		}
	}
	return false
}
