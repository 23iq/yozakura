package mcp

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestParseTOML(t *testing.T) {
	doc, err := ParseTOML(`
title = "x" # trailing comment
n = 1_000
f = -2.5e3
hex = 0x1F
yes = true
date = 1979-05-27T07:32:00Z
lit = 'C:\no\escape'
ml = """
line1
line2"""
mll = '''raw\n'''
cont = """a \
       b"""
arr = [1, [2, 3], "four", { k = "v" },]
a.b.c = 7
"q.k" = 1

[t]
x = { y = 1, z = [true, false] }

[[items]]
id = 1
[[items]]
id = 2
[items.sub]
v = "nested"
`)
	assert.NoError(t, err)
	assert.Equal(t, "x", doc["title"])
	assert.Equal(t, int64(1000), doc["n"])
	assert.Equal(t, -2500.0, doc["f"])
	assert.Equal(t, int64(31), doc["hex"])
	assert.Equal(t, true, doc["yes"])
	assert.Equal(t, "1979-05-27T07:32:00Z", doc["date"])
	assert.Equal(t, `C:\no\escape`, doc["lit"])
	assert.Equal(t, "line1\nline2", doc["ml"])
	assert.Equal(t, `raw\n`, doc["mll"])
	assert.Equal(t, "a b", doc["cont"])
	assert.Equal(t, []any{int64(1), []any{int64(2), int64(3)}, "four", map[string]any{"k": "v"}}, doc["arr"])
	assert.Equal(t, int64(7), doc["a"].(map[string]any)["b"].(map[string]any)["c"])
	assert.Equal(t, int64(1), doc["q.k"])
	assert.Equal(t, []any{true, false}, doc["t"].(map[string]any)["x"].(map[string]any)["z"])
	items := doc["items"].([]any)
	assert.Len(t, items, 2)
	assert.Equal(t, "nested", items[1].(map[string]any)["sub"].(map[string]any)["v"])
}

func TestParseTOMLErrors(t *testing.T) {
	for _, src := range []string{
		"a = ",
		"a = \"open",
		"a = 1\na = 2",
		"[t\nx=1",
		"a = [1 2]",
		"a = 1 b = 2",
	} {
		_, err := ParseTOML(src)
		assert.Error(t, err, src)
	}
}

func TestStripJSONC(t *testing.T) {
	in := `{
  // c1
  "a": "http://x//y", /* block */ "b": [1, 2,],
  "c": {"d": "e\"//", },
}`
	var v map[string]any
	assert.NoError(t, json.Unmarshal([]byte(StripJSONC(in)), &v))
	assert.Equal(t, "http://x//y", v["a"])
	assert.Equal(t, "e\"//", v["c"].(map[string]any)["d"])
	assert.Len(t, v["b"], 2)
}

func TestImportClaude(t *testing.T) {
	list, err := ImportClaude("testdata/claude.json", false)
	assert.NoError(t, err)
	byName := map[string]ServerSpec{}
	for _, s := range list {
		byName[s.Name] = s
	}
	assert.Len(t, list, 4)
	fs := byName["filesystem"]
	assert.Equal(t, TransportStdio, fs.Transport)
	assert.Equal(t, "npx", fs.Command)
	assert.Equal(t, SourceClaude, fs.Source)
	assert.Equal(t, "1", fs.Env["DEBUG"])
	assert.Equal(t, TransportHTTP, byName["remote-docs"].Transport)
	assert.Equal(t, TransportSSE, byName["legacy"].Transport)
	db := byName["db"]
	assert.Equal(t, SourceClaudeProject, db.Source)
	assert.Equal(t, "/home/user/proj-b", db.Project)
	assert.Equal(t, []string{"--ro"}, db.Args)
}

func TestImportClaudeProjectMCPJSON(t *testing.T) {
	dir := t.TempDir()
	proj := filepath.Join(dir, "p")
	assert.NoError(t, os.MkdirAll(proj, 0o755))
	assert.NoError(t, os.WriteFile(filepath.Join(proj, ".mcp.json"), []byte(`{"mcpServers":{"pj":{"command":"pj-mcp"}}}`), 0o644))
	cj := filepath.Join(dir, "claude.json")
	assert.NoError(t, os.WriteFile(cj, []byte(`{"projects":{"`+proj+`":{}}}`), 0o644))
	list, err := ImportClaude(cj, true)
	assert.NoError(t, err)
	assert.Len(t, list, 1)
	assert.Equal(t, "pj", list[0].Name)
	assert.Equal(t, proj, list[0].Project)
}

func TestImportCodex(t *testing.T) {
	t.Setenv("YZ_TEST_TOKEN", "tok")
	list, err := ImportCodex("testdata/codex.toml")
	assert.NoError(t, err)
	byName := map[string]ServerSpec{}
	for _, s := range list {
		byName[s.Name] = s
	}
	assert.Len(t, list, 5)
	s := byName["search"]
	assert.Equal(t, []string{"--index", `C:\literal\path`, "--threads", "4"}, s.Args)
	assert.Equal(t, "k-123", s.Env["SEARCH_KEY"])
	assert.Equal(t, "vé", s.Env["QUOTED.KEY"])
	assert.True(t, s.Enabled)
	off := byName["off"]
	assert.False(t, off.Enabled)
	assert.Equal(t, map[string]string{"A": "1", "B": "two"}, off.Env)
	docs := byName["docs"]
	assert.Equal(t, TransportHTTP, docs.Transport)
	assert.Equal(t, "core", docs.Headers["X-Team"])
	assert.Equal(t, "Bearer tok", docs.Headers["Authorization"])
	assert.Equal(t, "\nmulti", "\n"+byName["dotted.name"].Command)
}

func TestImportOpencode(t *testing.T) {
	list, err := ImportOpencode("testdata/opencode")
	assert.NoError(t, err)
	byName := map[string]ServerSpec{}
	for _, s := range list {
		byName[s.Name] = s
	}
	assert.Len(t, list, 3)
	lt := byName["local-tool"]
	assert.Equal(t, "bun", lt.Command)
	assert.Equal(t, []string{"x", "local-tool-mcp"}, lt.Args)
	assert.False(t, lt.Enabled, "jsonc override disables it")
	assert.Equal(t, "t", lt.Env["TOKEN"])
	web := byName["web"]
	assert.Equal(t, TransportHTTP, web.Transport)
	assert.Equal(t, "http://not-a-comment", web.Headers["X-Key"])
}

func TestImportMergeAndRedaction(t *testing.T) {
	res := Import(ImportOptions{
		Claude: true, Codex: true, Opencode: true,
		Home:        t.TempDir(),
		ClaudeJSON:  "testdata/claude.json",
		CodexTOML:   "testdata/codex.toml",
		OpencodeDir: "testdata/opencode",
	})
	assert.Empty(t, res.Errors)
	names := []string{}
	for _, s := range res.Servers {
		names = append(names, s.Source+":"+s.Name)
	}
	// claude first, then claude-project, codex, opencode; sorted by name inside.
	assert.Equal(t, []string{
		"claude:filesystem", "claude:legacy", "claude:remote-docs", "claude-project:db",
		"codex:docs", "codex:dotted.name", "codex:off", "codex:search",
		"opencode:local-tool", "opencode:web",
	}, names)
	dups := map[string]string{}
	for _, d := range res.Duplicates {
		dups[d.Source+":"+d.Name] = d.KeptBy
	}
	assert.Equal(t, map[string]string{"codex:filesystem": "claude", "opencode:search": "codex"}, dups)

	for _, s := range res.Servers {
		data, _ := json.Marshal(s.Public())
		str := string(data)
		assert.NotContains(t, str, "secret")
		assert.NotContains(t, str, "Bearer")
		assert.NotContains(t, str, "k-123")
	}
	var docs Public
	for _, s := range res.Servers {
		if s.Name == "remote-docs" {
			docs = s.Public()
		}
	}
	assert.Equal(t, []string{"Authorization"}, docs.HeaderKeys)
	assert.True(t, strings.HasSuffix(docs.URL, "?…"))
}

func TestImportMissingFilesAreSilent(t *testing.T) {
	home := t.TempDir()
	t.Setenv("CODEX_HOME", "")
	t.Setenv("XDG_CONFIG_HOME", "")
	res := Import(ImportOptions{Claude: true, Codex: true, Opencode: true, Home: home})
	assert.Empty(t, res.Servers)
	assert.Empty(t, res.Errors)
}

func TestImportReportsBrokenFiles(t *testing.T) {
	dir := t.TempDir()
	bad := filepath.Join(dir, "bad.toml")
	assert.NoError(t, os.WriteFile(bad, []byte("[mcp_servers.x\n"), 0o644))
	res := Import(ImportOptions{Codex: true, Home: dir, CodexTOML: bad})
	assert.Len(t, res.Errors, 1)
	assert.Contains(t, res.Errors[0], "bad.toml")
}
