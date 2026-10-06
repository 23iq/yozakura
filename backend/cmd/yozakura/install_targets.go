package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/fsutil"
	"yozakura/backend/pkg/migrate"
	"yozakura/backend/pkg/exclusive"
	"yozakura/backend/pkg/paths"
)

func runInstall(targets []string) {
	if installFlagsUsed(targets) {
		os.Exit(runExclusiveInstall(targets, defaultExclusiveEnv(), os.Stdout, os.Stderr))
	}
	target := ""
	if len(targets) > 0 {
		target = targets[0]
	}
	switch target {
	case "hyprland":
		installHyprland()
	case "niri":
		installSimpleTarget(niriConfig)
	case "mango":
		installSimpleTarget(mangoConfig)
	default:
		fmt.Printf("Error: Unknown target '%s'. Supported: hyprland, niri, mango\n", target)
		os.Exit(1)
	}
}

func runRemove(targets []string) {
	target := ""
	if len(targets) > 0 {
		target = targets[0]
	}
	switch target {
	case "hyprland":
		removeHyprland()
	case "niri":
		removeSimpleTarget(niriConfig)
	case "mango":
		removeSimpleTarget(mangoConfig)
	default:
		fmt.Printf("Error: Unknown target '%s'. Supported: hyprland, niri, mango\n", target)
		os.Exit(1)
	}
}

// Block detection markers — the first line of each block ("<comment> <Name>")
// is the stable identity used for both append detection and removal. Using
// the inner content (e.g. the loadfile(...)() line, or the include/source
// path) was fragile: if the user edited the inner path, the next run of
// `install <target>` would not match the marker and would re-append the
// entire block, producing duplicate imports.
//
// Blocks written by the legacy app (same layout, legacy name and data dir)
// are upgraded in place by upgradeLegacyBlock, so user overrides that follow
// the block keep loading after it.
func blockMarker(comment string) string { return brand.ConfigBlockMarker(comment) }

func overridesNote(comment, keyword string) string {
	return brand.ConfigOverridesNote(comment, keyword)
}

func dataRel() string { return brand.DataRel() }

func hyprConfBlock() string { return brand.HyprConfBlock() }

func hyprLuaBlock() string { return brand.HyprLuaBlock() }

// simpleTarget describes a compositor whose integration is a single
// include/source line in one config file. Hyprland is the exception with
// both .conf and .lua sides.
type simpleTarget struct {
	name    string
	relDir  string // under ~/.config
	relFile string // config file path under relDir
	line    string // include/source line, relative to the data dir
	header  string // language-specific comment marker for the block
}

var niriConfig = simpleTarget{name: "Niri", relDir: "niri", relFile: "config.kdl", line: `include "~%sniri.kdl"`, header: "//"}

var mangoConfig = simpleTarget{name: "Mango", relDir: "mango", relFile: "config.conf", line: `source = ~%smango.conf`, header: "#"}

func installHyprland() {
	home, _ := os.UserHomeDir()
	hyprDir := paths.HyprDir()
	os.MkdirAll(hyprDir, 0o755)
	luaPath := filepath.Join(hyprDir, "hyprland.lua")
	confPath := filepath.Join(hyprDir, "hyprland.conf")

	if isHomeManagerManaged(luaPath) || isHomeManagerManaged(confPath) {
		printHomeManagerHyprlandGuidance(luaPath, confPath)
		return
	}

	upgradeLegacyBlock(luaPath)
	upgradeLegacyBlock(confPath)
	repairHyprlandEntry(home, currentExecutable())
	if fileExists(luaPath) || !fileExists(confPath) {
		appendBlock(luaPath, blockMarker("--"), hyprLuaBlock())
	} else {
		appendBlock(confPath, blockMarker("#"), hyprConfBlock())
	}
}

func removeHyprland() {
	hyprDir := paths.HyprDir()
	luaPath := filepath.Join(hyprDir, "hyprland.lua")
	confPath := filepath.Join(hyprDir, "hyprland.conf")
	if isHomeManagerManaged(luaPath) || isHomeManagerManaged(confPath) {
		return
	}
	if exclusive.Active(hyprDir) {
		// the restore was declined: the entry is our minimal file, and
		// without the block it would load nothing at all
		fmt.Println("Exclusive mode is still active: " + hyprDir + " is left as is. Your previous config is in the backups under " + paths.New().DataDir + "/backups.")
		return
	}
	reportErr(removeBlock(luaPath, blockMarker("--"), luaLoadLine(), legacyLuaLoadLine()))
	reportErr(removeBlock(confPath, blockMarker("#"), strings.Split(hyprConfBlock(), "\n")[1]))
}

// isHomeManagerManaged returns true when path is a symlink whose target
// lives inside the Nix store, which is the home-manager pattern (HM places
// every managed file under <store-path>/home-manager-files/...). Writing
// through such a symlink fails with EACCES because the target is read-only.
//
// Readlink is preferred over EvalSymlinks here: it does not require the
// target to exist and returns the link text exactly as written by HM.
func isHomeManagerManaged(path string) bool {
	info, err := os.Lstat(path)
	if err != nil {
		return false
	}
	if info.Mode()&os.ModeSymlink == 0 {
		return false
	}
	target, err := os.Readlink(path)
	if err != nil {
		return false
	}
	return strings.HasPrefix(target, "/nix/store/")
}

func printHomeManagerHyprlandGuidance(luaPath, confPath string) {
	managed := luaPath
	if isHomeManagerManaged(confPath) {
		managed = confPath
	}
	fmt.Fprint(os.Stderr, branded(fmt.Sprintf(
		"{name}: %s is managed by home-manager (symlink into /nix/store).\n"+
			"{name} will not modify it directly. Add this to your home.nix instead:\n\n"+
			"  wayland.windowManager.hyprland.enable = false;\n"+
			"  xdg.configFile.\"hypr/hyprland.lua\".text = ''\n"+
			"    loadfile(os.getenv(\"HOME\") .. \"%shyprland.lua\")()\n\n"+
			"    -- OVERRIDES (hl.* API, Hyprland >=0.56)\n"+
			"    hl.config({ input = { kb_layout = \"latam\" } })\n"+
			"    hl.monitor({ output = \"\", mode = \"preferred\", scale = 1 })\n"+
			"    hl.bind(\"SUPER + Return\", hl.dsp.exec_cmd(\"kitty\"))\n"+
			"  '';\n\n"+
			"{name} regenerates ~%shyprland.lua on every\n"+
			"theme/gaps/binds change — no rebuild required for cosmetic tweaks.\n",
		managed, dataRel(), dataRel())))
}

func installSimpleTarget(t simpleTarget) {
	dir := filepath.Join(filepath.Dir(paths.New().ConfigDir), t.relDir)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		return
	}
	path := filepath.Join(dir, t.relFile)
	upgradeLegacyBlock(path)
	block := fmt.Sprintf("%s\n%s\n\n%s OVERRIDES\n%s\n",
		blockMarker(t.header), fmt.Sprintf(t.line, dataRel()), t.header, overridesNote(t.header, includeKeyword(t.name)))
	appendBlock(path, blockMarker(t.header), block)
	writeStartupBootstrap(t, currentExecutable())
}

func removeSimpleTarget(t simpleTarget) {
	path := filepath.Join(filepath.Dir(paths.New().ConfigDir), t.relDir, t.relFile)
	reportErr(removeBlock(path, blockMarker(t.header), fmt.Sprintf(t.line, dataRel())))
}

func includeKeyword(compositor string) string {
	if compositor == "Mango" {
		return "source"
	}
	return "include"
}

func appendBlock(path, marker, block string) {
	if fileExists(path) {
		data, err := os.ReadFile(path)
		if err == nil && containsLine(string(data), marker) {
			fmt.Printf("%s block already present in %s\n", brand.DisplayName, path)
			return
		}
	}
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		return
	}
	defer f.Close()
	info, _ := f.Stat()
	if info.Size() > 0 {
		fmt.Fprintf(f, "\n%s\n", block)
	} else {
		fmt.Fprintf(f, "%s\n", block)
	}
	fmt.Printf("Added %s block to %s\n", brand.DisplayName, path)
}

func reportErr(err error) {
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
	}
}

func containsLine(text, line string) bool {
	for _, l := range strings.Split(text, "\n") {
		if strings.TrimSuffix(l, "\r") == line {
			return true
		}
	}
	return false
}

// upgradeLegacyBlock upgrades a block written by the legacy app in place
// (see migrate.UpgradeLegacyBlock).
func upgradeLegacyBlock(path string) bool {
	changed, err := migrate.UpgradeLegacyBlock(path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		return false
	}
	if changed {
		fmt.Printf("Updated the old config block in %s (backup: %s.pre-%s)\n", path, path, brand.AppID)
	}
	return changed
}

// removeBlock drops the app's block (marker, include line, overrides note
// and the blank lines around them) from a compositor config. The original
// is kept as <path>.bak; the file is replaced atomically (through symlinks).
func removeBlock(path string, exact ...string) error {
	if !fileExists(path) {
		return nil
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	isRemove := func(line string) bool {
		trimmed := strings.TrimSuffix(line, "\r")
		for _, e := range exact {
			if strings.TrimSpace(trimmed) == e {
				return true
			}
		}
		for _, c := range []string{"#", "--", "//"} {
			if trimmed == blockMarker(c) || trimmed == c+" OVERRIDES" ||
				trimmed == overridesNote(c, "source") || trimmed == overridesNote(c, "include") {
				return true
			}
		}
		return false
	}

	lines := strings.Split(strings.TrimSuffix(string(data), "\n"), "\n")
	out := []string{}
	for i, line := range lines {
		next := ""
		if i+1 < len(lines) {
			next = lines[i+1]
		}
		prev := ""
		if i > 0 {
			prev = lines[i-1]
		}
		if isRemove(line) {
			continue
		}
		if line == "" && (isRemove(prev) || isRemove(next)) {
			continue
		}
		out = append(out, line)
	}
	if len(out) == len(lines) {
		return nil
	}
	if err := fsutil.WriteFile(path+".bak", data, 0o644); err != nil {
		return fmt.Errorf("backup %s.bak: %w", path, err)
	}
	if err := fsutil.WriteFile(path, []byte(strings.Join(out, "\n")+"\n"), 0o644); err != nil {
		return err
	}
	fmt.Printf("Removed %s block from %s (backup: %s.bak)\n", brand.DisplayName, path, path)
	return nil
}
