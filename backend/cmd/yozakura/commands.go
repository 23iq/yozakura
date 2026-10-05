package main

import (
	"fmt"
	"os"
	"os/exec"
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
	execCommand("nix", "profile", "upgrade", brand.AppID, "--refresh", "--impure")
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
