package termrun

import (
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

func TestWithLoginShell(t *testing.T) {
	argv := []string{"kitty"}
	if got := WithLoginShell(argv, "/usr/bin/fish", "/bin/bash"); !reflect.DeepEqual(got, []string{"env", "SHELL=/usr/bin/fish", "kitty"}) {
		t.Fatalf("changed login shell: %q", got)
	}
	for _, c := range [][2]string{{"/bin/bash", "/bin/bash"}, {"", "/bin/bash"}, {"fish", "/bin/bash"}} {
		if got := WithLoginShell(argv, c[0], c[1]); !reflect.DeepEqual(got, argv) {
			t.Errorf("login %q current %q: %q", c[0], c[1], got)
		}
	}
	if got := WithLoginShell(nil, "/usr/bin/fish", ""); got != nil {
		t.Errorf("empty argv: %q", got)
	}
}

func TestIsTerminalEntry(t *testing.T) {
	yes := "[Desktop Entry]\nName=kitty\nCategories=System;TerminalEmulator;\nExec=kitty\n"
	no := "[Desktop Entry]\nName=Files\nCategories=System;FileManager;\n[Desktop Action x]\nCategories=TerminalEmulator\n"
	if !IsTerminalEntry(yes) || IsTerminalEntry(no) || IsTerminalEntry("") {
		t.Fatal("TerminalEmulator category misread")
	}
}
