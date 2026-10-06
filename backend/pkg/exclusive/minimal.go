package exclusive

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/brand"
)

const (
	luaEntry  = "hyprland.lua"
	confEntry = "hyprland.conf"
)

// exclusiveMarker is the first line of the minimal entry; its presence is
// what makes exclusive mode active.
func exclusiveMarker(comment string) string {
	return brand.ConfigBlockMarker(comment) + " exclusive mode"
}

// entryName picks the entry Hyprland loads: hyprland.lua when present (as
// the installer does), else hyprland.conf.
func entryName(hypr string) string {
	if _, err := os.Lstat(filepath.Join(hypr, luaEntry)); err == nil {
		return luaEntry
	}
	return confEntry
}

// activeEntry returns the entry file that starts with the exclusive
// marker, or "".
func activeEntry(hypr string) string {
	for name, c := range map[string]string{luaEntry: "--", confEntry: "#"} {
		data, err := os.ReadFile(filepath.Join(hypr, name))
		if err != nil {
			continue
		}
		first, _, _ := strings.Cut(string(data), "\n")
		if strings.TrimSpace(first) == exclusiveMarker(c) {
			return name
		}
	}
	return ""
}

// checkManaged refuses a hypr dir or entry file that links into /nix/store
// (home-manager) and a hypr dir that is itself a symlink.
func checkManaged(hypr string) error {
	for _, p := range []string{hypr, filepath.Join(hypr, luaEntry), filepath.Join(hypr, confEntry)} {
		if intoNixStore(p) {
			return ErrHomeManager
		}
	}
	if info, err := os.Lstat(hypr); err == nil && info.Mode()&os.ModeSymlink != 0 {
		return ErrLinkedDir
	}
	return nil
}

func intoNixStore(p string) bool {
	info, err := os.Lstat(p)
	if err != nil || info.Mode()&os.ModeSymlink == 0 {
		return false
	}
	if target, err := os.Readlink(p); err == nil && strings.HasPrefix(target, "/nix/store/") {
		return true
	}
	real, err := filepath.EvalSymlinks(p)
	return err == nil && strings.HasPrefix(real, "/nix/store/")
}

func minimalEntry(lua bool, backup string) string {
	c, block, user := "#", brand.HyprConfBlock(), "source = ~/.config/hypr/user.conf"
	if lua {
		c, block = "--", brand.HyprLuaBlock()
		user = `local user = loadfile(os.getenv("HOME") .. "/.config/hypr/user.lua") if user then user() end`
	}
	cmd := brand.Command("exclusive", "restore")
	return strings.Join([]string{
		exclusiveMarker(c),
		fmt.Sprintf("%s This file was replaced by %s's exclusive mode. Your previous config is", c, brand.DisplayName),
		fmt.Sprintf("%s backed up in %s; `%s` brings it back.", c, backup, cmd),
		"",
		strings.TrimSuffix(block, "\n"),
		user,
		"",
	}, "\n")
}

func userNote(lua bool) string {
	c, ext := "#", "conf"
	if lua {
		c, ext = "--", "lua"
	}
	return fmt.Sprintf("%s user.%s: your personal Hyprland tweaks. It is loaded after %s's\n"+
		"%s generated config, so anything set here overrides it.\n", c, ext, brand.DisplayName, c)
}

// writeMinimal replaces the entry with the minimal one (the old entry, a
// file or a symlink, is in the backup; a symlink is replaced, never written
// through) and creates an empty user file unless one exists.
func writeMinimal(hypr, entry, backup string) error {
	lua := entry == luaEntry
	if err := os.MkdirAll(hypr, 0o755); err != nil {
		return err
	}
	user := filepath.Join(hypr, "user.conf")
	if lua {
		user = filepath.Join(hypr, "user.lua")
	}
	if _, err := os.Lstat(user); os.IsNotExist(err) {
		if err := writeFileSync(user, []byte(userNote(lua)), 0o644); err != nil {
			return fmt.Errorf("write %s: %w", user, err)
		}
	}
	if err := replaceFile(filepath.Join(hypr, entry), []byte(minimalEntry(lua, backup)), 0o644); err != nil {
		return fmt.Errorf("write %s: %w", entry, err)
	}
	return nil
}

// Active reports whether hypr (a ~/.config/hypr dir) carries the exclusive
// mode entry.
func Active(hypr string) bool { return activeEntry(hypr) != "" }
