package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"syscall"
	"yozakura/backend/pkg/brand"
)

func isSocketUp() bool {
	_, err := os.Stat(socketPath())
	return err == nil || isPipe(socketPath()) || isUnixSocket(socketPath())
}

func isPipe(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return info.Mode()&os.ModeNamedPipe != 0
}

func isUnixSocket(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return info.Mode()&os.ModeSocket != 0
}

// detachAttr returns process attributes for full detach.
func detachAttr() *syscall.SysProcAttr {
	return &syscall.SysProcAttr{Setsid: true}
}

// The shell source has just changed, so an existing generation was composed
// from the previous one and Yozakura would start without it. Re-compose here
// instead of leaving the user on the clean base until they open Settings.
func rebuildModsAfterUpdate() {
	status, err := callMods("status", nil)
	if err != nil {
		return
	}
	enabled := false
	for _, mod := range status.Mods {
		if mod.Enabled {
			enabled = true
			break
		}
	}
	if !enabled {
		return
	}
	fmt.Println("Rebuilding mods for the new " + brand.DisplayName + " version...")
	rebuilt, err := callMods("rebuild", nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Warning: mods were not rebuilt: %v\n", err)
		fmt.Fprintln(os.Stderr, brand.DisplayName+" starts without them. Settings > Mods can retry the build.")
		return
	}
	for _, mod := range rebuilt.Mods {
		if !mod.Compatible {
			fmt.Printf("  %s is not compatible with this version: %s\n", mod.ID, mod.CompatibilityError)
			continue
		}
		if mod.Untested {
			fmt.Printf("  %s: %s\n", mod.ID, mod.UntestedMessage)
		}
	}
	fmt.Println("Mods rebuilt.")
}

func runRefresh() {
	fmt.Println("Refreshing " + brand.DisplayName + " profile...")
	name := brand.AppID
	if out, err := exec.Command("nix", "profile", "list", "--json").Output(); err == nil {
		if found := profileElement(out); found != "" {
			name = found
		}
	}
	execCommand("nix", "profile", "upgrade", name, "--refresh", "--impure")
}

// profileElement finds the nix profile entry holding the app in `nix
// profile list --json` output: its name comes from the flake URL, so it is
// matched by the store path (/nix/store/<hash>-<app id>-<version>).
func profileElement(listJSON []byte) string {
	var list struct {
		Elements map[string]struct {
			StorePaths []string `json:"storePaths"`
		} `json:"elements"`
	}
	if json.Unmarshal(listJSON, &list) != nil {
		return ""
	}
	if _, ok := list.Elements[brand.AppID]; ok {
		return brand.AppID
	}
	names := make([]string, 0, len(list.Elements))
	for name := range list.Elements {
		names = append(names, name)
	}
	sort.Strings(names)
	for _, name := range names {
		for _, p := range list.Elements[name].StorePaths {
			base := strings.ToLower(filepath.Base(p))
			// <app id>-<version>: not -backend, -env or -sddm-theme
			_, rest, _ := strings.Cut(base, "-")
			if v, ok := strings.CutPrefix(rest, brand.AppID+"-"); ok && v != "" && v[0] >= '0' && v[0] <= '9' {
				return name
			}
		}
	}
	return ""
}

func runShellScript(script string, args ...string) (string, error) {
	out, err := exec.Command("bash", append([]string{script}, args...)...).Output()
	return strings.TrimSpace(string(out)), err
}

func doSuspend() {
	if _, err := exec.LookPath("systemctl"); err == nil {
		exec.Command("systemctl", "suspend").Run()
	} else if _, err := exec.LookPath("loginctl"); err == nil {
		exec.Command("loginctl", "suspend").Run()
	} else {
		exec.Command("dbus-send", "--system", "--print-reply",
			"--dest=org.freedesktop.login1", "/org/freedesktop/login1",
			"org.freedesktop.login1.Manager.Suspend", "boolean:true").Run()
	}
}
