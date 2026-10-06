package tasks

import (
	"encoding/json"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestDetectCheck(t *testing.T) {
	cases := []struct {
		files map[string]string
		want  string
	}{
		{map[string]string{"Makefile": "build:\n\tgo build\ncheck: lint test\n\t@true\n"}, "make check"},
		{map[string]string{"Makefile": ".PHONY: test\ntest:\n\tgo test\n", "go.mod": "module x"}, "make test"},
		{map[string]string{"Makefile": "X := check:\nbuild:\n", "go.mod": "module x"}, "go test ./..."},
		{map[string]string{"package.json": `{"scripts":{"test":"vitest"}}`, "pnpm-lock.yaml": ""}, "pnpm test"},
		{map[string]string{"package.json": `{"scripts":{"test":"echo \"Error: no test specified\" && exit 1"}}`}, ""},
		{map[string]string{"Cargo.toml": "[package]"}, "cargo test"},
		{map[string]string{"README": "x"}, ""},
	}
	for i, c := range cases {
		dir := t.TempDir()
		for name, body := range c.files {
			writeFile(t, filepath.Join(dir, name), body)
		}
		if got := DetectCheck(dir); got != c.want {
			t.Errorf("case %d: %q want %q", i, got, c.want)
		}
	}
}

func TestRunCheck(t *testing.T) {
	dir := t.TempDir()
	if cr := runCheck(dir, "echo ok", time.Minute, time.Now); cr.Status != CheckPass || !strings.Contains(cr.OutputTail, "ok") {
		t.Fatalf("pass: %+v", cr)
	}
	if cr := runCheck(dir, "echo bad >&2; exit 4", time.Minute, time.Now); cr.Status != CheckFail || cr.ExitCode != 4 || !strings.Contains(cr.OutputTail, "bad") {
		t.Fatalf("fail: %+v", cr)
	}
	if cr := runCheck(dir, "sleep 5", 200*time.Millisecond, time.Now); cr.Status != CheckTimeout || cr.DurationMs > 4000 {
		t.Fatalf("timeout: %+v", cr)
	}
	if cr := runCheck(dir, " ", time.Minute, time.Now); cr.Status != CheckSkipped {
		t.Fatalf("skip: %+v", cr)
	}
	long := runCheck(dir, "yes x | head -c 20000", time.Minute, time.Now)
	if len(long.OutputTail) != checkTailBytes {
		t.Fatalf("tail size %d", len(long.OutputTail))
	}
}

func TestTemplates(t *testing.T) {
	global := t.TempDir()
	project := testRepo(t)
	d := TemplateDirs{Bundled: bundledTemplates(t), Global: global}
	writeFile(t, filepath.Join(global, "review.md"), "---\nname: My review\ndescription: mine\n---\nGlobal {{input}}")
	writeFile(t, filepath.Join(ProjectTemplateDir(project), "deploy.md"), "Deploy {{branch}} of {{project}} {{unknown}}")
	list := ListTemplates(d, project)
	ids := map[string]Template{}
	for _, tp := range list {
		ids[tp.ID] = tp
	}
	for _, id := range []string{"review", "tests", "fix-check", "explain", "refactor", "deploy"} {
		if _, ok := ids[id]; !ok {
			t.Errorf("template %s missing", id)
		}
	}
	if ids["review"].Source != "global" || ids["review"].Name != "My review" || ids["review"].Body != "" {
		t.Fatalf("override: %+v", ids["review"])
	}
	if ids["explain"].Mode != "plan" || ids["explain"].Description == "" {
		t.Fatalf("front matter: %+v", ids["explain"])
	}
	tp, err := GetTemplate(d, project, "deploy")
	if err != nil || tp.Source != "project" {
		t.Fatalf("get: %+v %v", tp, err)
	}
	out := Render(tp.Body, nil, project, nil)
	if out != "Deploy main of proj {{unknown}}" {
		t.Fatalf("render %q", out)
	}
	if got := Render("{{ input }}/{{selection}}", map[string]string{"input": "a"}, project, nil); got != "a/" {
		t.Fatalf("vars %q", got)
	}
	if _, err := GetTemplate(d, project, "../etc/passwd"); err == nil {
		t.Fatal("path traversal accepted")
	}
}

func TestGitSummary(t *testing.T) {
	repo := testRepo(t)
	writeFile(t, filepath.Join(repo, "README.md"), "changed\n")
	writeFile(t, filepath.Join(repo, "new.txt"), "x\n")
	writeFile(t, filepath.Join(repo, "staged.txt"), "x\n")
	run(t, repo, "git", "add", "staged.txt")
	s := Summarize(repo)
	if !s.IsRepo || s.Branch != "main" || s.Changed != 3 || s.Staged != 1 || s.Unstaged != 1 || s.Untracked != 1 || s.Head == "" {
		t.Fatalf("summary: %+v", s)
	}
	if s := Summarize(t.TempDir()); s.IsRepo {
		t.Fatal("not a repo")
	}
	var parsed GitSummary
	parseStatusV2("# branch.oid abc\x00# branch.head (detached)\x00# branch.upstream origin/main\x00# branch.ab +2 -3\x00", &parsed)
	if !parsed.Detached || parsed.Branch != "" || parsed.Ahead != 2 || parsed.Behind != 3 {
		t.Fatalf("parsed: %+v", parsed)
	}
}

func TestProjectConfig(t *testing.T) {
	e := newEnv(t, nil)
	writeFile(t, filepath.Join(e.repo, "go.mod"), "module x\n")
	writeFile(t, filepath.Join(e.repo, "AGENTS.md"), "# rules\n")
	v, err := e.m.SetProject(ProjectPatch{Dir: filepath.Join(e.repo, "."), ResetCheck: true})
	if err != nil {
		t.Fatal(err)
	}
	if v.CheckCommand != nil || v.EffectiveCheck != "go test ./..." || v.SuggestedCheck != "go test ./..." || !v.IsGit ||
		v.MaxAttempts != 2 || v.MergeMode != "squash" || v.Instructions != "AGENTS.md" {
		t.Fatalf("view: %+v", v)
	}
	bad := "rebase"
	if _, err := e.m.SetProject(ProjectPatch{Dir: e.repo, MergeMode: &bad}); err == nil {
		t.Fatal("bad merge mode accepted")
	}
	cmd, three := "make check", 3
	v, _ = e.m.SetProject(ProjectPatch{Dir: e.repo, CheckCommand: &cmd, MaxAttempts: &three})
	if v.EffectiveCheck != "make check" || v.MaxAttempts != 3 {
		t.Fatalf("set: %+v", v)
	}
	data, _ := json.Marshal(v)
	if !strings.Contains(string(data), `"checkCommand":"make check"`) {
		t.Fatalf("json: %s", data)
	}
	if s := e.m.Configure(Settings{MaxParallel: 0}); s.MaxParallel != 2 || s.LimitBackoff != 1800 {
		t.Fatalf("defaults: %+v", s)
	}
}
