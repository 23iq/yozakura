package yozakura

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

func notesFixture(t *testing.T, d *Deps) string {
	dir := filepath.Join(t.TempDir(), "yozakura-notes")
	d.NotesDir = dir
	assert.NoError(t, os.MkdirAll(filepath.Join(dir, "notes"), 0o755))
	index := `{"order":["a","b"],"notes":{"a":{"title":"Inbox","created":"x","modified":"x","isMarkdown":true},` +
		`"b":{"title":"Recipes","created":"y","modified":"y","isMarkdown":false}},"extra":42}`
	assert.NoError(t, os.WriteFile(filepath.Join(dir, "index.json"), []byte(index), 0o644))
	assert.NoError(t, os.WriteFile(filepath.Join(dir, "notes", "a.md"), []byte("# Inbox\n\n- buy milk\n"), 0o644))
	assert.NoError(t, os.WriteFile(filepath.Join(dir, "notes", "b.html"), []byte("<h1>Recipes</h1><p>Pancakes &amp; syrup</p>"), 0o644))
	return dir
}

func TestNotesSearchAndRead(t *testing.T) {
	d, _, _ := newDeps(t)
	notesFixture(t, &d)
	m := structured(t, callTool(t, d, "notes_search", `{"query":"syrup"}`))
	notes := m["notes"].([]any)
	assert.Len(t, notes, 1)
	assert.Equal(t, "Recipes", notes[0].(map[string]any)["title"])
	assert.Contains(t, notes[0].(map[string]any)["snippet"], "Pancakes & syrup")

	m = structured(t, callTool(t, d, "notes_search", `{}`))
	assert.Len(t, m["notes"], 2)

	m = structured(t, callTool(t, d, "notes_read", `{"id":"recipes"}`))
	assert.Equal(t, "Recipes\nPancakes & syrup", m["content"])
	assert.True(t, callTool(t, d, "notes_read", `{"id":"ghost"}`).IsError)
}

func TestNotesCreateAndAppend(t *testing.T) {
	d, _, _ := newDeps(t)
	dir := notesFixture(t, &d)

	m := structured(t, callTool(t, d, "notes_append", `{"id":"Inbox","text":"call  mom","bullet":true}`))
	assert.Equal(t, "- call mom", m["appended"])
	data, _ := os.ReadFile(filepath.Join(dir, "notes", "a.md"))
	assert.Equal(t, "# Inbox\n\n- buy milk\n- call mom\n", string(data))

	structured(t, callTool(t, d, "notes_append", `{"id":"b","text":"<b>tea</b>"}`))
	data, _ = os.ReadFile(filepath.Join(dir, "notes", "b.html"))
	assert.True(t, strings.HasSuffix(string(data), "<p>&lt;b&gt;tea&lt;/b&gt;</p>"))

	assert.True(t, callTool(t, d, "notes_append", `{"id":"Ideas","text":"x"}`).IsError)
	m = structured(t, callTool(t, d, "notes_append", `{"id":"Ideas","text":"x","create":true}`))
	assert.Equal(t, true, m["created"])

	m = structured(t, callTool(t, d, "notes_create", `{"title":"Meeting","content":"Agenda"}`))
	id := m["id"].(string)
	data, _ = os.ReadFile(filepath.Join(dir, "notes", id+".md"))
	assert.Equal(t, "# Meeting\n\nAgenda\n", string(data))

	var index map[string]any
	raw, _ := os.ReadFile(filepath.Join(dir, "index.json"))
	assert.NoError(t, json.Unmarshal(raw, &index))
	order := index["order"].([]any)
	assert.Equal(t, id, order[0])
	assert.Len(t, order, 4)
	assert.Equal(t, float64(42), index["extra"], "unknown fields are kept")
	meta := index["notes"].(map[string]any)[id].(map[string]any)
	assert.Equal(t, true, meta["isMarkdown"])
	assert.Equal(t, "2026-10-05T12:30:45.000Z", meta["created"])
	assert.True(t, callTool(t, d, "notes_create", `{"title":" "}`).IsError)
}

func TestNotesEmptyFolder(t *testing.T) {
	d, _, _ := newDeps(t)
	d.NotesDir = filepath.Join(t.TempDir(), "none")
	m := structured(t, callTool(t, d, "notes_search", `{"query":"x"}`))
	assert.Len(t, m["notes"], 0)
	structured(t, callTool(t, d, "notes_create", `{"title":"First"}`))
	m = structured(t, callTool(t, d, "notes_search", `{}`))
	assert.Len(t, m["notes"], 1)
}
