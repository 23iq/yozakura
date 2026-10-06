package main

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"yozakura/backend/pkg/extrascatalog"
	"yozakura/backend/pkg/svc/extras"
	"yozakura/backend/pkg/sysinstall"
)

type sysFake struct {
	calls [][]string
	files map[string]string
}

func newSysFake(t *testing.T) (*sysFake, sysEnv) {
	t.Helper()
	f := &sysFake{files: map[string]string{
		"/etc/shells": "/bin/bash\n/usr/bin/fish\n",
	}}
	read := func(p string) ([]byte, error) {
		if d, ok := f.files[p]; ok {
			return []byte(d), nil
		}
		return nil, os.ErrNotExist
	}
	env := sysEnv{
		euid:   0,
		getenv: func(k string) string { return map[string]string{"PKEXEC_UID": "1000"}[k] },
		lookup: func(uid string) (string, error) {
			if uid == "1000" {
				return "alice", nil
			}
			return "", errors.New("no user")
		},
		catalog:  extrascatalog.Load,
		platform: func() extras.Platform { return extras.Platform{Distro: "arch", GPU: "nvidia"} },
		helper: sysinstall.Helper{
			Out: &bytes.Buffer{},
			Run: func(name string, args ...string) error {
				f.calls = append(f.calls, append([]string{name}, args...))
				return nil
			},
			ReadFile:  read,
			WriteFile: func(string, []byte) error { return nil },
			RealPath:  func(p string) (string, error) { return p, nil },
		},
	}
	return f, env
}

func runSysT(args []string, env sysEnv) (int, string) {
	var out, errOut bytes.Buffer
	code := runSys(args, env, &out, &errOut)
	return code, errOut.String()
}

func TestSysRefusesNonRoot(t *testing.T) {
	f, env := newSysFake(t)
	env.euid = 1000
	if code, msg := runSysT([]string{"upgrade"}, env); code != 1 || !strings.Contains(msg, "root") {
		t.Fatalf("code=%d msg=%q", code, msg)
	}
	if len(f.calls) != 0 {
		t.Fatal("ran as non-root")
	}
}

func TestSysInstallUsesEmbeddedCatalog(t *testing.T) {
	f, env := newSysFake(t)
	if code, msg := runSysT([]string{"install", "ollama"}, env); code != 0 {
		t.Fatalf("code=%d msg=%q", code, msg)
	}
	want := [][]string{{"pacman", "-S", "--needed", "--noconfirm", "--", "ollama-cuda"}, {"systemctl", "enable", "--now", "--", "ollama"}}
	if !reflect.DeepEqual(f.calls, want) {
		t.Fatalf("calls = %v", f.calls)
	}
}

func TestDefaultSysEnvEmbedsCatalog(t *testing.T) {
	t.Setenv("YOZAKURA_SHELL", t.TempDir())
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	c, err := defaultSysEnv(&bytes.Buffer{}).catalog()
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := c.Get("ollama"); !ok {
		t.Fatal("embedded catalog lacks ollama")
	}
}

func TestSysInstallRejectsBadIds(t *testing.T) {
	f, env := newSysFake(t)
	for _, args := range [][]string{{"install"}, {"install", "--overwrite=*"}, {"install", "nope"}, {"install", "ollama", "oh-my-posh"}} {
		if code, _ := runSysT(args, env); code == 0 {
			t.Errorf("%v accepted", args)
		}
	}
	if len(f.calls) != 0 {
		t.Fatalf("ran %v", f.calls)
	}
}

func TestSysChshOnlyInvoker(t *testing.T) {
	f, env := newSysFake(t)
	if code, msg := runSysT([]string{"chsh", "root", "/usr/bin/fish"}, env); code != 1 || !strings.Contains(msg, "invoking user") {
		t.Fatalf("code=%d msg=%q", code, msg)
	}
	if code, _ := runSysT([]string{"chsh", "alice", "/tmp/evil"}, env); code != 1 {
		t.Fatal("unlisted shell accepted")
	}
	noPkexec := env
	noPkexec.getenv = func(string) string { return "" }
	if code, _ := runSysT([]string{"chsh", "alice", "/usr/bin/fish"}, noPkexec); code != 1 {
		t.Fatal("chsh without PKEXEC_UID accepted")
	}
	if len(f.calls) != 0 {
		t.Fatalf("ran %v", f.calls)
	}
	if code, msg := runSysT([]string{"chsh", "alice", "/usr/bin/fish"}, env); code != 0 {
		t.Fatalf("code=%d msg=%q", code, msg)
	}
	if !reflect.DeepEqual(f.calls, [][]string{{"usermod", "-s", "/usr/bin/fish", "--", "alice"}}) {
		t.Fatalf("calls = %v", f.calls)
	}
}

func TestSysVerbs(t *testing.T) {
	f, env := newSysFake(t)
	for _, args := range [][]string{{"upgrade", "x"}, {"enable-multilib", "x"}, {"rm"}, {"chsh", "alice"}} {
		if code, _ := runSysT(args, env); code != 2 {
			t.Errorf("%v: code %d", args, code)
		}
	}
	if code, _ := runSysT([]string{"upgrade"}, env); code != 0 || !reflect.DeepEqual(f.calls, [][]string{{"pacman", "-Syu", "--noconfirm"}}) {
		t.Fatalf("upgrade calls = %v", f.calls)
	}
}

// The privileged helper survives its parent (the daemon) going away: with
// SIGPIPE ignored a write to the closed output pipe is an error, not death,
// so pacman (whose output it relays) is never killed mid-transaction.
func TestSysSurvivesClosedStdout(t *testing.T) {
	if os.Getenv("YZ_SIGPIPE_CHILD") == "1" {
		ignoreSIGPIPE()
		for i := 0; i < 3; i++ {
			fmt.Println("progress line")
			time.Sleep(5 * time.Millisecond)
		}
		_ = os.WriteFile(os.Getenv("YZ_SIGPIPE_MARK"), []byte("alive"), 0o644)
		os.Exit(0)
	}
	mark := filepath.Join(t.TempDir(), "mark")
	pr, pw, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	pr.Close() // the reader (the daemon) is gone
	cmd := exec.Command(os.Args[0], "-test.run=^TestSysSurvivesClosedStdout$")
	cmd.Env = append(os.Environ(), "YZ_SIGPIPE_CHILD=1", "YZ_SIGPIPE_MARK="+mark)
	cmd.Stdout = pw
	if err := cmd.Run(); err != nil {
		t.Fatalf("child died: %v", err)
	}
	pw.Close()
	if b, _ := os.ReadFile(mark); string(b) != "alive" {
		t.Fatal("child did not finish after its stdout reader went away")
	}
}
