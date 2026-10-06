package yozakura

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"regexp"
	"strings"

	"yozakura/backend/pkg/fsutil"
	"yozakura/backend/pkg/mcp"
)

// notes_delete and notes_restore: deleting a note (like the Notes tab: the
// file and its index entry go) and writing a note's whole content back,
// which is the undo of notes_append and notes_delete.

// maxUndoContent caps the note content carried in an undo (bigger notes
// get no undo rather than a huge tool argument).
const maxUndoContent = 256 << 10

var noteIDPattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`)

func noteUndoTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("notes_delete", "Delete note",
			`Delete a note (by id or title) from the Notes tab. Ask the user first. The result's undo (notes_restore) brings it back with the same content.`,
			`{"type":"object","properties":{"id":{"type":"string","description":"Note id or title."}},"required":["id"],"additionalProperties":false}`,
			toolOpts{destructive: true}, d.notesDelete),
		define("notes_restore", "Restore note",
			`Write a note's whole content back (the undo of notes_append and notes_delete): "content" is the raw file content (markdown, or HTML for rich-text notes). A deleted note is recreated with "title", "markdown" and "created".`,
			`{"type":"object","properties":{"id":{"type":"string"},"content":{"type":"string"},"title":{"type":"string"},"markdown":{"type":"boolean","default":true},"created":{"type":"string"}},"required":["id","content"],"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.notesRestore),
	}
}

// restoreUndo is a notes_restore undo with the note's current content, or
// nil when the content is too big to carry.
func restoreUndo(id string, m noteMeta, content []byte, withMeta bool) map[string]any {
	if len(content) > maxUndoContent {
		return nil
	}
	args := map[string]any{"id": id, "content": string(content)}
	if withMeta {
		args["title"], args["markdown"], args["created"] = m.Title, m.IsMarkdown, m.Created
	}
	return undo("notes_restore", args)
}

func (d Deps) notesDelete(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ ID string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	idx, err := d.loadNotes()
	if err != nil {
		return nil, err
	}
	id, ok := idx.find(a.ID)
	if !ok {
		return nil, fmt.Errorf("no note %q (see notes_search)", a.ID)
	}
	m := idx.Notes[id]
	path := d.noteFile(id, m)
	content, err := os.ReadFile(path)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return nil, err
	}
	if err := os.Remove(path); err != nil && !errors.Is(err, os.ErrNotExist) {
		return nil, err
	}
	delete(idx.Notes, id)
	order := idx.Order[:0]
	for _, o := range idx.Order {
		if o != id {
			order = append(order, o)
		}
	}
	idx.Order = order
	if err := d.saveNotes(idx); err != nil {
		return nil, err
	}
	out := map[string]any{"id": id, "title": m.Title, "deleted": true}
	if u := restoreUndo(id, m, content, true); u != nil {
		out["undo"] = u
	}
	return mcp.JSONResult(out), nil
}

func (d Deps) notesRestore(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		ID, Content, Title, Created string
		Markdown                    *bool
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	idx, err := d.loadNotes()
	if err != nil {
		return nil, err
	}
	m, exists := idx.Notes[a.ID]
	if !exists {
		if !noteIDPattern.MatchString(a.ID) {
			return nil, fmt.Errorf("invalid note id %q", a.ID)
		}
		title := strings.TrimSpace(a.Title)
		if title == "" {
			return nil, fmt.Errorf("no note %q; give its title to recreate it", a.ID)
		}
		m = noteMeta{Title: title, Created: a.Created, IsMarkdown: a.Markdown == nil || *a.Markdown}
		if m.Created == "" {
			m.Created = isoNow(d.now())
		}
		idx.Order = append([]string{a.ID}, idx.Order...)
	}
	m.Modified = isoNow(d.now())
	if err := os.MkdirAll(d.notesDir()+"/notes", 0o755); err != nil {
		return nil, err
	}
	if err := fsutil.WriteFile(d.noteFile(a.ID, m), []byte(a.Content), 0o644); err != nil {
		return nil, err
	}
	idx.Notes[a.ID] = m
	if err := d.saveNotes(idx); err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"id": a.ID, "title": m.Title, "restored": true, "recreated": !exists}), nil
}
