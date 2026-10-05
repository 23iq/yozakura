package transfers

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

// fakeProc builds a /proc-like tree and points procRoot at it.
type fakeProc struct {
	t    *testing.T
	root string
}

type fakeFD struct {
	target string
	flags  int // octal-able open flags, e.g. 0100001 (O_WRONLY|O_LARGEFILE)
	pos    int64
}

const (
	flagsRead  = 0100000
	flagsWrite = 0100001
	flagsRW    = 0100002
)

func newFakeProc(t *testing.T) *fakeProc {
	t.Helper()
	root := t.TempDir()
	old := procRoot
	procRoot = root
	resetProcSnapshot()
	t.Cleanup(func() {
		procRoot = old
		resetProcSnapshot()
	})
	return &fakeProc{t: t, root: root}
}

func (f *fakeProc) add(pid int, comm string, args []string, fds map[int]fakeFD) {
	f.t.Helper()
	dir := filepath.Join(f.root, strconv.Itoa(pid))
	must(f.t, os.MkdirAll(filepath.Join(dir, "fd"), 0o755))
	must(f.t, os.MkdirAll(filepath.Join(dir, "fdinfo"), 0o755))
	must(f.t, os.WriteFile(filepath.Join(dir, "comm"), []byte(comm+"\n"), 0o644))
	must(f.t, os.WriteFile(filepath.Join(dir, "cmdline"), []byte(strings.Join(args, "\x00")+"\x00"), 0o644))
	for n, fd := range fds {
		must(f.t, os.Symlink(fd.target, filepath.Join(dir, "fd", strconv.Itoa(n))))
		info := fmt.Sprintf("pos:\t%d\nflags:\t%o\nmnt_id:\t25\nino:\t1234\n", fd.pos, fd.flags)
		must(f.t, os.WriteFile(filepath.Join(dir, "fdinfo", strconv.Itoa(n)), []byte(info), 0o644))
	}
	resetProcSnapshot()
}

func (f *fakeProc) setPos(pid, fd int, pos int64, flags int) {
	f.t.Helper()
	info := fmt.Sprintf("pos:\t%d\nflags:\t%o\n", pos, flags)
	must(f.t, os.WriteFile(filepath.Join(f.root, strconv.Itoa(pid), "fdinfo", strconv.Itoa(fd)), []byte(info), 0o644))
}

func (f *fakeProc) remove(pid int) {
	must(f.t, os.RemoveAll(filepath.Join(f.root, strconv.Itoa(pid))))
	resetProcSnapshot()
}

func must(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}

func writeSize(t *testing.T, path string, size int64) {
	t.Helper()
	must(t, os.WriteFile(path, make([]byte, size), 0o644))
}

func mkdirAll(dir string) error { return os.MkdirAll(dir, 0o755) }
