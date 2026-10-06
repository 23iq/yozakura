package specials

import (
	"bufio"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// Entry is the part of an installed .desktop file a special's app needs.
type Entry struct {
	ID           string // desktop id without ".desktop"
	Name         string
	Icon         string
	Exec         string
	StartupClass string
}

// fieldCodes mirrors Specials.stripFieldCodes.
var fieldCodes = regexp.MustCompile(`\s*%[fFuUdDnNickvm]`)

// StripFieldCodes removes Exec field codes (%U, %f, ...); "%%" is "%".
func StripFieldCodes(exec string) string {
	s := strings.ReplaceAll(exec, "%%", "\x00")
	s = fieldCodes.ReplaceAllString(s, "")
	return strings.TrimSpace(strings.ReplaceAll(s, "\x00", "%"))
}

// App turns an entry into a special's app (class from StartupWMClass,
// else the desktop id).
func (e Entry) App() App {
	match := e.StartupClass
	if match == "" {
		match = e.ID
	}
	icon := e.Icon
	if icon == "" {
		icon = e.ID
	}
	name := e.Name
	if name == "" {
		name = e.ID
	}
	return App{ID: e.ID, Name: name, Icon: icon, Match: match, Command: StripFieldCodes(e.Exec), IfRunning: "nothing"}
}

// ApplicationDirs are the XDG application directories, user first.
func ApplicationDirs() []string {
	var dirs []string
	home := os.Getenv("XDG_DATA_HOME")
	if home == "" {
		if h, err := os.UserHomeDir(); err == nil {
			home = filepath.Join(h, ".local", "share")
		}
	}
	if home != "" {
		dirs = append(dirs, filepath.Join(home, "applications"))
	}
	data := os.Getenv("XDG_DATA_DIRS")
	if data == "" {
		data = "/usr/local/share:/usr/share"
	}
	seen := map[string]bool{}
	for _, d := range append([]string{""}, strings.Split(data, ":")...) {
		if d == "" {
			continue
		}
		p := filepath.Join(d, "applications")
		if !seen[p] {
			seen[p] = true
			dirs = append(dirs, p)
		}
	}
	return dirs
}

// Lookup finds an installed desktop entry by id (first dir wins).
func Lookup(dirs []string, id string) (Entry, bool) {
	id = strings.TrimSuffix(id, ".desktop")
	for _, d := range dirs {
		if e, ok := readEntry(filepath.Join(d, id+".desktop"), id); ok {
			return e, true
		}
	}
	return Entry{}, false
}

// FindByName finds an installed app whose Name equals name (any case).
func FindByName(dirs []string, name string) (Entry, bool) {
	for _, d := range dirs {
		files, _ := filepath.Glob(filepath.Join(d, "*.desktop"))
		for _, f := range files {
			e, ok := readEntry(f, strings.TrimSuffix(filepath.Base(f), ".desktop"))
			if ok && strings.EqualFold(e.Name, name) {
				return e, true
			}
		}
	}
	return Entry{}, false
}

// Entries lists every installed app (first dir wins for an id), in dir
// then file order.
func Entries(dirs []string) []Entry {
	var out []Entry
	seen := map[string]bool{}
	for _, d := range dirs {
		files, _ := filepath.Glob(filepath.Join(d, "*.desktop"))
		for _, f := range files {
			id := strings.TrimSuffix(filepath.Base(f), ".desktop")
			if seen[id] {
				continue
			}
			if e, ok := readEntry(f, id); ok {
				seen[id] = true
				out = append(out, e)
			}
		}
	}
	return out
}

// readEntry parses the [Desktop Entry] group; hidden/NoDisplay entries
// still count (they are installed), entries without Exec do not.
func readEntry(path, id string) (Entry, bool) {
	f, err := os.Open(path)
	if err != nil {
		return Entry{}, false
	}
	defer f.Close()
	e := Entry{ID: id}
	inMain := false
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if strings.HasPrefix(line, "[") {
			inMain = line == "[Desktop Entry]"
			continue
		}
		if !inMain {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		switch strings.TrimSpace(k) {
		case "Name":
			e.Name = strings.TrimSpace(v)
		case "Icon":
			e.Icon = strings.TrimSpace(v)
		case "Exec":
			e.Exec = strings.TrimSpace(v)
		case "StartupWMClass":
			e.StartupClass = strings.TrimSpace(v)
		}
	}
	return e, e.Exec != ""
}

// File is the installed .desktop file of a desktop id (first dir wins).
// Files in subdirectories have ids joined with "-" (desktop entry spec:
// <dir>/kde/foo.desktop is "kde-foo").
func File(dirs []string, id string) (string, bool) {
	id = strings.TrimSuffix(id, ".desktop")
	if id == "" || strings.ContainsAny(id, "/\x00") {
		return "", false
	}
	for _, d := range dirs {
		p := filepath.Join(d, id+".desktop")
		if st, err := os.Stat(p); err == nil && !st.IsDir() {
			return p, true
		}
		found := ""
		_ = filepath.WalkDir(d, func(path string, de fs.DirEntry, err error) error {
			if err != nil || found != "" || de.IsDir() || !strings.HasSuffix(path, ".desktop") {
				return nil
			}
			rel, _ := filepath.Rel(d, strings.TrimSuffix(path, ".desktop"))
			if strings.ReplaceAll(rel, string(filepath.Separator), "-") == id {
				found = path
				return filepath.SkipAll
			}
			return nil
		})
		if found != "" {
			return found, true
		}
	}
	return "", false
}
