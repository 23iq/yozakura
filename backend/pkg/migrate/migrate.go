// Package migrate moves a legacy (Ambxst) install over to the current app
// identity on first start.
//
// Rules: it runs only when the new config dir is missing and the legacy one
// exists. Config, data, state, cache and notes are copied (never moved);
// large dirs (python venv, depth models, whisper build) are symlinked;
// compositor configs and mod generations are regenerated instead of copied.
// Known references inside the copies (action ids, CLI commands, legacy dirs,
// the display name) are rewritten. The legacy dirs are never modified, so
// the old binary keeps working as a rollback.
//
// Afterwards the user's own files that point at the legacy install (kitty
// include, Hyprland source/exec lines, hypridle, nvim palette path) are
// rewritten, each original saved as <file>.pre-<app>. The Hyprland entry
// file is only switched once the new generated config exists (see
// FinishPending), so Hyprland never reloads into a missing file.
//
// Everything is logged to <data dir>/MarkerFile as JSON.
package migrate

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/paths"
)

// MarkerFile is written into the new data dir once migration ran.
var MarkerFile = "migrated-from-" + brand.LegacyAppID

// Legacy names the dirs of the install being migrated. Empty fields are
// skipped.
type Legacy struct {
	ConfigDir string
	DataDir   string
	StateDir  string
	CacheDir  string
	NotesDir  string
}

// DefaultLegacy resolves the legacy dirs with the same XDG rules the app
// uses for its own.
func DefaultLegacy() Legacy {
	xdg := func(env, def string) string {
		if v := os.Getenv(env); v != "" {
			return v
		}
		home, _ := os.UserHomeDir()
		return filepath.Join(home, def)
	}
	data := xdg("XDG_DATA_HOME", ".local/share")
	return Legacy{
		ConfigDir: filepath.Join(xdg("XDG_CONFIG_HOME", ".config"), brand.LegacyAppID),
		DataDir:   filepath.Join(data, brand.LegacyAppID),
		StateDir:  filepath.Join(xdg("XDG_STATE_HOME", ".local/state"), brand.LegacyAppID),
		CacheDir:  filepath.Join(xdg("XDG_CACHE_HOME", ".cache"), brand.LegacyAppID),
		NotesDir:  filepath.Join(data, brand.LegacyAppID+"-notes"),
	}
}

// Result summarises one Run.
type Result struct {
	Migrated  bool
	Skipped   string   // why nothing was migrated
	Copied    []string // top-level entries copied per dir
	Linked    []string // symlinks created (new -> legacy)
	Rewritten []string // copied files whose references were rewritten
	UserFiles []string // user files rewritten (backup: <file>.pre-<app>)
	Pending   []string // user files waiting for the generated config
	Notes     []string // manual follow-ups
}

// Log is the JSON content of MarkerFile.
type Log struct {
	Time      string            `json:"time"`
	From      map[string]string `json:"from"`
	To        map[string]string `json:"to"`
	Copied    []string          `json:"copied"`
	Linked    []string          `json:"linked"`
	Rewritten []string          `json:"rewritten"`
	UserFiles []string          `json:"userFiles"`
	Pending   []string          `json:"pending"`
	Notes     []string          `json:"notes"`
}

// Run migrates l into p (see the package doc). It is a no-op when p's
// config dir already exists or there is no legacy config.
func Run(p paths.Paths, l Legacy) (Result, error) {
	return runWithHome(p, l, homeOf(l.ConfigDir))
}

// homeOf returns the home dir a config dir lives in (<home>/.config/<id>),
// falling back to the user's home for a custom XDG_CONFIG_HOME. Deriving it
// keeps tests (and other roots) from ever touching the real home.
func homeOf(configDir string) string {
	if parent := filepath.Dir(configDir); filepath.Base(parent) == ".config" {
		return filepath.Dir(parent)
	}
	home, _ := os.UserHomeDir()
	return home
}

// resolveLegacy follows symlinks of the legacy roots (missing ones stay).
func resolveLegacy(l Legacy) Legacy {
	for _, dir := range []*string{&l.ConfigDir, &l.DataDir, &l.StateDir, &l.CacheDir, &l.NotesDir} {
		if *dir == "" {
			continue
		}
		if real, err := filepath.EvalSymlinks(*dir); err == nil {
			*dir = real
		}
	}
	return l
}

func runWithHome(p paths.Paths, l Legacy, home string) (Result, error) {
	var res Result
	if p.ConfigDir == "" || l.ConfigDir == "" || p.ConfigDir == l.ConfigDir {
		res.Skipped = "no distinct legacy config dir"
		return res, nil
	}
	if exists(p.ConfigDir) {
		res.Skipped = "config dir already exists: " + p.ConfigDir
		return res, nil
	}
	if !isDir(l.ConfigDir) {
		res.Skipped = "no legacy config at " + l.ConfigDir
		return res, nil
	}
	// Copy from the real dirs: a symlinked legacy root (dotfiles) would be
	// recreated as a link, so the new dirs would point at — and the rewrite
	// would modify — the legacy files.
	l = resolveLegacy(l)
	log.Printf("[migrate] migrating %s settings from %s", brand.LegacyName, l.ConfigDir)

	// Config goes through a staging dir: an interrupted copy never leaves a
	// half-filled config dir that would block the next attempt.
	staging := p.ConfigDir + ".migrating"
	_ = os.RemoveAll(staging)
	if err := copyTree(l.ConfigDir, staging, nil); err != nil {
		return res, fmt.Errorf("copy config: %w", err)
	}
	rewritten, err := rewriteTree(staging, configRules(), func(string) bool { return true })
	if err != nil {
		return res, fmt.Errorf("rewrite config: %w", err)
	}
	for _, f := range rewritten {
		res.Rewritten = append(res.Rewritten, filepath.Join(p.ConfigDir, f))
	}
	if renamed, err := renameBindsRoot(filepath.Join(staging, "binds.json")); err != nil {
		res.Notes = append(res.Notes, "binds.json: "+err.Error())
	} else if renamed {
		res.Rewritten = append(res.Rewritten, filepath.Join(p.ConfigDir, "binds.json")+" (core binds root)")
	}
	// A migrated install is an existing setup: never show the first-run wizard.
	if _, err := MarkOnboardingDone(filepath.Join(staging, "config", "general.json"), true, true); err != nil {
		res.Notes = append(res.Notes, "general.json: "+err.Error())
	}
	res.Copied = append(res.Copied, l.ConfigDir+" -> "+p.ConfigDir)

	if l.DataDir != "" && p.DataDir != "" && isDir(l.DataDir) {
		if err := migrateData(p, l, &res); err != nil {
			return res, err
		}
	}
	for _, d := range [][2]string{{l.StateDir, p.StateDir}, {l.CacheDir, p.CacheDir}, {l.NotesDir, notesDir(p)}} {
		if d[0] == "" || d[1] == "" || !isDir(d[0]) {
			continue
		}
		if err := copyTree(d[0], d[1], skipLegacyNamed); err != nil {
			return res, fmt.Errorf("copy %s: %w", d[0], err)
		}
		res.Copied = append(res.Copied, d[0]+" -> "+d[1])
		files, err := rewriteTree(d[1], pathRules(), isJSON)
		if err != nil {
			return res, err
		}
		for _, f := range files {
			res.Rewritten = append(res.Rewritten, filepath.Join(d[1], f))
		}
	}

	if err := os.Rename(staging, p.ConfigDir); err != nil {
		return res, fmt.Errorf("activate config: %w", err)
	}
	res.Migrated = true

	user, pending, err := rewriteUserFiles(home, cacheFrag(p), dataFrag(p), p.DataDir)
	if err != nil {
		res.Notes = append(res.Notes, "user files: "+err.Error())
	}
	res.UserFiles, res.Pending = user, pending
	res.Notes = append(res.Notes, manualNotes(home)...)

	if err := writeLog(p, l, res); err != nil {
		return res, err
	}
	for _, f := range res.UserFiles {
		log.Printf("[migrate] rewrote %s (backup %s)", f, f+backupSuffix())
	}
	for _, f := range res.Pending {
		log.Printf("[migrate] %s switches once the new compositor config is generated", f)
	}
	log.Printf("[migrate] done; log in %s", filepath.Join(p.DataDir, MarkerFile))
	return res, nil
}

// FinishPending rewrites the user files Run deferred (the Hyprland entry
// file) once the generated config they point at exists. Safe to call on
// every start: it does nothing without a marker or pending entries.
func FinishPending(p paths.Paths) ([]string, error) {
	return finishPendingWithHome(p, homeOf(p.ConfigDir))
}

func finishPendingWithHome(p paths.Paths, home string) ([]string, error) {
	marker := filepath.Join(p.DataDir, MarkerFile)
	data, err := os.ReadFile(marker)
	if err != nil {
		return nil, nil
	}
	var lg Log
	if err := json.Unmarshal(data, &lg); err != nil || len(lg.Pending) == 0 {
		return nil, nil
	}
	var done, still []string
	for _, f := range lg.Pending {
		if !entryTargetExists(f, p.DataDir) {
			still = append(still, f)
			continue
		}
		changed, err := rewriteUserFile(f, rulesFor(home, f, userRules(cacheFrag(p), dataFrag(p))), true)
		if err != nil {
			still = append(still, f)
			continue
		}
		if changed {
			done = append(done, f)
			lg.UserFiles = append(lg.UserFiles, f)
			log.Printf("[migrate] rewrote %s (backup %s)", f, f+backupSuffix())
		}
	}
	if len(done) == 0 && len(still) == len(lg.Pending) {
		return nil, nil
	}
	lg.Pending = still
	out, _ := json.MarshalIndent(lg, "", "  ")
	return done, os.WriteFile(marker, append(out, '\n'), 0o644)
}

// renameBindsRoot moves the core binds from the legacy root key of
// binds.json to the current one and drops the serialized legacy defaults.
// The shell does the same on load (Config.qml repairKeybinds); doing it here
// keeps the very first start from showing default binds.
func renameBindsRoot(path string) (bool, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return false, nil
	}
	var root map[string]json.RawMessage
	if err := json.Unmarshal(data, &root); err != nil {
		return false, err
	}
	changed := false
	if legacy, ok := root[brand.LegacyAppID]; ok {
		if _, has := root[brand.AppID]; !has {
			root[brand.AppID] = legacy
		}
		delete(root, brand.LegacyAppID)
		changed = true
	}
	if _, ok := root["default"+brand.LegacyName+"Binds"]; ok {
		delete(root, "default"+brand.LegacyName+"Binds")
		changed = true
	}
	if !changed {
		return false, nil
	}
	var buf strings.Builder
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false) // keep shell commands ("> pipe", "&&") readable
	enc.SetIndent("", "  ")
	if err := enc.Encode(root); err != nil {
		return false, err
	}
	return true, os.WriteFile(path, []byte(buf.String()), 0o644)
}

// --- data dir --------------------------------------------------------------

// linkedDataDirs are large and position-dependent (venvs embed absolute
// paths): the new data dir points at them instead of copying.
var linkedDataDirs = []string{"venv-depth", "depth-models", "whisper"}

// generatedData are rewritten by the backend/axctl on start.
var generatedData = regexp.MustCompile(`^(hyprland.*\.(lua|conf)|axctl\.toml|niri\.kdl|mango\.conf)$`)

func migrateData(p paths.Paths, l Legacy, res *Result) error {
	skip := func(rel string, d fs.DirEntry) bool {
		top := strings.SplitN(rel, string(filepath.Separator), 2)[0]
		for _, name := range linkedDataDirs {
			if top == name {
				return true
			}
		}
		if rel == filepath.Join("mods", "generations") || rel == filepath.Join("mods", "pending-activation.json") {
			return true
		}
		if !strings.Contains(rel, string(filepath.Separator)) && !d.IsDir() && generatedData.MatchString(rel) {
			return true
		}
		return rel == MarkerFile
	}
	if err := copyTree(l.DataDir, p.DataDir, skip); err != nil {
		return fmt.Errorf("copy data: %w", err)
	}
	res.Copied = append(res.Copied, l.DataDir+" -> "+p.DataDir)
	for _, name := range linkedDataDirs {
		src, dst := filepath.Join(l.DataDir, name), filepath.Join(p.DataDir, name)
		if !exists(src) || exists(dst) {
			continue
		}
		if err := os.Symlink(src, dst); err != nil {
			return fmt.Errorf("link %s: %w", name, err)
		}
		res.Linked = append(res.Linked, dst+" -> "+src)
	}
	files, err := rewriteTree(p.DataDir, pathRules(), isJSON)
	if err != nil {
		return err
	}
	for _, f := range files {
		res.Rewritten = append(res.Rewritten, filepath.Join(p.DataDir, f))
	}
	return nil
}

func notesDir(p paths.Paths) string {
	if p.DataDir == "" {
		return ""
	}
	return p.DataDir + "-notes"
}

// skipLegacyNamed drops generated files named after the legacy app (they are
// regenerated under the new name).
func skipLegacyNamed(rel string, d fs.DirEntry) bool {
	return !strings.Contains(rel, string(filepath.Separator)) && strings.Contains(d.Name(), brand.LegacyAppID)
}

// --- rewrite rules ---------------------------------------------------------

type rule struct {
	re   *regexp.Regexp
	repl string
}

var (
	legacy = regexp.QuoteMeta(brand.LegacyAppID)
	// Legacy XDG dirs inside a path: /.cache/ambxst/, $HOME/.config/ambxst" ...
	legacyDirRe = regexp.MustCompile(`(?m)/\.(cache|config|local/share|local/state)/` + legacy + `([/"'\s]|$)`)
	// The CLI as a command: "ambxst lock", `|| ambxst run x`, exec-once =
	// ambxst, exec_cmd("ambxst"). Not ambxst-polkit, ambxst.css,
	// /usr/bin/ambxst, ~/.local/src/ambxst, require("ambxst") in Lua
	// modules (not rewritten in nvim) or a JSON key "ambxst": {.
	cmdWordRe   = regexp.MustCompile("(?m)(^|[\\s\"'(=;&|`])" + legacy + "([ \\t]+[a-z+-])")
	cmdBareRe   = regexp.MustCompile("(?m)(^|[\\s(=;&|`])" + legacy + "([\\s;)&|]|$)")
	cmdQuotedRe = regexp.MustCompile(`(?m)(["'])` + legacy + `(["'])(\s*[,)\]}]|\s*$)`)
	actionRe    = regexp.MustCompile(`"` + legacy + `\.([\w-]+)"`)
	pipeRe      = regexp.MustCompile(legacy + `_ipc\.pipe`)
	nameRe      = regexp.MustCompile(`\b` + regexp.QuoteMeta(brand.LegacyName) + `\b`)
	pathRepl    = "/.$1/" + brand.AppID + "$2"
	actionRepl  = `"` + brand.AppID + `.$1"`
)

func pathRules() []rule {
	return []rule{{legacyDirRe, pathRepl}, {pipeRe, brand.AppID + "_ipc.pipe"}}
}

func configRules() []rule {
	return append(append(pathRules(),
		rule{actionRe, actionRepl},
		rule{nameRe, brand.DisplayName},
	), commandRules()...)
}

func commandRules() []rule {
	return []rule{
		{cmdWordRe, "${1}" + brand.AppID + "${2}"},
		{cmdBareRe, "${1}" + brand.AppID + "${2}"},
		{cmdQuotedRe, "${1}" + brand.AppID + "${2}${3}"},
	}
}

// userRules rewrite only what points at the legacy install: its dirs (to the
// given new cache/data fragments) and its pipe. Prose stays. Files that run
// commands (Hyprland) additionally get commandRules.
func userRules(newCache, newData string) []rule {
	// Accept "~/.cache/x" or "$HOME/.cache/x": only the fragment from "/."
	// on replaces the matched legacy fragment.
	for _, s := range []*string{&newCache, &newData} {
		if i := strings.Index(*s, "/."); i > 0 {
			*s = (*s)[i:]
		}
	}
	cache := regexp.MustCompile(`/\.cache/` + legacy + `([/"'\s]|$)`)
	data := regexp.MustCompile(`/\.local/share/` + legacy + `([/"'\s]|$)`)
	return []rule{
		{cache, newCache + "$1"},
		{data, newData + "$1"},
		{legacyDirRe, pathRepl},
		{pipeRe, brand.AppID + "_ipc.pipe"},
	}
}

// shellRCFiles are interactive shell configs (aliases, autostart lines).
var shellRCFiles = []string{".bashrc", ".zshrc", ".profile", ".bash_profile", ".zprofile"}

// rulesFor picks the user rules for a file: Hyprland configs and shell
// configs run the CLI, so their command lines are rewritten too; kitty and
// nvim only get paths (a Lua module named after the legacy app stays).
func rulesFor(home, path string, base []rule) []rule {
	runsCommands := false
	for _, dir := range []string{".config/hypr", ".config/fish"} {
		if strings.HasPrefix(path, filepath.Join(home, dir)+string(filepath.Separator)) {
			runsCommands = true
		}
	}
	for _, rc := range shellRCFiles {
		if path == filepath.Join(home, rc) {
			runsCommands = true
		}
	}
	if runsCommands {
		return append(append([]rule{}, base...), commandRules()...)
	}
	return base
}

// applyRules runs every rule until the text is stable (a command rule cannot
// match two adjacent occurrences in one pass).
func applyRules(text string, rules []rule) string {
	for i := 0; i < 4; i++ {
		before := text
		for _, r := range rules {
			text = r.re.ReplaceAllString(text, r.repl)
		}
		if text == before {
			break
		}
	}
	return text
}

func isJSON(rel string) bool { return strings.HasSuffix(rel, ".json") }

// rewriteTree applies rules to the text files under root accepted by want.
// Returns the changed files relative to root.
func rewriteTree(root string, rules []rule, want func(rel string) bool) ([]string, error) {
	var changed []string
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.Type()&fs.ModeSymlink != 0 || d.IsDir() {
			return nil
		}
		rel, _ := filepath.Rel(root, path)
		if !want(rel) {
			return nil
		}
		info, err := d.Info()
		if err != nil || info.Size() > 4<<20 {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil || isBinary(data) {
			return nil
		}
		out := applyRules(string(data), rules)
		if out == string(data) {
			return nil
		}
		changed = append(changed, rel)
		return os.WriteFile(path, []byte(out), info.Mode().Perm())
	})
	sort.Strings(changed)
	return changed, err
}

func isBinary(data []byte) bool {
	n := len(data)
	if n > 8192 {
		n = 8192
	}
	for _, b := range data[:n] {
		if b == 0 {
			return true
		}
	}
	return false
}

// --- user files ------------------------------------------------------------

func cacheFrag(p paths.Paths) string {
	if p.CacheDir == "" {
		return "/.cache/" + brand.AppID
	}
	return "/.cache/" + filepath.Base(p.CacheDir)
}

func dataFrag(p paths.Paths) string {
	if p.DataDir == "" {
		return "/.local/share/" + brand.AppID
	}
	return "/.local/share/" + filepath.Base(p.DataDir)
}

// rewriteUserReferences rewrites every known user file that points at the
// legacy install, including the Hyprland entry file. newCache and newData
// replace the legacy cache and data dir path fragments (e.g.
// "~/.cache/yozakura", "/.local/share/yozakura").
func rewriteUserReferences(home string, newCache, newData string) ([]string, error) {
	changed, _, err := rewriteUserFiles(home, newCache, newData, "")
	return changed, err
}

// rewriteUserFiles rewrites the user files; with a non-empty newDataDir the
// Hyprland entry files are deferred (returned as pending) until the
// generated config they will load exists there.
func rewriteUserFiles(home, newCache, newData, newDataDir string) (changed, pending []string, err error) {
	rules := userRules(newCache, newData)
	var errs []error
	for _, f := range userFileCandidates(home) {
		entry := isHyprEntry(home, f)
		fileRules := rulesFor(home, f, rules)
		if entry && newDataDir != "" && !entryTargetExists(f, newDataDir) {
			if needsRewrite(f, fileRules) {
				pending = append(pending, f)
			}
			continue
		}
		ok, err := rewriteUserFile(f, fileRules, entry)
		if err != nil {
			errs = append(errs, err)
			continue
		}
		if ok {
			changed = append(changed, f)
		}
	}
	return changed, pending, errors.Join(errs...)
}

// userFileCandidates lists the user's files that may point at the install:
// kitty config, every Hyprland lua/conf (entry, sourced files, hypridle,
// hyprlock) and the nvim config.
func userFileCandidates(home string) []string {
	var out []string
	add := func(root string, exts ...string) {
		filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return nil
			}
			if d.IsDir() {
				if strings.HasPrefix(d.Name(), ".") && path != root {
					return filepath.SkipDir
				}
				return nil
			}
			if d.Type()&fs.ModeSymlink != 0 || strings.Contains(d.Name(), ".pre-") {
				return nil
			}
			for _, ext := range exts {
				if strings.HasSuffix(d.Name(), ext) {
					out = append(out, path)
					break
				}
			}
			return nil
		})
	}
	add(filepath.Join(home, ".config/kitty"), ".conf")
	add(filepath.Join(home, ".config/hypr"), ".lua", ".conf")
	add(filepath.Join(home, ".config/nvim"), ".lua", ".vim")
	add(filepath.Join(home, ".config/fish"), ".fish")
	for _, rc := range shellRCFiles {
		if path := filepath.Join(home, rc); isRegular(path) {
			out = append(out, path)
		}
	}
	sort.Strings(out)
	return out
}

func isHyprEntry(home, path string) bool {
	dir := filepath.Join(home, ".config/hypr")
	return path == filepath.Join(dir, "hyprland.lua") || path == filepath.Join(dir, "hyprland.conf")
}

// entryTargetExists reports whether the generated file a Hyprland entry
// file loads (same name, new data dir) is there.
func entryTargetExists(entry, newDataDir string) bool {
	return exists(filepath.Join(newDataDir, filepath.Base(entry)))
}

func needsRewrite(path string, rules []rule) bool {
	data, err := os.ReadFile(path)
	return err == nil && applyRules(string(data), rules) != string(data)
}

func backupSuffix() string { return ".pre-" + brand.AppID }

// rewriteUserFile applies rules (and, for a Hyprland entry file, the block
// marker upgrade) and saves the original as <path>.pre-<app> first.
func rewriteUserFile(path string, rules []rule, entry bool) (bool, error) {
	info, err := os.Stat(path)
	if err != nil {
		return false, nil
	}
	data, err := os.ReadFile(path)
	if err != nil || isBinary(data) {
		return false, nil
	}
	out := applyRules(string(data), rules)
	if entry {
		out = upgradeMarkers(out)
	}
	if out == string(data) {
		return false, nil
	}
	backup := path + backupSuffix()
	if !exists(backup) {
		if err := os.WriteFile(backup, data, info.Mode().Perm()); err != nil {
			return false, fmt.Errorf("backup %s: %w", path, err)
		}
	}
	return true, os.WriteFile(path, []byte(out), info.Mode().Perm())
}

// --- install blocks --------------------------------------------------------

// upgradeMarkers renames the comment lines of an `install <target>` block
// written by the legacy app ("-- Ambxst", the overrides note).
func upgradeMarkers(text string) string {
	lines := strings.Split(text, "\n")
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		for _, c := range []string{"#", "--", "//"} {
			if trimmed == c+" "+brand.LegacyName {
				lines[i] = c + " " + brand.DisplayName
			}
			for _, kw := range []string{"source", "include"} {
				old := c + " Down here you can write or " + kw + " anything that you want to override from " + brand.LegacyName + "'s settings."
				if trimmed == old {
					lines[i] = c + " Down here you can write or " + kw + " anything that you want to override from " + brand.DisplayName + "'s settings."
				}
			}
		}
	}
	return strings.Join(lines, "\n")
}

// UpgradeLegacyBlock rewrites, in place, an `install <target>` block the
// legacy app wrote into a compositor config: marker, overrides note and
// every non-comment line pointing into the legacy data dir. Lines stay
// where they are, so user overrides after the block keep their order. The
// original is saved as <path>.pre-<app> before the first change.
func UpgradeLegacyBlock(path string) (bool, error) {
	if brand.LegacyAppID == brand.AppID {
		return false, nil
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return false, nil
	}
	legacyData := "/.local/share/" + brand.LegacyAppID + "/"
	newData := "/.local/share/" + brand.AppID + "/"
	lines := strings.Split(upgradeMarkers(string(data)), "\n")
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "#") || strings.HasPrefix(trimmed, "--") || strings.HasPrefix(trimmed, "//") {
			continue
		}
		lines[i] = strings.ReplaceAll(line, legacyData, newData)
	}
	out := strings.Join(lines, "\n")
	if out == string(data) {
		return false, nil
	}
	mode := os.FileMode(0o644)
	if info, err := os.Stat(path); err == nil {
		mode = info.Mode().Perm()
	}
	backup := path + backupSuffix()
	if !exists(backup) {
		if err := os.WriteFile(backup, data, mode); err != nil {
			return false, err
		}
	}
	return true, os.WriteFile(path, []byte(out), mode)
}

// --- notes and log ---------------------------------------------------------

// manualNotes lists what migration cannot do itself.
func manualNotes(home string) []string {
	notes := []string{
		fmt.Sprintf("Legacy dirs are kept for rollback (`%s quit && %s`); remove ~/.config/%s, ~/.local/share/%s, ~/.local/state/%s and ~/.cache/%s once you no longer need them.",
			brand.AppID, brand.LegacyAppID, brand.LegacyAppID, brand.LegacyAppID, brand.LegacyAppID, brand.LegacyAppID),
		fmt.Sprintf("Spotify (spicetify), Discord clients (enabledThemes) and Firefox (@import) switch to the %s theme automatically on the next palette apply.", brand.AppID),
		fmt.Sprintf("Telegram: open ~/.cache/%s/%s.tdesktop-theme once (Settings > Chat settings > Load theme); the old theme file is no longer updated.", brand.AppID, brand.AppID),
		fmt.Sprintf("SDDM: re-run `sudo scripts/install-sddm-theme.sh` to install the %s login theme (/var/lib/%s-sddm); it replaces the %s one.", brand.AppID, brand.AppID, brand.LegacyAppID),
	}
	var leftovers []string
	for _, pattern := range []string{
		".config/*/themes/" + brand.LegacyAppID + ".css",
		".config/spicetify/Themes/" + brand.LegacyAppID,
		".config/qt[56]ct/colors/" + brand.LegacyAppID + ".colors",
		".mozilla/firefox/*/chrome/" + brand.LegacyAppID + "*.css",
	} {
		matches, _ := filepath.Glob(filepath.Join(home, pattern))
		leftovers = append(leftovers, matches...)
	}
	if len(leftovers) > 0 {
		notes = append(notes, "Old generated theme files left in place (safe to delete after the switch): "+strings.Join(leftovers, ", "))
	}
	return notes
}

func writeLog(p paths.Paths, l Legacy, res Result) error {
	lg := Log{
		Time:      time.Now().Format(time.RFC3339),
		From:      map[string]string{"config": l.ConfigDir, "data": l.DataDir, "state": l.StateDir, "cache": l.CacheDir, "notes": l.NotesDir},
		To:        map[string]string{"config": p.ConfigDir, "data": p.DataDir, "state": p.StateDir, "cache": p.CacheDir, "notes": notesDir(p)},
		Copied:    res.Copied,
		Linked:    res.Linked,
		Rewritten: res.Rewritten,
		UserFiles: res.UserFiles,
		Pending:   res.Pending,
		Notes:     res.Notes,
	}
	if err := os.MkdirAll(p.DataDir, 0o755); err != nil {
		return err
	}
	out, _ := json.MarshalIndent(lg, "", "  ")
	return os.WriteFile(filepath.Join(p.DataDir, MarkerFile), append(out, '\n'), 0o644)
}

// --- fs helpers ------------------------------------------------------------

func exists(path string) bool {
	_, err := os.Lstat(path)
	return err == nil
}

func isRegular(path string) bool {
	info, err := os.Lstat(path)
	return err == nil && info.Mode().IsRegular()
}

func isDir(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

// copyTree copies src into dst (created as needed) without overwriting
// existing files. skip gets paths relative to src; a skipped dir is not
// descended. Symlinks are recreated as symlinks.
func copyTree(src, dst string, skip func(rel string, d fs.DirEntry) bool) error {
	return filepath.WalkDir(src, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(src, path)
		if rel != "." && skip != nil && skip(rel, d) {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		target := filepath.Join(dst, rel)
		info, err := os.Lstat(path)
		if err != nil {
			return err
		}
		switch {
		case info.IsDir():
			return os.MkdirAll(target, info.Mode().Perm()|0o700)
		case info.Mode()&fs.ModeSymlink != 0:
			if exists(target) {
				return nil
			}
			link, err := os.Readlink(path)
			if err != nil {
				return err
			}
			return os.Symlink(link, target)
		case info.Mode().IsRegular():
			if exists(target) {
				return nil
			}
			return copyFile(path, target, info.Mode().Perm())
		}
		return nil // sockets, fifos: runtime only
	})
}

func copyFile(src, dst string, mode os.FileMode) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	tmp := dst + ".tmp-migrate"
	out, err := os.OpenFile(tmp, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, mode)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		os.Remove(tmp)
		return err
	}
	if err := out.Close(); err != nil {
		os.Remove(tmp)
		return err
	}
	return os.Rename(tmp, dst)
}
