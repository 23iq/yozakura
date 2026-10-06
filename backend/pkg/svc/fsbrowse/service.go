// Package fsbrowse answers the AI bar's folder picker: the subfolders of a
// directory (fs.list) and the git repositories under the home directory
// (fs.repos, scanned to a small depth and cached). Read-only; handlers run
// on the IPC server's goroutines, so a scan never blocks the shell.
package fsbrowse

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"yozakura/backend/pkg/ipc"
)

// maxEntries caps one listing (a folder with 50k subfolders is not browsed).
const maxEntries = 2000

// Entry is one subfolder.
type Entry struct {
	Name   string `json:"name"`
	Path   string `json:"path"`
	Git    bool   `json:"git"`
	Hidden bool   `json:"hidden"`
}

// Listing is the fs.list result.
type Listing struct {
	Dir       string  `json:"dir"`
	Parent    string  `json:"parent"`
	Entries   []Entry `json:"entries"`
	Git       bool    `json:"git"`
	Truncated bool    `json:"truncated,omitempty"`
	Error     string  `json:"error,omitempty"`
}

// Service is the "fs" IPC service.
type Service struct {
	home  string
	ttl   time.Duration
	mu    sync.Mutex
	scan  sync.Mutex
	repos []Repo
	at    time.Time
}

// NewService browses relative to the user's home directory.
func NewService() *Service {
	home, _ := os.UserHomeDir()
	return &Service{home: home, ttl: 10 * time.Minute}
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "fs",
		Methods: map[string]ipc.HandlerFunc{
			"list":  s.list,
			"repos": s.reposMethod,
		},
	})
}

// expand turns "~", "~/x" and relative paths into a clean absolute path.
func (s *Service) expand(p string) string {
	p = strings.TrimSpace(p)
	switch {
	case p == "" || p == "~":
		return s.home
	case strings.HasPrefix(p, "~/"):
		p = filepath.Join(s.home, p[2:])
	case !filepath.IsAbs(p):
		p = filepath.Join(s.home, p)
	}
	return filepath.Clean(p)
}

func isGit(dir string) bool {
	_, err := os.Stat(filepath.Join(dir, ".git"))
	return err == nil
}

func (s *Service) list(params json.RawMessage) (any, error) {
	var p struct {
		Dir string `json:"dir"`
	}
	_ = json.Unmarshal(params, &p)
	return List(s.expand(p.Dir)), nil
}

// List returns the subfolders of dir (symlinks to folders included),
// sorted case-insensitively, visible ones first.
func List(dir string) Listing {
	out := Listing{Dir: dir, Parent: filepath.Dir(dir), Entries: []Entry{}, Git: isGit(dir)}
	if dir == "/" {
		out.Parent = ""
	}
	items, err := os.ReadDir(dir)
	if err != nil {
		out.Error = err.Error()
		return out
	}
	for _, it := range items {
		path := filepath.Join(dir, it.Name())
		if !it.IsDir() {
			if it.Type()&os.ModeSymlink == 0 {
				continue
			}
			if st, err := os.Stat(path); err != nil || !st.IsDir() {
				continue
			}
		}
		if len(out.Entries) >= maxEntries {
			out.Truncated = true
			break
		}
		out.Entries = append(out.Entries, Entry{Name: it.Name(), Path: path, Git: isGit(path), Hidden: strings.HasPrefix(it.Name(), ".")})
	}
	sort.SliceStable(out.Entries, func(i, j int) bool {
		a, b := out.Entries[i], out.Entries[j]
		if a.Hidden != b.Hidden {
			return !a.Hidden
		}
		return strings.ToLower(a.Name) < strings.ToLower(b.Name)
	})
	return out
}
