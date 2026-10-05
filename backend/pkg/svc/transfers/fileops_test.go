package transfers

import (
	"path/filepath"
	"testing"
	"time"
)

func TestFileOpsCopyProgress(t *testing.T) {
	fp := newFakeProc(t)
	dir := t.TempDir()
	src := filepath.Join(dir, "holiday.mkv")
	dst := filepath.Join(dir, "backup", "holiday.mkv")
	writeSize(t, src, 8<<20)
	must(t, mkdirAll(filepath.Dir(dst)))
	writeSize(t, dst, 2<<20)
	fp.add(900, "cp", []string{"cp", src, dst}, map[int]fakeFD{
		3: {target: src, flags: flagsRead, pos: 2 << 20},
		4: {target: dst, flags: flagsWrite, pos: 2 << 20},
	})
	s := newProcSource(fileOpTools, fileOpPick)
	now := newTestProcSource(s)
	items := s.scan()
	if len(items) != 1 {
		t.Fatalf("want 1, got %+v", items)
	}
	it := items[0]
	if it.Title != "holiday.mkv" || it.Path != dst || it.Detail != "Copying" || it.Kind != KindCopy ||
		it.Processed != 2<<20 || it.Total != 8<<20 || it.App != "cp" {
		t.Fatalf("bad item %+v", it)
	}
	*now = now.Add(time.Second)
	fp.setPos(900, 3, 6<<20, flagsRead)
	it = s.scan()[0]
	if it.Processed != 6<<20 || it.Rate != float64(4<<20) {
		t.Fatalf("progress %+v", it)
	}
	*now = now.Add(time.Second)
	fp.setPos(900, 3, 8<<20, flagsRead)
	s.scan()
	fp.remove(900)
	*now = now.Add(time.Second)
	items = s.scan()
	if len(items) != 1 || items[0].State != StateDone || items[0].Processed != 8<<20 {
		t.Fatalf("done %+v", items)
	}
}

func TestFileOpsCancelledCopyIsNotDone(t *testing.T) {
	fp := newFakeProc(t)
	src := filepath.Join(t.TempDir(), "big.iso")
	writeSize(t, src, 4<<20)
	fp.add(1, "dd", []string{"dd", "if=" + src, "of=/dev/sdz"}, map[int]fakeFD{
		0: {target: src, flags: flagsRead, pos: 1 << 20},
		1: {target: "/dev/sdz", flags: flagsWrite},
	})
	s := newProcSource(fileOpTools, fileOpPick)
	now := newTestProcSource(s)
	*now = now.Add(time.Second)
	s.scan()
	fp.setPos(1, 0, 2<<20, flagsRead)
	*now = now.Add(time.Second)
	if it := s.scan()[0]; it.Path != src || it.Processed != 2<<20 {
		t.Fatalf("dd to a device keeps the source as path: %+v", it)
	}
	fp.remove(1)
	*now = now.Add(time.Second)
	if items := s.scan(); len(items) != 0 {
		t.Fatalf("half-done copy that vanished must not be reported done: %+v", items)
	}
}

func TestFileOpsIgnoresSmallFilesAndVerbs(t *testing.T) {
	fp := newFakeProc(t)
	dir := t.TempDir()
	small := filepath.Join(dir, "small.txt")
	writeSize(t, small, 1000)
	fp.add(2, "cp", []string{"cp", small, "/tmp/x"}, map[int]fakeFD{3: {target: small, flags: flagsRead}})
	s := newProcSource(fileOpTools, fileOpPick)
	newTestProcSource(s)
	if items := s.scan(); len(items) != 0 {
		t.Fatalf("small file reported: %+v", items)
	}
	cases := []struct {
		p    Proc
		want string
	}{
		{Proc{Comm: "tar", Args: []string{"tar", "xf", "a.tar"}}, "Extracting"},
		{Proc{Comm: "tar", Args: []string{"tar", "-xzf", "a.tgz"}}, "Extracting"},
		{Proc{Comm: "tar", Args: []string{"tar", "-czf", "a.tgz", "dir"}}, "Archiving"},
		{Proc{Comm: "tar", Args: []string{"tar", "--extract", "-f", "a"}}, "Extracting"},
		{Proc{Comm: "zstd", Args: []string{"zstd", "-d", "a.zst"}}, "Extracting"},
		{Proc{Comm: "zstd", Args: []string{"zstd", "-19", "a"}}, "Compressing"},
		{Proc{Comm: "7z", Args: []string{"7z", "x", "a.7z"}}, "Extracting"},
		{Proc{Comm: "7z", Args: []string{"7z", "a", "a.7z", "dir"}}, "Compressing"},
		{Proc{Comm: "ffmpeg", Args: []string{"ffmpeg", "-i", "a.mkv", "b.mp4"}}, "Converting"},
		{Proc{Comm: "mv", Args: []string{"mv", "a", "b"}}, "Moving"},
	}
	for _, c := range cases {
		if got := fileOpVerb(c.p); got != c.want {
			t.Errorf("%v: got %q want %q", c.p.Args, got, c.want)
		}
	}
}
