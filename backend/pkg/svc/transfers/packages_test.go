package transfers

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func fakePacman(t *testing.T) (lock, cache string) {
	t.Helper()
	dir := t.TempDir()
	lock = filepath.Join(dir, "db.lck")
	cache = filepath.Join(dir, "pkg")
	conf := filepath.Join(dir, "pacman.conf")
	must(t, os.MkdirAll(cache, 0o755))
	must(t, os.WriteFile(conf, []byte("[options]\n#CacheDir = /nope\nCacheDir = "+cache+"\nHoldPkg = pacman glibc\n"), 0o644))
	oldLock, oldConf := pacmanLockPath, pacmanConfPath
	pacmanLockPath, pacmanConfPath = lock, conf
	t.Cleanup(func() { pacmanLockPath, pacmanConfPath = oldLock, oldConf })
	return lock, cache
}

func TestPackagesPacmanDownloadAndDone(t *testing.T) {
	fp := newFakeProc(t)
	lock, cache := fakePacman(t)
	s := newPackagesSource()
	now := time.Unix(100, 0)
	s.now = func() time.Time { return now }
	s.maxAge = 0

	fp.add(10, "paru", []string{"paru", "-Syu"}, nil)
	if items := s.scan(); len(items) != 0 {
		t.Fatalf("no lock -> idle, got %+v", items)
	}

	must(t, os.WriteFile(lock, nil, 0o644))
	fp.add(11, "pacman", []string{"pacman", "-Syu"}, nil)
	items := s.scan()
	if len(items) != 1 || items[0].Title != "Updating system" || items[0].Kind != KindUpdate || items[0].Total != -1 {
		t.Fatalf("umbrella item %+v", items)
	}

	dl := filepath.Join(cache, "download-AbC123")
	must(t, os.MkdirAll(dl, 0o755))
	part := filepath.Join(dl, "linux-6.10.1.arch1-1-x86_64.pkg.tar.zst.part")
	writeSize(t, part, 1<<20)
	now = now.Add(time.Second)
	s.scan()
	writeSize(t, part, 3<<20)
	now = now.Add(time.Second)
	items = s.scan()
	if len(items) != 1 || items[0].Title != "linux-6.10.1.arch1-1-x86_64" || items[0].Processed != 3<<20 || items[0].Rate != float64(2<<20) || items[0].Detail != "Downloading" {
		t.Fatalf("package download %+v", items)
	}

	must(t, os.Remove(lock))
	fp.remove(11)
	now = now.Add(time.Second)
	items = s.scan()
	if len(items) != 1 || items[0].State != StateDone || items[0].Key != "system" {
		t.Fatalf("done %+v", items)
	}
	now = now.Add(browserDoneShown + time.Second)
	if items := s.scan(); len(items) != 0 {
		t.Fatalf("expired %+v", items)
	}
}

func TestPackagesFlatpak(t *testing.T) {
	fp := newFakeProc(t)
	fakePacman(t)
	s := newPackagesSource()
	s.maxAge = 0
	fp.add(20, "flatpak", []string{"flatpak", "install", "--user", "-y", "flathub", "org.gimp.GIMP"}, nil)
	fp.add(21, "flatpak", []string{"flatpak", "run", "org.mozilla.firefox"}, nil)
	items := s.scan()
	if len(items) != 1 || items[0].Title != "Installing org.gimp.GIMP" || items[0].App != "Flatpak" {
		t.Fatalf("flatpak %+v", items)
	}
	if flatpakTitle([]string{"flatpak", "update", "-y"}) != "Updating Flatpak apps" {
		t.Fatal("update title")
	}
	if flatpakTitle([]string{"flatpak", "list"}) != "" {
		t.Fatal("list is not an update")
	}
}
