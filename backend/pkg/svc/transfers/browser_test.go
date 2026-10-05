package transfers

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func newTestBrowser(t *testing.T, owners map[string]string) (*browserSource, *time.Time) {
	b := newBrowserSource()
	b.dir = t.TempDir()
	now := time.Unix(1000, 0)
	b.now = func() time.Time { return now }
	b.owners = func(paths []string) map[string]string { return owners }
	return b, &now
}

func TestBrowserFirefoxPartLifecycle(t *testing.T) {
	b, now := newTestBrowser(t, nil)
	final := filepath.Join(b.dir, "ubuntu-24.04.iso")
	part := final + ".part"
	writeSize(t, final, 0) // Firefox's placeholder
	writeSize(t, part, 1<<20)
	items := b.scan()
	if len(items) != 1 {
		t.Fatalf("want 1 item, got %+v", items)
	}
	it := items[0]
	if it.App != "Firefox" || it.AppIcon != "firefox" || it.Title != "ubuntu-24.04.iso" || it.Path != final || it.Dir != b.dir {
		t.Fatalf("bad item %+v", it)
	}
	if it.Processed != 1<<20 || it.Total != -1 || it.Rate != -1 || it.State != StateRunning {
		t.Fatalf("bad numbers %+v", it)
	}

	*now = now.Add(time.Second)
	writeSize(t, part, 3<<20)
	it = b.scan()[0]
	if it.Rate != float64(2<<20) {
		t.Fatalf("rate %v", it.Rate)
	}

	*now = now.Add(11 * time.Second)
	it = b.scan()[0]
	if it.State != StatePaused || it.Detail != "Stalled" || it.Rate != 0 {
		t.Fatalf("stall not detected %+v", it)
	}

	// Firefox renames on completion
	must(t, os.Rename(part, final))
	*now = now.Add(time.Second)
	items = b.scan()
	if len(items) != 1 || items[0].State != StateDone || items[0].Total != 3<<20 {
		t.Fatalf("completion %+v", items)
	}
	*now = now.Add(browserDoneShown + time.Second)
	if items = b.scan(); len(items) != 0 {
		t.Fatalf("done item should expire, got %+v", items)
	}
}

func TestBrowserCancelledDownloadDisappears(t *testing.T) {
	b, now := newTestBrowser(t, nil)
	part := filepath.Join(b.dir, "x.zip.crdownload")
	writeSize(t, part, 100)
	if len(b.scan()) != 1 {
		t.Fatal("crdownload not seen")
	}
	must(t, os.Remove(part))
	*now = now.Add(time.Second)
	if items := b.scan(); len(items) != 0 {
		t.Fatalf("cancelled download should vanish, got %+v", items)
	}
}

func TestBrowserOwnerResolution(t *testing.T) {
	b, _ := newTestBrowser(t, nil)
	cr := filepath.Join(b.dir, "Setup.exe.crdownload")
	op := filepath.Join(b.dir, "doc.pdf.opdownload")
	writeSize(t, cr, 10)
	writeSize(t, op, 10)
	b.owners = func(paths []string) map[string]string { return map[string]string{cr: "brave"} }
	got := map[string]Transfer{}
	for _, it := range b.scan() {
		got[it.Title] = it
	}
	if got["Setup.exe"].App != "Brave" || got["Setup.exe"].AppIcon != "brave-browser" {
		t.Fatalf("brave not resolved: %+v", got["Setup.exe"])
	}
	if got["doc.pdf"].App != "Opera" {
		t.Fatalf("opdownload should default to Opera: %+v", got["doc.pdf"])
	}
}

func TestBrowserIgnoresOtherFilesAndMissingDir(t *testing.T) {
	b, _ := newTestBrowser(t, nil)
	writeSize(t, filepath.Join(b.dir, "notes.txt"), 10)
	must(t, os.Mkdir(filepath.Join(b.dir, "folder.part"), 0o755))
	writeSize(t, filepath.Join(b.dir, ".part"), 10)
	if items := b.scan(); len(items) != 0 {
		t.Fatalf("unexpected items %+v", items)
	}
	b.dir = filepath.Join(b.dir, "missing")
	if items := b.scan(); len(items) != 0 {
		t.Fatal("missing dir must yield nothing")
	}
}
