package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/binds"
	"yozakura/backend/pkg/yozd/ipc"
)

func testBindsEnv(t *testing.T) (bindsEnv, string) {
	t.Helper()
	cat, err := binds.LoadCatalog(filepath.Join("..", "..", ".."))
	if err != nil {
		t.Fatal(err)
	}
	src, err := os.ReadFile(filepath.Join("..", "..", "pkg", "binds", "testdata", "binds.json"))
	if err != nil {
		t.Fatal(err)
	}
	file := filepath.Join(t.TempDir(), "binds.json")
	if err := os.WriteFile(file, src, 0o644); err != nil {
		t.Fatal(err)
	}
	adv := &binds.Advisor{Catalog: cat, File: file, AppID: "yozakura",
		Compositor: func() ([]ipc.Bind, error) {
			return []ipc.Bind{{Modifiers: []string{"SUPER"}, Key: "P", Description: "Window: Pin"}}, nil
		}}
	return bindsEnv{advisor: func() (*binds.Advisor, error) { return adv, nil }}, file
}

func runBindsT(t *testing.T, env bindsEnv, args ...string) (string, string, int) {
	t.Helper()
	var out, errOut bytes.Buffer
	code := runBinds(args, env, &out, &errOut)
	return out.String(), errOut.String(), code
}

func TestBindsCLI(t *testing.T) {
	env, file := testBindsEnv(t)
	orig, _ := os.ReadFile(file)

	if out, _, code := runBindsT(t, env, "help"); code != 0 || !strings.Contains(out, "binds search") {
		t.Fatalf("help: %d %s", code, out)
	}
	if out, _, code := runBindsT(t, env, "search", "закрыть", "окно"); code != 0 || !strings.Contains(out, "window.close") || !strings.Contains(out, "[SUPER+Q]") {
		t.Fatalf("search: %s", out)
	}
	if out, _, _ := runBindsT(t, env, "check", "super+p"); !strings.Contains(out, "is taken") || !strings.Contains(out, "Window: Pin") {
		t.Fatalf("check: %s", out)
	}
	if out, _, _ := runBindsT(t, env, "check", "SUPER+F"); !strings.Contains(out, "SUPER+F is free") {
		t.Fatalf("check free: %s", out)
	}
	if out, _, _ := runBindsT(t, env, "list", "--source", "compositor"); strings.TrimSpace(out) != "compositor  SUPER+P                Window: Pin" {
		t.Fatalf("list: %q", out)
	}
	if out, _, _ := runBindsT(t, env, "suggest", "window.fullscreen", "--count", "1"); !strings.Contains(out, "SUPER+F") {
		t.Fatalf("suggest: %s", out)
	}
	out, errOut, code := runBindsT(t, env, "set", "SUPER+B", "apps.launch", "app=firefox")
	if code != 0 || !strings.Contains(out, "added custom bind SUPER+B") {
		t.Fatalf("set: %s %s", out, errOut)
	}
	token := ""
	for _, line := range strings.Split(out, "\n") {
		if cli, ok := strings.CutPrefix(line, "Undo: "); ok {
			token = cli[strings.LastIndex(cli, " ")+1:]
		}
	}
	if _, errOut, code := runBindsT(t, env, "undo", token); code != 0 {
		t.Fatalf("undo: %s", errOut)
	}
	if now, _ := os.ReadFile(file); string(now) != string(orig) {
		t.Fatal("undo must restore binds.json")
	}
	if _, errOut, code := runBindsT(t, env, "set", "SUPER+P", "window.close"); code == 0 || !strings.Contains(errOut, "compositor") {
		t.Fatalf("compositor conflict: %s", errOut)
	}
	if _, errOut, code := runBindsT(t, env, "set", "SUPER+B", "apps.launch", "firefox"); code == 0 || !strings.Contains(errOut, "key=value") {
		t.Fatalf("bad arg: %s", errOut)
	}
	if out, _, code := runBindsT(t, env, "rm", "SUPER+Q", "--json"); code != 0 || !strings.Contains(out, `"tool": "binds_undo"`) {
		t.Fatalf("rm: %s", out)
	}
}
