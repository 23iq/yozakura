package fsbrowse

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func mkdirs(t *testing.T, root string, dirs ...string) {
	t.Helper()
	for _, d := range dirs {
		if err := os.MkdirAll(filepath.Join(root, d), 0o755); err != nil {
			t.Fatal(err)
		}
	}
}

func TestListFoldersOnlySortedVisibleFirst(t *testing.T) {
	root := t.TempDir()
	mkdirs(t, root, "b", "A", ".hidden", "repo/.git")
	if err := os.WriteFile(filepath.Join(root, "file.txt"), nil, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(root, "b"), filepath.Join(root, "link")); err != nil {
		t.Fatal(err)
	}
	l := List(root)
	var names []string
	for _, e := range l.Entries {
		names = append(names, e.Name)
	}
	want := []string{"A", "b", "link", "repo", ".hidden"}
	if len(names) != len(want) {
		t.Fatalf("names=%v", names)
	}
	for i := range want {
		if names[i] != want[i] {
			t.Fatalf("names=%v want %v", names, want)
		}
	}
	if !l.Entries[3].Git || l.Entries[0].Git || !l.Entries[4].Hidden {
		t.Fatalf("flags=%+v", l.Entries)
	}
	if l.Parent != filepath.Dir(root) || l.Error != "" {
		t.Fatalf("listing=%+v", l)
	}
	if missing := List(filepath.Join(root, "nope")); missing.Error == "" || len(missing.Entries) != 0 {
		t.Fatalf("missing=%+v", missing)
	}
}

func TestExpandTildeAndRelative(t *testing.T) {
	s := &Service{home: "/home/u"}
	for in, want := range map[string]string{"": "/home/u", "~": "/home/u", "~/src/": "/home/u/src", "src": "/home/u/src", "/tmp/../etc": "/etc"} {
		if got := s.expand(in); got != want {
			t.Fatalf("expand(%q)=%q want %q", in, got, want)
		}
	}
}

func TestScanFindsReposSkipsHeavyFolders(t *testing.T) {
	root := t.TempDir()
	mkdirs(t, root,
		"src/a/.git", "src/a/inner/.git", "work/team/b/.git",
		"node_modules/x/.git", ".cache/y/.git", ".dotfiles/.git", "deep/1/2/3/4/c/.git",
		"src/.hiddenrepo/.git")
	repos := Scan(root, 4, time.Now().Add(5*time.Second))
	got := map[string]bool{}
	for _, r := range repos {
		rel, _ := filepath.Rel(root, r.Path)
		got[rel] = true
	}
	for _, want := range []string{"src/a", "work/team/b", ".dotfiles"} {
		if !got[want] {
			t.Fatalf("missing %s in %v", want, got)
		}
	}
	for _, not := range []string{"src/a/inner", "node_modules/x", ".cache/y", "deep/1/2/3/4/c", "src/.hiddenrepo"} {
		if got[not] {
			t.Fatalf("unexpected %s in %v", not, got)
		}
	}
}

func TestReposCachedUntilRefresh(t *testing.T) {
	root := t.TempDir()
	mkdirs(t, root, "one/.git")
	s := &Service{home: root, ttl: time.Hour}
	first, _ := s.Repos(false)
	mkdirs(t, root, "two/.git")
	if cached, _ := s.Repos(false); len(cached) != len(first) {
		t.Fatalf("cache ignored: %v", cached)
	}
	res, err := s.reposMethod(json.RawMessage(`{"refresh":true}`))
	if err != nil {
		t.Fatal(err)
	}
	if n := len(res.(map[string]any)["repos"].([]Repo)); n != 2 {
		t.Fatalf("refresh found %d", n)
	}
}
