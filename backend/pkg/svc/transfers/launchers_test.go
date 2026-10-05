package transfers

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestParseLauncherLogs(t *testing.T) {
	p, ok := parseLauncherLog(string(fixture(t, "heroic/heroic.log")))
	if !ok || p.Title != "Hades" || p.Percent != 12.34 || p.Downloaded != heroicBytes(510.66) || p.Rate != 48.25*mib {
		t.Fatalf("heroic %+v", p)
	}
	if p.Total <= p.Downloaded {
		t.Fatalf("total estimated from the percentage: %+v", p)
	}
	l, ok := parseLauncherLog(string(fixture(t, "heroic/legendary.log")))
	if !ok || l.Percent != 25 || l.Total != 4096*mib || l.Downloaded != 1024*mib || l.Rate != 14.63*mib {
		t.Fatalf("legendary %+v", l)
	}
	g, ok := parseLauncherLog("[PROGRESS] INFO: = Progress: 40.00 400/1000, Running for: 00:00:10, ETA: 00:00:15\n[PROGRESS] INFO: = Downloaded: 200.00 MiB, Written: 300.00 MiB\n")
	if !ok || g.Percent != 40 || g.Total != 500*mib {
		t.Fatalf("gogdl %+v", g)
	}
	if _, ok := parseLauncherLog("(13:00:00) INFO: [Frontend]: Refreshing library\n"); ok {
		t.Fatal("no progress in an unrelated log")
	}
}

func TestLaunchersScan(t *testing.T) {
	logs := t.TempDir()
	os.MkdirAll(filepath.Join(logs, "games"), 0o755)
	os.WriteFile(filepath.Join(logs, "games", "heroic.log"), fixture(t, "heroic/heroic.log"), 0o644)
	procs := []Proc{
		{PID: 1, Comm: "legendary", Args: []string{"/opt/Heroic/resources/app.asar.unpacked/build/bin/linux/legendary", "install", "Min", "--platform", "Windows", "-y"}},
		{PID: 2, Comm: "legendary", Args: []string{"legendary", "launch", "Fortnite"}}, // playing, not downloading
		{PID: 3, Comm: "lutris", Args: []string{"/usr/bin/python3", "/usr/bin/lutris", "lutris:install/hollow-knight-gog"}},
		{PID: 4, Comm: "lutris", Args: []string{"/usr/bin/python3", "/usr/bin/lutris"}},
	}
	s := newLaunchersSource()
	s.logDirs = []string{logs}
	s.listProc = func() []Proc { return procs }
	items := s.scan()
	m := byKeyMap(items)
	if len(items) != 2 {
		t.Fatalf("items %+v", items)
	}
	h := m["legendary:Min"]
	if h.Title != "Hades" || h.App != "Heroic" || h.Detail != "Epic Games" || h.Total <= 0 || h.Processed != heroicBytes(510.66) || h.Rate != 48.25*mib {
		t.Fatalf("heroic item %+v", h)
	}
	if l := m["lutris:hollow-knight-gog"]; l.App != "Lutris" || l.Total != -1 {
		t.Fatalf("lutris item %+v", l)
	}

	// A stale log gives an indeterminate item with the game id
	old := time.Now().Add(-time.Hour)
	os.Chtimes(filepath.Join(logs, "games", "heroic.log"), old, old)
	items = s.scan()
	if h := byKeyMap(items)["legendary:Min"]; h.Title != "Min" || h.Total != -1 {
		t.Fatalf("stale log %+v", h)
	}

	procs = nil
	if items := s.scan(); len(items) != 0 || len(s.started) != 0 {
		t.Fatalf("nothing running: %+v", items)
	}
}

func TestHelperJob(t *testing.T) {
	if sub, game, ok := helperJob(Proc{Comm: "gogdl", Args: []string{"gogdl", "--auth-config-path", "/x", "download", "1207658924", "--platform", "windows"}}); !ok || sub != "download" || game != "1207658924" {
		t.Fatalf("gogdl %v %v %v", sub, game, ok)
	}
	if _, _, ok := helperJob(Proc{Comm: "nile", Args: []string{"nile", "library", "sync"}}); ok {
		t.Fatal("library sync is not a download")
	}
}

func heroicBytes(v float64) int64 { return int64(v * mib) }
