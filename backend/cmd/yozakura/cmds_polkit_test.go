package main

import (
	"errors"
	"strings"
	"testing"
)

type polkitFake struct {
	shell   bool
	command string
	ran     []string
}

func (f *polkitFake) env() polkitEnv {
	return polkitEnv{
		shellAgent: func() bool { return f.shell },
		command:    func() string { return f.command },
		lookPath: func(name string) (string, error) {
			if name == "missing" {
				return "", errors.New("not found")
			}
			if strings.HasPrefix(name, "/") {
				return name, nil
			}
			return "/usr/bin/" + name, nil
		},
		exec: func(bin string, argv []string) error {
			f.ran = append([]string{bin}, argv...)
			return nil
		},
	}
}

func TestPolkitFallbackStaysOutOfTheShellAgentsWay(t *testing.T) {
	f := &polkitFake{shell: true, command: "/usr/lib/hyprpolkitagent/hyprpolkitagent"}
	var errb strings.Builder
	if code := runPolkitFallback(nil, f.env(), &errb); code != 0 || f.ran != nil {
		t.Fatalf("shell agent on: exit %d, ran %v", code, f.ran)
	}
}

func TestPolkitFallbackStartsTheInstalledAgent(t *testing.T) {
	f := &polkitFake{command: "systemctl --user start hyprpolkitagent"}
	var errb strings.Builder
	if code := runPolkitFallback(nil, f.env(), &errb); code != 0 {
		t.Fatalf("exit %d: %s", code, errb.String())
	}
	if got := strings.Join(f.ran, " "); got != "/usr/bin/systemctl systemctl --user start hyprpolkitagent" {
		t.Fatalf("ran %q", got)
	}
}

func TestPolkitFallbackFailures(t *testing.T) {
	for _, c := range []struct {
		args    []string
		command string
		code    int
	}{
		{nil, "", 1},
		{nil, "missing --flag", 1},
		{[]string{"extra"}, "/x/agent", 2},
	} {
		f := &polkitFake{command: c.command}
		var errb strings.Builder
		if code := runPolkitFallback(c.args, f.env(), &errb); code != c.code || f.ran != nil || errb.Len() == 0 {
			t.Errorf("%v %q: exit %d (want %d), ran %v, stderr %q", c.args, c.command, code, c.code, f.ran, errb.String())
		}
	}
}

func TestBootstrapStartsTheFallbackVerb(t *testing.T) {
	niri := bootstrapBody(niriConfig, "/opt/bin/yozakura", "/opt/bin/yozakura polkit-fallback")
	if !strings.Contains(niri, `spawn-at-startup "/opt/bin/yozakura" "polkit-fallback"`+"\n") {
		t.Fatalf("niri bootstrap:\n%s", niri)
	}
	mango := bootstrapBody(mangoConfig, "/opt/bin/yozakura", "/opt/bin/yozakura polkit-fallback")
	if !strings.Contains(mango, "exec-once = /opt/bin/yozakura polkit-fallback\n") {
		t.Fatalf("mango bootstrap:\n%s", mango)
	}
}
