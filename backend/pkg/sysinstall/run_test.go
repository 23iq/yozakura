package sysinstall

import (
	"bytes"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"yozakura/backend/pkg/svc/extras"
)

type fakeSys struct {
	calls  [][]string
	files  map[string][]byte
	writes map[string][]byte
	fail   string
}

func (f *fakeSys) helper(out *bytes.Buffer) Helper {
	f.writes = map[string][]byte{}
	return Helper{
		Out: out,
		Run: func(name string, args ...string) error {
			f.calls = append(f.calls, append([]string{name}, args...))
			if name == f.fail {
				return errors.New("exit status 1")
			}
			return nil
		},
		ReadFile: func(p string) ([]byte, error) {
			if d, ok := f.files[p]; ok {
				return d, nil
			}
			return nil, os.ErrNotExist
		},
		WriteFile: func(p string, d []byte) error { f.writes[p] = d; return nil },
	}
}

func TestInstallArch(t *testing.T) {
	f := &fakeSys{}
	err := f.helper(&bytes.Buffer{}).Install(testCatalog(), extras.Platform{Distro: "arch", GPU: "nvidia"}, []string{"ollama", "arch-only"})
	if err != nil {
		t.Fatal(err)
	}
	want := [][]string{
		{"pacman", "-S", "--needed", "--noconfirm", "ollama-cuda", "cuda"},
		{"systemctl", "enable", "--now", "ollama"},
	}
	if !reflect.DeepEqual(f.calls, want) {
		t.Fatalf("calls = %v", f.calls)
	}
}

func TestInstallFedoraAndFailureStopsUnits(t *testing.T) {
	f := &fakeSys{fail: "dnf"}
	err := f.helper(&bytes.Buffer{}).Install(testCatalog(), extras.Platform{Distro: "fedora"}, []string{"ollama"})
	if err == nil || len(f.calls) != 1 || f.calls[0][0] != "dnf" || f.calls[0][1] != "install" {
		t.Fatalf("err=%v calls=%v", err, f.calls)
	}
}

func TestInstallRejectsBeforeRunning(t *testing.T) {
	f := &fakeSys{}
	if err := f.helper(&bytes.Buffer{}).Install(testCatalog(), extras.Platform{Distro: "arch"}, []string{"ollama", "aur-only"}); err == nil {
		t.Fatal("expected error")
	}
	if len(f.calls) != 0 {
		t.Fatalf("ran %v", f.calls)
	}
}

func TestUpgrade(t *testing.T) {
	f := &fakeSys{}
	h := f.helper(&bytes.Buffer{})
	if h.Upgrade("arch") != nil || h.Upgrade("fedora") != nil || h.Upgrade("nixos") == nil {
		t.Fatal("upgrade results")
	}
	want := [][]string{{"pacman", "-Syu", "--noconfirm"}, {"dnf", "upgrade", "-y"}}
	if !reflect.DeepEqual(f.calls, want) {
		t.Fatalf("calls = %v", f.calls)
	}
}

func TestEnableMultilibVerb(t *testing.T) {
	f := &fakeSys{files: map[string][]byte{PacmanConf: []byte(pacmanConf)}}
	if err := f.helper(&bytes.Buffer{}).EnableMultilib("arch", "/etc/pacman.conf.bak"); err != nil {
		t.Fatal(err)
	}
	if string(f.writes["/etc/pacman.conf.bak"]) != pacmanConf {
		t.Fatal("backup missing")
	}
	if !strings.Contains(string(f.writes[PacmanConf]), "\n[multilib]\n") {
		t.Fatal("conf not rewritten")
	}
	if !reflect.DeepEqual(f.calls, [][]string{{"pacman", "-Sy"}}) {
		t.Fatalf("calls = %v", f.calls)
	}

	f = &fakeSys{files: map[string][]byte{PacmanConf: f.writes[PacmanConf]}}
	if err := f.helper(&bytes.Buffer{}).EnableMultilib("arch", "/b"); err != nil || len(f.calls) != 0 || len(f.writes) != 0 {
		t.Fatalf("already enabled: err=%v calls=%v writes=%v", err, f.calls, f.writes)
	}
	if err := f.helper(&bytes.Buffer{}).EnableMultilib("fedora", "/b"); err == nil {
		t.Fatal("fedora must fail")
	}
}

func TestChsh(t *testing.T) {
	f := &fakeSys{files: map[string][]byte{EtcShells: []byte("/bin/bash\n/usr/bin/fish\n")}}
	h := f.helper(&bytes.Buffer{})
	if err := h.Chsh("alice", "/usr/bin/zsh"); err == nil {
		t.Fatal("unlisted shell accepted")
	}
	if err := h.Chsh("alice", "/usr/bin/fish"); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(f.calls, [][]string{{"usermod", "-s", "/usr/bin/fish", "--", "alice"}}) {
		t.Fatalf("calls = %v", f.calls)
	}
}

func TestExecRunnerStreamsAndFixesEnv(t *testing.T) {
	var out bytes.Buffer
	run := ExecRunner(&out)
	if err := run("sh", "-c", `echo "one"; echo two >&2; echo "LC=$LC_ALL"`); err != nil {
		t.Fatal(err)
	}
	got := out.String()
	for _, want := range []string{"one\n", "two\n", "LC=C\n"} {
		if !strings.Contains(got, want) {
			t.Errorf("output %q lacks %q", got, want)
		}
	}
	if err := run("false"); err == nil {
		t.Error("exit status not propagated")
	}
	if err := run("../bin/sh"); err == nil {
		t.Error("path accepted")
	}
}

func TestWriteFileAtomicKeepsMode(t *testing.T) {
	p := filepath.Join(t.TempDir(), "c")
	if err := os.WriteFile(p, []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := WriteFileAtomic(p, []byte("y")); err != nil {
		t.Fatal(err)
	}
	st, _ := os.Stat(p)
	d, _ := os.ReadFile(p)
	if string(d) != "y" || st.Mode().Perm() != 0o600 {
		t.Fatalf("data=%q mode=%v", d, st.Mode())
	}
}
