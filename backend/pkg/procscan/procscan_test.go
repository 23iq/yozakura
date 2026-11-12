package procscan

import (
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"syscall"
	"testing"
)

// fakeProc writes /proc/<pid>/{comm,cmdline} under root.
func fakeProc(t *testing.T, root string, pid int, comm string, argv ...string) {
	t.Helper()
	dir := filepath.Join(root, strconv.Itoa(pid))
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "comm"), []byte(comm+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	cmdline := ""
	if len(argv) > 0 {
		cmdline = strings.Join(argv, "\x00") + "\x00"
	}
	if err := os.WriteFile(filepath.Join(dir, "cmdline"), []byte(cmdline), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestListReadsArgvAndComm(t *testing.T) {
	root := t.TempDir()
	fakeProc(t, root, 10, "wl-paste", "wl-paste", "--watch", "sh", "-c", "cat >/dev/null; echo X")
	fakeProc(t, root, 11, "kthreadd")
	if err := os.MkdirAll(filepath.Join(root, "self"), 0o755); err != nil {
		t.Fatal(err)
	}
	procs := List(root)
	if len(procs) != 2 {
		t.Fatalf("got %d procs, want 2: %+v", len(procs), procs)
	}
	byPID := map[int]Proc{}
	for _, p := range procs {
		byPID[p.PID] = p
	}
	wp := byPID[10]
	want := []string{"wl-paste", "--watch", "sh", "-c", "cat >/dev/null; echo X"}
	if !slices.Equal(wp.Argv, want) || wp.Comm != "wl-paste" || wp.UID != os.Getuid() {
		t.Fatalf("pid 10 = %+v", wp)
	}
	if len(byPID[11].Argv) != 0 {
		t.Fatalf("kernel thread argv = %q", byPID[11].Argv)
	}
}

func TestSignalSkipsSelfAndOtherUsers(t *testing.T) {
	root := t.TempDir()
	fakeProc(t, root, 20, "mako", "mako")
	fakeProc(t, root, 21, "mako", "mako")
	var got []int
	k := Killer{Root: root, UID: os.Getuid(), Self: 21, Kill: func(pid int, sig syscall.Signal) error {
		if sig != syscall.SIGTERM {
			t.Fatalf("signal %v", sig)
		}
		got = append(got, pid)
		return nil
	}}
	hit := k.Signal(func(p Proc) bool { return NamedAny(p, "mako") }, syscall.SIGTERM)
	if !slices.Equal(hit, []int{20}) || !slices.Equal(got, []int{20}) {
		t.Fatalf("hit %v, killed %v; want only 20", hit, got)
	}
	k.UID = os.Getuid() + 1
	if hit := k.Signal(func(Proc) bool { return true }, syscall.SIGTERM); len(hit) != 0 {
		t.Fatalf("signalled another user's processes: %v", hit)
	}
}

func TestNamedAnyIsExact(t *testing.T) {
	cases := []struct {
		name string
		p    Proc
		want bool
	}{
		{"plain", Proc{Comm: "dunst", Argv: []string{"/usr/bin/dunst"}}, true},
		{"nix wrapper", Proc{Comm: ".swaync-wrapped", Argv: []string{"/nix/store/x/bin/swaync"}}, true},
		{"wrapper argv0", Proc{Comm: "x", Argv: []string{"/nix/store/x/bin/.mako-wrapped"}}, true},
		{"editor on a file", Proc{Comm: "nvim", Argv: []string{"nvim", "mako_template.py"}}, false},
		{"path containing the name", Proc{Comm: "yozakura", Argv: []string{"/home/tamako/.local/bin/yozakura"}}, false},
		{"prefix only", Proc{Comm: "makoctl", Argv: []string{"makoctl", "dismiss"}}, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := NamedAny(tc.p, "dunst", "mako", "swaync"); got != tc.want {
				t.Fatalf("NamedAny(%+v) = %v, want %v", tc.p, got, tc.want)
			}
		})
	}
}
