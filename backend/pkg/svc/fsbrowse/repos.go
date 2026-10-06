package fsbrowse

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// Repo is a discovered git repository.
type Repo struct {
	Path     string `json:"path"`
	Name     string `json:"name"`
	Modified int64  `json:"modified"`
}

// Scan limits: depth below home, folders visited and wall time.
const (
	scanDepth  = 4
	scanBudget = 1500 * time.Millisecond
	scanDirs   = 40000
)

// skipped folders never hold projects worth listing (or are huge).
var skipped = map[string]bool{
	"node_modules": true, ".cache": true, ".local": true, ".npm": true, ".cargo": true,
	".rustup": true, "go": true, ".git": true, "vendor": true, "target": true,
	".venv": true, "venv": true, "__pycache__": true, ".mozilla": true, ".steam": true,
	".var": true, "Trash": true, ".Trash": true, "snap": true, ".gradle": true,
	".m2": true, ".nix-profile": true, "dist": true, "build": true, ".wine": true,
}

func (s *Service) reposMethod(params json.RawMessage) (any, error) {
	var p struct {
		Refresh bool `json:"refresh"`
	}
	_ = json.Unmarshal(params, &p)
	repos, at := s.Repos(p.Refresh)
	return map[string]any{"repos": repos, "scannedAt": at.UnixMilli()}, nil
}

// Repos returns the cached repositories, scanning when the cache is
// missing, stale or refresh is set. Concurrent callers share one scan.
func (s *Service) Repos(refresh bool) ([]Repo, time.Time) {
	s.scan.Lock()
	defer s.scan.Unlock()
	s.mu.Lock()
	fresh := s.repos != nil && time.Since(s.at) < s.ttl && !refresh
	repos, at := s.repos, s.at
	s.mu.Unlock()
	if fresh {
		return repos, at
	}
	repos = Scan(s.home, scanDepth, time.Now().Add(scanBudget))
	at = time.Now()
	s.mu.Lock()
	s.repos, s.at = repos, at
	s.mu.Unlock()
	return repos, at
}

// Scan walks root breadth first to `depth` levels and returns the git
// repositories it finds (it does not descend into them), most recently
// modified first. It stops at the deadline or after scanDirs folders.
func Scan(root string, depth int, deadline time.Time) []Repo {
	out := []Repo{}
	level := []string{root}
	visited := 0
	for d := 0; d <= depth && len(level) > 0; d++ {
		var next []string
		for _, dir := range level {
			if visited >= scanDirs || time.Now().After(deadline) {
				return sortRepos(out)
			}
			visited++
			if dir != root && isGit(dir) {
				out = append(out, repoAt(dir))
				continue
			}
			if d == depth {
				continue
			}
			items, err := os.ReadDir(dir)
			if err != nil {
				continue
			}
			for _, it := range items {
				if !it.IsDir() || skipped[it.Name()] {
					continue
				}
				// Hidden folders are skipped except at the top (~/.config/x
				// is rarely a project, ~/.dotfiles often is).
				if strings.HasPrefix(it.Name(), ".") && dir != root {
					continue
				}
				next = append(next, filepath.Join(dir, it.Name()))
			}
		}
		level = next
	}
	return sortRepos(out)
}

func repoAt(dir string) Repo {
	r := Repo{Path: dir, Name: filepath.Base(dir)}
	if st, err := os.Stat(filepath.Join(dir, ".git")); err == nil {
		r.Modified = st.ModTime().UnixMilli()
	}
	return r
}

func sortRepos(r []Repo) []Repo {
	sort.SliceStable(r, func(i, j int) bool {
		if r[i].Modified != r[j].Modified {
			return r[i].Modified > r[j].Modified
		}
		return r[i].Path < r[j].Path
	})
	return r
}
