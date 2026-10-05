package transfers

import (
	"bufio"
	"context"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

// packages: system updates. pacman and its wrappers (yay, paru, pamac)
// count while the pacman db lock exists; packages being downloaded show up
// as growing "*.part" files in pacman's CacheDir (pacman >= 6 downloads into
// "download-*" subdirectories), each with size and rate. Without a partial
// file the update is one indeterminate "Updating system" item. Running
// `flatpak install|update` processes become an indeterminate item too
// (flatpak prints its progress only to its terminal).

func init() { register("packages", func() Source { return newPackagesSource() }) }

// Overridable paths (tests)
var (
	pacmanLockPath = "/var/lib/pacman/db.lck"
	pacmanConfPath = "/etc/pacman.conf"
	pacmanCacheDef = "/var/cache/pacman/pkg"
)

var pacmanFamily = map[string]bool{"pacman": true, "yay": true, "paru": true, "pamac": true, "pikaur": true, "aura": true}

type packagesSource struct {
	now      func() time.Time
	maxAge   time.Duration
	parts    map[string]*partialFile
	wasBusy  bool
	finished map[string]finishedFile
}

func newPackagesSource() *packagesSource {
	return &packagesSource{now: time.Now, maxAge: activeSampling / 2, parts: map[string]*partialFile{}, finished: map[string]finishedFile{}}
}

func (s *packagesSource) Run(ctx context.Context, env *Env) {
	for {
		items := s.scan()
		env.Update(items)
		interval := idleDiscovery
		if len(items) > 0 {
			interval = activeSampling
		}
		if !sleepOrWake(ctx, interval, nil) {
			return
		}
	}
}

// pacmanCacheDirs reads CacheDir entries from pacman.conf.
func pacmanCacheDirs() []string {
	var dirs []string
	if f, err := os.Open(pacmanConfPath); err == nil {
		defer f.Close()
		sc := bufio.NewScanner(f)
		for sc.Scan() {
			line := strings.TrimSpace(sc.Text())
			k, v, ok := strings.Cut(line, "=")
			if ok && strings.TrimSpace(k) == "CacheDir" {
				dirs = append(dirs, strings.Fields(v)...)
			}
		}
	}
	if len(dirs) == 0 {
		dirs = []string{pacmanCacheDef}
	}
	return dirs
}

// pacmanPartials lists "*.part" files in the cache dirs and their
// "download-*" subdirectories.
func pacmanPartials() []string {
	var out []string
	for _, dir := range pacmanCacheDirs() {
		entries, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, e := range entries {
			name := e.Name()
			if e.IsDir() && strings.HasPrefix(name, "download-") {
				sub, _ := os.ReadDir(filepath.Join(dir, name))
				for _, se := range sub {
					if strings.HasSuffix(se.Name(), ".part") && !se.IsDir() {
						out = append(out, filepath.Join(dir, name, se.Name()))
					}
				}
			} else if strings.HasSuffix(name, ".part") && !e.IsDir() {
				out = append(out, filepath.Join(dir, name))
			}
		}
	}
	return out
}

// flatpakTitle describes a flatpak process ("" when it is not installing
// or updating anything).
func flatpakTitle(args []string) string {
	var verb string
	var refs []string
	for i, a := range args {
		if i == 0 || strings.HasPrefix(a, "-") {
			continue
		}
		if verb == "" {
			switch a {
			case "install", "update", "upgrade":
				verb = a
				continue
			default:
				return ""
			}
		}
		refs = append(refs, a)
	}
	switch verb {
	case "install":
		if len(refs) > 0 {
			return "Installing " + refs[len(refs)-1]
		}
		return "Installing Flatpak apps"
	case "update", "upgrade":
		return "Updating Flatpak apps"
	}
	return ""
}

func packageName(partPath string) string {
	name := strings.TrimSuffix(filepath.Base(partPath), ".part")
	for _, ext := range []string{".pkg.tar.zst", ".pkg.tar.xz", ".pkg.tar.gz", ".pkg.tar", ".sig"} {
		name = strings.TrimSuffix(name, ext)
	}
	return name
}

func (s *packagesSource) scan() []Transfer {
	now := s.now()
	var out []Transfer
	busy := false
	if _, err := os.Stat(pacmanLockPath); err == nil {
		for _, p := range SnapshotProcs(s.maxAge) {
			if pacmanFamily[p.Comm] {
				busy = true
				break
			}
		}
	}
	seen := map[string]bool{}
	if busy {
		for _, path := range pacmanPartials() {
			size := FileSize(path)
			if size < 0 {
				continue
			}
			seen[path] = true
			p := s.parts[path]
			if p == nil {
				p = &partialFile{}
				s.parts[path] = p
			}
			p.size = size
			p.meter.Observe(size, now)
			t := Unknown()
			t.Key = "pkg:" + filepath.Base(path)
			t.App, t.AppIcon = "pacman", "system-software-update"
			t.Title = packageName(path)
			t.Detail = "Downloading"
			t.Kind = KindUpdate
			t.Processed = size
			t.Rate = p.meter.Rate()
			t.StartedAt = p.meter.Started().UnixMilli()
			out = append(out, t)
		}
		if len(out) == 0 {
			t := Unknown()
			t.Key = "system"
			t.App, t.AppIcon = "pacman", "system-software-update"
			t.Title = "Updating system"
			t.Kind = KindUpdate
			out = append(out, t)
		}
	} else if s.wasBusy {
		t := Unknown()
		t.Key = "system"
		t.App, t.AppIcon = "pacman", "system-software-update"
		t.Title = "Updating system"
		t.Kind = KindUpdate
		t.State = StateDone
		s.finished["system"] = finishedFile{item: t, at: now}
	}
	s.wasBusy = busy
	for path := range s.parts {
		if !seen[path] {
			delete(s.parts, path)
		}
	}
	for _, p := range SnapshotProcs(s.maxAge) {
		if p.Comm != "flatpak" {
			continue
		}
		title := flatpakTitle(p.Args)
		if title == "" {
			continue
		}
		t := Unknown()
		t.Key = "flatpak:" + strconv.Itoa(p.PID)
		t.App, t.AppIcon = "Flatpak", "flatpak"
		t.Title = title
		t.Kind = KindUpdate
		out = append(out, t)
	}
	for key, f := range s.finished {
		if now.Sub(f.at) > browserDoneShown {
			delete(s.finished, key)
			continue
		}
		out = append(out, f.item)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Key < out[j].Key })
	return out
}
