package termrun

import (
	"os/exec"
	"reflect"
	"strings"
	"testing"
)

func TestArgvPerTerminal(t *testing.T) {
	r := Request{Command: "echo hi", KeepOpen: true}
	for bin, want := range map[string][]string{
		"kitty":          {"kitty", "sh"},
		"alacritty":      {"alacritty", "-e", "sh"},
		"wezterm":        {"wezterm", "start", "--", "sh"},
		"gnome-terminal": {"gnome-terminal", "--", "sh"},
		"/usr/bin/foot":  {"/usr/bin/foot", "sh"},
		"mystery":        {"mystery", "-e", "sh"},
	} {
		got, err := Argv(Config{Terminal: bin}, r)
		if err != nil {
			t.Fatal(err)
		}
		if !reflect.DeepEqual(got[:len(want)], want) {
			t.Errorf("%s: %v, want prefix %v", bin, got, want)
		}
		if got[len(got)-3] != "sh" || got[len(got)-2] != "echo hi" {
			t.Errorf("%s: command must be one positional arg: %v", bin, got)
		}
	}
}

func TestScriptNeverContainsTheCommand(t *testing.T) {
	cmd := `echo "a'b"; rm -rf $(whoami) ` + "`id`"
	for _, keep := range []bool{true, false} {
		s := Script(Request{Command: cmd, Cwd: "/tmp/x y", KeepOpen: keep})
		if strings.Contains(s[2], "rm") || strings.Contains(s[2], "x y") {
			t.Fatalf("script text carries data: %q", s[2])
		}
		if s[4] != cmd || s[5] != "/tmp/x y" {
			t.Fatalf("args: %q", s)
		}
		if keep != strings.Contains(s[2], "exec") {
			t.Fatalf("keepOpen=%v script %q", keep, s[2])
		}
	}
}

// The script really runs the command line verbatim and changes directory.
func TestScriptRuns(t *testing.T) {
	dir := t.TempDir()
	s := Script(Request{Command: `printf '%s;' "$PWD" 'a b' ; echo $((1+1))`, Cwd: dir})
	out, err := exec.Command(s[0], s[1:]...).CombinedOutput()
	if err != nil {
		t.Fatal(err, string(out))
	}
	if !strings.Contains(string(out), dir+";a b;2") {
		t.Fatalf("output %q", out)
	}
	s = Script(Request{Command: "true", Cwd: dir + "/missing"})
	if err := exec.Command(s[0], s[1:]...).Run(); err == nil {
		t.Fatal("a missing cwd must fail")
	}
}

func TestAdvancedTemplate(t *testing.T) {
	c := Config{Terminal: "foot", Advanced: true, Template: `$TERMINAL --app-id x -e $COMMAND`}
	got, _ := Argv(c, Request{Command: "ls", KeepOpen: false})
	if !reflect.DeepEqual(got[:4], []string{"foot", "--app-id", "x", "-e"}) || got[4] != "sh" || got[len(got)-2] != "ls" {
		t.Fatalf("%v", got)
	}
	c.Template = `$TERMINAL -e bash -c "$COMMAND"`
	got, _ = Argv(c, Request{Command: "it's", KeepOpen: false})
	if len(got) != 5 || !strings.Contains(got[4], `'it'\''s'`) || !strings.HasPrefix(got[4], "'sh' '-c'") {
		t.Fatalf("%q", got)
	}
	c.Template = "$TERMINAL"
	got, _ = Argv(c, Request{Command: "ls"})
	if got[1] != "sh" {
		t.Fatalf("template without $COMMAND falls back: %v", got)
	}
}

func TestErrorsAndHelpers(t *testing.T) {
	if _, err := Argv(Config{}, Request{Command: "x"}); err == nil {
		t.Error("no terminal")
	}
	if _, err := Argv(Config{Terminal: "kitty"}, Request{Command: "  "}); err == nil {
		t.Error("no command")
	}
	if got := Fields(`a "b c" 'd e' f\ g`); !reflect.DeepEqual(got, []string{"a", "b c", "d e", "f g"}) {
		t.Errorf("%q", got)
	}
	if ExpandHome("~/p", "/h") != "/h/p" || ExpandHome("~", "/h") != "/h" || ExpandHome("/x", "/h") != "/x" {
		t.Error("ExpandHome")
	}
}
