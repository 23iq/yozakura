package transfers

import (
	"path/filepath"
	"testing"
	"time"
)

func newTestProcSource(src *procSource) *time.Time {
	now := time.Unix(5000, 0)
	src.now = func() time.Time { return now }
	src.maxAge = 0
	return &now
}

func TestTerminalCurlDownload(t *testing.T) {
	fp := newFakeProc(t)
	dir := t.TempDir()
	out := filepath.Join(dir, "linux-6.10.tar.xz")
	writeSize(t, out, 4<<20)
	fp.add(321, "curl", []string{"curl", "-LO", "https://cdn.kernel.org/linux-6.10.tar.xz"}, map[int]fakeFD{
		0: {target: "/dev/pts/1", flags: flagsRW},
		1: {target: "/dev/pts/1", flags: flagsRW},
		3: {target: "socket:[777]", flags: flagsRW},
		4: {target: out, flags: flagsWrite},
	})
	src := newProcSource(terminalTools, terminalPick)
	now := newTestProcSource(src)
	items := src.scan()
	if len(items) != 1 {
		t.Fatalf("want 1, got %+v", items)
	}
	it := items[0]
	if it.App != "curl" || it.Title != "linux-6.10.tar.xz" || it.Path != out || it.Processed != 4<<20 || it.Total != -1 || it.Kind != KindDownload {
		t.Fatalf("bad item %+v", it)
	}
	*now = now.Add(time.Second)
	writeSize(t, out, 6<<20)
	it = src.scan()[0]
	if it.Rate != float64(2<<20) {
		t.Fatalf("rate %v", it.Rate)
	}
	// curl exits after finishing: shown as done for a moment
	fp.remove(321)
	*now = now.Add(time.Second)
	items = src.scan()
	if len(items) != 1 || items[0].State != StateDone || items[0].Total != 6<<20 {
		t.Fatalf("done %+v", items)
	}
	*now = now.Add(browserDoneShown + time.Second)
	if len(src.scan()) != 0 {
		t.Fatal("done should expire")
	}
}

func TestTerminalYtdlpPartAndSideFiles(t *testing.T) {
	fp := newFakeProc(t)
	dir := t.TempDir()
	part := filepath.Join(dir, "Talk [abc123].mp4.part")
	state := filepath.Join(dir, "Talk [abc123].mp4.ytdl")
	writeSize(t, part, 1000)
	writeSize(t, state, 5000) // bigger, but a side file
	fp.add(77, "yt-dlp", []string{"/usr/bin/python3", "/usr/bin/yt-dlp", "URL"}, map[int]fakeFD{
		5: {target: state, flags: flagsWrite},
		6: {target: part, flags: flagsWrite},
	})
	src := newProcSource(terminalTools, terminalPick)
	newTestProcSource(src)
	it := src.scan()[0]
	if it.Title != "Talk [abc123].mp4" || it.Path != filepath.Join(dir, "Talk [abc123].mp4") || it.App != "yt-dlp" {
		t.Fatalf("bad item %+v", it)
	}
}

func TestTerminalKilledWithoutProgressIsDropped(t *testing.T) {
	fp := newFakeProc(t)
	out := filepath.Join(t.TempDir(), "f")
	writeSize(t, out, 10)
	fp.add(5, "wget", []string{"wget", "x"}, map[int]fakeFD{3: {target: out, flags: flagsWrite}})
	src := newProcSource(terminalTools, terminalPick)
	now := newTestProcSource(src)
	src.scan()
	fp.remove(5)
	*now = now.Add(time.Second)
	if items := src.scan(); len(items) != 0 {
		t.Fatalf("no growth seen -> no done item, got %+v", items)
	}
}

func TestTerminalIgnoresProcessesWithoutPayload(t *testing.T) {
	fp := newFakeProc(t)
	fp.add(9, "curl", []string{"curl", "https://example.org"}, map[int]fakeFD{1: {target: "/dev/pts/0", flags: flagsRW}})
	fp.add(10, "bash", []string{"bash"}, nil)
	src := newProcSource(terminalTools, terminalPick)
	newTestProcSource(src)
	if items := src.scan(); len(items) != 0 {
		t.Fatalf("got %+v", items)
	}
}
