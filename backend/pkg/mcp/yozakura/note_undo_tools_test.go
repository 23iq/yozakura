package yozakura

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

// callUndo runs the undo descriptor of a tool result.
func callUndo(t *testing.T, d Deps, m map[string]any) map[string]any {
	t.Helper()
	u, ok := m["undo"].(map[string]any)
	if !assert.True(t, ok, "no undo in %v", m) {
		return nil
	}
	args, _ := json.Marshal(u["args"])
	return structured(t, callTool(t, d, u["tool"].(string), string(args)))
}

func noteIndex(t *testing.T, dir string) map[string]any {
	t.Helper()
	var index map[string]any
	raw, _ := os.ReadFile(filepath.Join(dir, "index.json"))
	assert.NoError(t, json.Unmarshal(raw, &index))
	return index
}

func TestNotesUndo(t *testing.T) {
	d, _, _ := newDeps(t)
	dir := notesFixture(t, &d)
	md := filepath.Join(dir, "notes", "a.md")

	// append -> undo restores the previous content
	m := structured(t, callTool(t, d, "notes_append", `{"id":"Inbox","text":"call mom"}`))
	callUndo(t, d, m)
	data, _ := os.ReadFile(md)
	assert.Equal(t, "# Inbox\n\n- buy milk\n", string(data))

	// rich-text append -> the HTML comes back as it was
	m = structured(t, callTool(t, d, "notes_append", `{"id":"Recipes","text":"tea"}`))
	callUndo(t, d, m)
	data, _ = os.ReadFile(filepath.Join(dir, "notes", "b.html"))
	assert.Equal(t, "<h1>Recipes</h1><p>Pancakes &amp; syrup</p>", string(data))

	// create -> undo deletes it
	m = structured(t, callTool(t, d, "notes_create", `{"title":"Meeting"}`))
	id := m["id"].(string)
	assert.Equal(t, map[string]any{"tool": "notes_delete", "args": map[string]any{"id": id}}, m["undo"])
	callUndo(t, d, m)
	_, err := os.Stat(filepath.Join(dir, "notes", id+".md"))
	assert.True(t, os.IsNotExist(err))
	assert.Nil(t, noteIndex(t, dir)["notes"].(map[string]any)[id])

	// append with create -> undo deletes the new note too
	m = structured(t, callTool(t, d, "notes_append", `{"id":"Ideas","text":"x","create":true}`))
	assert.Equal(t, "notes_delete", m["undo"].(map[string]any)["tool"])

	// delete -> undo recreates it in place with its metadata and content
	m = structured(t, callTool(t, d, "notes_delete", `{"id":"Inbox"}`))
	assert.Equal(t, true, m["deleted"])
	_, err = os.Stat(md)
	assert.True(t, os.IsNotExist(err))
	idx := noteIndex(t, dir)
	assert.NotContains(t, idx["order"], "a")
	assert.Equal(t, float64(42), idx["extra"], "unknown fields are kept")
	r := callUndo(t, d, m)
	assert.Equal(t, true, r["recreated"])
	data, _ = os.ReadFile(md)
	assert.Equal(t, "# Inbox\n\n- buy milk\n", string(data))
	meta := noteIndex(t, dir)["notes"].(map[string]any)["a"].(map[string]any)
	assert.Equal(t, "Inbox", meta["title"])
	assert.Equal(t, "x", meta["created"])
	assert.Equal(t, true, meta["isMarkdown"])

	assert.True(t, callTool(t, d, "notes_delete", `{"id":"ghost"}`).IsError)
	assert.True(t, callTool(t, d, "notes_restore", `{"id":"../evil","content":"x","title":"t"}`).IsError, "ids are file names")
	assert.True(t, callTool(t, d, "notes_restore", `{"id":"new1","content":"x"}`).IsError, "a missing note needs its title")
	assert.NotContains(t, ReadOnlyToolNames(), "notes_delete")
}
