package keystore

import (
	"encoding/json"
	"os/exec"
	"path/filepath"
	"testing"
)

func newTest(t *testing.T) *Service {
	t.Helper()
	if _, err := exec.LookPath("sqlite3"); err != nil {
		t.Skip("sqlite3 not installed")
	}
	return &Service{db: filepath.Join(t.TempDir(), "sub", "keys.db"), lock: make(chan struct{}, 1)}
}

func TestSetOnCleanDirCreatesDBAndTable(t *testing.T) {
	s := newTest(t)
	res, _ := s.set(json.RawMessage(`{"provider":"p'x","api_key":"sec|ret\nline","endpoint":"e","custom_curl":"a\nb"}`))
	if m := res.(map[string]any); m["status"] != "ok" {
		t.Fatalf("set failed: %v", m)
	}
	got, _ := s.get(json.RawMessage(`{"provider":"p'x"}`))
	m := got.(map[string]any)
	if m["api_key"] != "sec|ret\nline" || m["custom_curl"] != "a\nb" || m["endpoint"] != "e" {
		t.Fatalf("roundtrip: %v", m)
	}
	if h, _ := s.has(json.RawMessage(`{"provider":"p'x"}`)); h != true {
		t.Fatal("has")
	}
	l, err := s.list(nil)
	if err != nil || len(l.([]entry)) != 1 {
		t.Fatalf("list: %v %v", l, err)
	}
	if _, err := s.delete(json.RawMessage(`{"provider":"p'x"}`)); err != nil {
		t.Fatal(err)
	}
	if h, _ := s.has(json.RawMessage(`{"provider":"p'x"}`)); h != false {
		t.Fatal("deleted")
	}
}

func TestListOnCleanDirIsEmpty(t *testing.T) {
	s := newTest(t)
	l, err := s.list(nil)
	if err != nil || len(l.([]entry)) != 0 {
		t.Fatalf("%v %v", l, err)
	}
}
