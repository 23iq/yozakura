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

// minimalEntry is the whole entry file of exclusive mode: the generated
// config, then the user file from hypr. polkit starts the polkit agent
// (the generated config starts one only off Hyprland, where the installer
// added it to the user's own entry, which this file replaces); "" when none
// is installed.
func minimalEntry(lua bool, backup, hypr, polkit string) string {
	c, block := "#", brand.HyprConfBlock()
	user := "source = " + filepath.Join(hypr, "user.conf")
	if lua {
		c, block = "--", brand.HyprLuaBlock()
		user = fmt.Sprintf("local user = loadfile(%q) if user then user() end", filepath.Join(hypr, "user.lua"))
	}
	cmd := brand.Command("install", "--restore")
	lines := []string{
		exclusiveMarker(c),
		fmt.Sprintf("%s This file was replaced by %s's exclusive mode. Your previous config is", c, brand.DisplayName),
		fmt.Sprintf("%s backed up in %s; `%s` brings it back.", c, backup, cmd),
		"",
		strings.TrimSuffix(block, "\n"),
	}
	if polkit != "" {
		lines = append(lines, polkitStart(lua, polkit))
	}
	return strings.Join(append(lines, user, ""), "\n")
}

// polkitStart is the minimal entry's line that runs the polkit command (an
// sh command line).
func polkitStart(lua bool, polkit string) string {
	if lua {
		return fmt.Sprintf("hl.on(\"hyprland.start\", function() hl.exec_cmd(%q) end)", polkit)
	}
	// hyprlang: # starts a comment unless doubled
	return "exec-once = " + strings.ReplaceAll(polkit, "#", "##")
}

// UpdatePolkit brings the polkit line of the active exclusive entry in hypr
// up to date: a line that is exactly the one this package wrote for one of
// the commands in old becomes the line for polkit. The entry is generated
// (the user's tweaks live in user.conf / user.lua), but only a regular file
// is rewritten, never a symlink (Home Manager), and an edited line stays.
// Reports whether it wrote.
func UpdatePolkit(hypr string, old []string, polkit string) (bool, error) {
	entry := activeEntry(hypr)
	if entry == "" || polkit == "" {
		return false, nil
	}
	path := filepath.Join(hypr, entry)
	if info, err := os.Lstat(path); err != nil || !info.Mode().IsRegular() {
		return false, nil
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return false, nil
	}
	lua := entry == luaEntry
	stale := map[string]bool{}
	for _, o := range old {
		if o != "" && o != polkit {
			stale[polkitStart(lua, o)] = true
		}
	}
	lines := strings.Split(string(data), "\n")
	n := 0
	for i, l := range lines {
		body := strings.TrimSuffix(l, "\r")
		if stale[body] {
			lines[i] = polkitStart(lua, polkit) + l[len(body):]
			n++
		}
	}
	if n == 0 {
		return false, nil
	}
	info, _ := os.Stat(path)
	return true, replaceFile(path, []byte(strings.Join(lines, "\n")), info.Mode().Perm())
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
func writeMinimal(hypr, entry, backup, polkit string) error {
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
	if err := replaceFile(filepath.Join(hypr, entry), []byte(minimalEntry(lua, backup, hypr, polkit)), 0o644); err != nil {
		return fmt.Errorf("write %s: %w", entry, err)
	}
	return nil
}

// Active reports whether hypr (a ~/.config/hypr dir) carries the exclusive
// mode entry.
func Active(hypr string) bool { return activeEntry(hypr) != "" }
