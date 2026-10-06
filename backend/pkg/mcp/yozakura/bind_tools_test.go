package yozakura

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/brand"
)

func bindDeps(t *testing.T) (Deps, string) {
	t.Helper()
	d, r, _ := newDeps(t)
	d.AppDirs = []string{"../../specials/testdata/apps"}
	src, err := os.ReadFile("../../binds/testdata/binds.json")
	must(t, assert.NoError(t, err))
	d.BindsFile = filepath.Join(t.TempDir(), "binds.json")
	must(t, assert.NoError(t, os.WriteFile(d.BindsFile, src, 0o644)))
	r.bins[brand.Daemon] = true
	r.out[brand.Daemon+" config list-binds"] = `[{"modifiers":["SUPER"],"key":"P","dispatcher":"__lua","description":"Window: Pin"}]`
	return d, d.BindsFile
}

func TestBindToolsReadOnlyFlags(t *testing.T) {
	ro := ReadOnlyToolNames()
	for _, n := range []string{"binds_search", "binds_list", "binds_check", "binds_suggest"} {
		assert.Contains(t, ro, n)
	}
	for _, n := range []string{"binds_set", "binds_remove", "binds_undo"} {
		assert.NotContains(t, ro, n)
	}
}

func TestBindToolsFlow(t *testing.T) {
	d, file := bindDeps(t)
	orig, _ := os.ReadFile(file)

	res := callTool(t, d, "binds_search", `{"query":"раскладка","limit":3}`)
	must(t, assert.False(t, res.IsError, res.Text()))
	assert.Contains(t, res.Text(), `"keyboard-layout-next"`)

	res = callTool(t, d, "binds_check", `{"combo":"SUPER+P"}`)
	must(t, assert.False(t, res.IsError, res.Text()))
	assert.Contains(t, res.Text(), `"source": "compositor"`)
	assert.Contains(t, res.Text(), `"free": false`)

	res = callTool(t, d, "binds_list", `{"source":"compositor"}`)
	must(t, assert.False(t, res.IsError, res.Text()))
	assert.Contains(t, res.Text(), "Window: Pin")

	res = callTool(t, d, "binds_suggest", `{"action":"window.fullscreen","count":2}`)
	must(t, assert.False(t, res.IsError, res.Text()))
	assert.Contains(t, res.Text(), `"SUPER+F"`)

	res = callTool(t, d, "binds_set", `{"combo":"SUPER+P","action":"window.fullscreen"}`)
	assert.True(t, res.IsError, "a compositor combo is refused")

	res = callTool(t, d, "binds_set", `{"combo":"SUPER+F","action":"window.fullscreen"}`)
	must(t, assert.False(t, res.IsError, res.Text()))
	var set struct {
		Undo struct {
			Tool string
			Args map[string]string
		}
	}
	must(t, assert.NoError(t, json.Unmarshal([]byte(res.Text()), &set)))
	assert.Equal(t, "binds_undo", set.Undo.Tool)

	undoArgs, _ := json.Marshal(set.Undo.Args)
	res = callTool(t, d, set.Undo.Tool, string(undoArgs))
	must(t, assert.False(t, res.IsError, res.Text()))
	now, _ := os.ReadFile(file)
	assert.Equal(t, string(orig), string(now))

	res = callTool(t, d, "binds_remove", `{"combo":"SUPER+Q"}`)
	must(t, assert.False(t, res.IsError, res.Text()))
	assert.Contains(t, res.Text(), `"undo"`)
}

func must(t *testing.T, ok bool) {
	t.Helper()
	if !ok {
		t.FailNow()
	}
}
