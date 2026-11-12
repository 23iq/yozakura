package termrun

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestPasswdShell(t *testing.T) {
	data := []byte("root:x:0:0::/root:/bin/bash\nu:x:1000:1000::/home/u:/usr/bin/fish\nuu:x:1001:1001::/home/uu:/bin/zsh\n")
	for name, want := range map[string]string{"u": "/usr/bin/fish", "uu": "/bin/zsh", "x": "", "": ""} {
		if got := PasswdShell(data, name); got != want {
			t.Errorf("%q: got %q, want %q", name, got, want)
		}
	}
}

func TestWithShell(t *testing.T) {
	argv := []string{"kitty"}
	if got := WithShell(argv, "/usr/bin/fish"); !reflect.DeepEqual(got, []string{"env", "SHELL=/usr/bin/fish", "kitty"}) {
		t.Fatalf("changed login shell: %q", got)
	}
	for _, sh := range []string{"", "fish"} {
		if got := WithShell(argv, sh); !reflect.DeepEqual(got, argv) {
			t.Errorf("shell %q: %q", sh, got)
		}
	}
	if got := WithShell(nil, "/usr/bin/fish"); got != nil {
		t.Errorf("empty argv: %q", got)
	}
}

func TestChangedShell(t *testing.T) {
	exists := func(p string) bool { return p != "/gone/fish" }
	cases := []struct{ start, now, want string }{
		{"/bin/bash", "/usr/bin/fish", "/usr/bin/fish"}, // chsh this session
		{"/bin/bash", "/bin/bash", ""},                  // no chsh: $SHELL stays, even a deliberate other one
		{"", "/usr/bin/fish", ""},                       // start unknown
		{"/bin/bash", "", ""},                           // passwd unreadable now
		{"/bin/bash", "fish", ""},                       // not absolute
		{"/bin/bash", "/gone/fish", ""},                 // the new shell does not exist
	}
	for _, c := range cases {
		if got := ChangedShell(c.start, c.now, exists); got != c.want {
			t.Errorf("start %q now %q: %q, want %q", c.start, c.now, got, c.want)
		}
	}
	if got := ChangedShell("/bin/bash", "/usr/bin/fish", nil); got != "" {
		t.Errorf("no executable check: %q", got)
	}
}

func TestIsExecutable(t *testing.T) {
	dir := t.TempDir()
	exe, plain := filepath.Join(dir, "exe"), filepath.Join(dir, "plain")
	if os.WriteFile(exe, nil, 0o755) != nil || os.WriteFile(plain, nil, 0o644) != nil {
		t.Fatal("setup")
	}
	if !IsExecutable(exe) || IsExecutable(plain) || IsExecutable(dir) || IsExecutable(filepath.Join(dir, "none")) {
		t.Fatal("executable misread")
	}
}

func TestIsTerminalEntry(t *testing.T) {
	yes := "[Desktop Entry]\nName=kitty\nCategories=System;TerminalEmulator;\nExec=kitty\n"
	no := "[Desktop Entry]\nName=Files\nCategories=System;FileManager;\n[Desktop Action x]\nCategories=TerminalEmulator\n"
	if !IsTerminalEntry(yes) || IsTerminalEntry(no) || IsTerminalEntry("") {
		t.Fatal("TerminalEmulator category misread")
	}
}
