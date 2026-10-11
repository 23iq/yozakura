package main

import (
	"bytes"
	"reflect"
	"strings"
	"testing"

	"yozakura/backend/pkg/termrun"
)

func termTestEnv(c termrun.Config) (terminalEnv, *[]string) {
	var got []string
	return terminalEnv{
		config: func() termrun.Config { return c },
		home:   func() string { return "/home/u" },
		start:  func(argv []string) error { got = argv; return nil },
	}, &got
}

func TestTerminalRunBuildsArgv(t *testing.T) {
	env, got := termTestEnv(termrun.Config{Terminal: "alacritty"})
	var errOut bytes.Buffer
	code := runTerminal([]string{"run", "--cwd", "~/src/app", "--keep-open=false", "--", "cd x && claude; echo $(id)"}, env, &errOut)
	if code != 0 {
		t.Fatalf("exit %d: %s", code, errOut.String())
	}
	want := []string{"alacritty", "-e", "sh", "-c"}
	if !reflect.DeepEqual((*got)[:4], want) {
		t.Fatalf("argv %q", *got)
	}
	n := len(*got)
	if (*got)[n-2] != "cd x && claude; echo $(id)" || (*got)[n-1] != "/home/u/src/app" {
		t.Fatalf("positional args %q", *got)
	}
	if strings.Contains((*got)[4], "exec") {
		t.Fatalf("keep-open=false must not exec a shell: %q", (*got)[4])
	}
}

func TestTerminalRunDefaultsAndErrors(t *testing.T) {
	env, got := termTestEnv(termrun.Config{Terminal: "kitty"})
	var errOut bytes.Buffer
	if code := runTerminal([]string{"run", "htop"}, env, &errOut); code != 0 {
		t.Fatalf("exit %d: %s", code, errOut.String())
	}
	if !strings.Contains((*got)[3], "exec") {
		t.Fatalf("keep-open defaults to true: %q", *got)
	}
	for _, args := range [][]string{{"run"}, {"run", "--keep-open=maybe", "x"}, {"nope"}} {
		if code := runTerminal(args, env, &bytes.Buffer{}); code != 2 {
			t.Errorf("%v: exit %d", args, code)
		}
	}
	env.config = func() termrun.Config { return termrun.Config{} }
	if code := runTerminal([]string{"run", "x"}, env, &bytes.Buffer{}); code != 1 {
		t.Errorf("no terminal: exit %d", code)
	}
}
