package yozakura

import (
	"context"
	"encoding/json"
	"fmt"
	"html"
	"os"
	"strings"

	"yozakura/backend/pkg/fsutil"
	"yozakura/backend/pkg/mcp"
)

// Note tools read and write the Notes tab (dashboard "Notes", launcher
// prefix, quick note bind) through its own files (see notes.go).

func noteTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("notes_search", "Search notes",
			`Search the user's notes (the shell's Notes tab) by title and content, case-insensitive; an empty query lists the most recent notes. Returns id, title, modified time and a snippet around the match. Read a whole note with notes_read.`,
			`{"type":"object","properties":{"query":{"type":"string"},"limit":{"type":"integer","minimum":1,"maximum":50,"default":10}},"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.notesSearch),
		define("notes_read", "Read note",
			`Read one note by id or title (rich-text notes come back as plain text).`,
			`{"type":"object","properties":{"id":{"type":"string","description":"Note id or title."}},"required":["id"],"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.notesRead),
		define("notes_create", "Create note",
			`Create a new note in the Notes tab with a title and markdown content (shown at the top of the list).`,
			`{"type":"object","properties":{"title":{"type":"string"},"content":{"type":"string","description":"Markdown body (the title is added as a heading)."}},"required":["title"],"additionalProperties":false}`,
			toolOpts{}, d.notesCreate),
		define("notes_append", "Append to note",
			`Append text to a note (by id or title), e.g. a shopping list item or a meeting summary. "create": true creates the note when no title matches. Markdown notes get the text as written ("bullet": true adds "- "); rich-text notes get it as a paragraph.`,
			`{"type":"object","properties":{"id":{"type":"string","description":"Note id or title."},"text":{"type":"string"},"bullet":{"type":"boolean","default":false},"create":{"type":"boolean","default":false}},"required":["id","text"],"additionalProperties":false}`,
			toolOpts{}, d.notesAppend),
	}
}

func snippet(text, query string, n int) string {
	flat := strings.Join(strings.Fields(text), " ")
	if query == "" {
		return truncate(flat, n)
	}
	runes := []rune(flat)
	lower := []rune(strings.ToLower(flat))
	i := strings.Index(string(lower), strings.ToLower(query))
	if i < 0 || len(lower) != len(runes) {
		return truncate(flat, n)
	}
	i = len([]rune(string(lower)[:i]))
	start := max(0, i-n/3)
	r := runes[start:]
	s := string(r[:min(len(r), n)])
	if start > 0 {
		s = "…" + s
	}
	if len(r) > n {
		s += "…"
	}
	return s
}

func (d Deps) notesSearch(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Query string
		Limit int
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.Limit <= 0 {
		a.Limit = 10
	}
	idx, err := d.loadNotes()
	if err != nil {
		return nil, err
	}
	q := strings.ToLower(strings.TrimSpace(a.Query))
	out := []map[string]any{}
	for _, id := range idx.Order {
		m, ok := idx.Notes[id]
		if !ok {
			continue
		}
		text, _ := d.readNote(id, m)
		if q != "" && !strings.Contains(strings.ToLower(m.Title), q) && !strings.Contains(strings.ToLower(text), q) {
			continue
		}
		out = append(out, map[string]any{"id": id, "title": m.Title, "modified": m.Modified,
			"markdown": m.IsMarkdown, "snippet": snippet(text, a.Query, 160)})
		if len(out) >= a.Limit {
			break
		}
	}
	return mcp.JSONResult(map[string]any{"notes": out, "total": len(idx.Order)}), nil
}

func (d Deps) notesRead(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
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
	text, err := d.readNote(id, m)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"id": id, "title": m.Title, "modified": m.Modified,
		"markdown": m.IsMarkdown, "content": truncate(text, 60000)}), nil
}

// createNote adds a markdown note at the top of the list.
func (d Deps) createNote(idx *notesIndex, title, body string) (string, error) {
	title = strings.TrimSpace(title)
	if title == "" {
		return "", fmt.Errorf("title is required")
	}
	id := newNoteID()
	now := isoNow(d.now())
	m := noteMeta{Title: title, Created: now, Modified: now, IsMarkdown: true}
	content := "# " + title + "\n\n" + strings.TrimSpace(body)
	if strings.TrimSpace(body) != "" {
		content += "\n"
	}
	if err := os.MkdirAll(d.notesDir()+"/notes", 0o755); err != nil {
		return "", err
	}
	if err := fsutil.WriteFile(d.noteFile(id, m), []byte(content), 0o644); err != nil {
		return "", err
	}
	idx.Notes[id] = m
	idx.Order = append([]string{id}, idx.Order...)
	return id, d.saveNotes(idx)
}

func (d Deps) notesCreate(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Title, Content string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	idx, err := d.loadNotes()
	if err != nil {
		return nil, err
	}
	id, err := d.createNote(idx, a.Title, a.Content)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"id": id, "title": strings.TrimSpace(a.Title), "created": true}), nil
}

func (d Deps) notesAppend(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		ID, Text       string
		Bullet, Create bool
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	text := strings.TrimRight(a.Text, "\n ")
	if strings.TrimSpace(text) == "" {
		return nil, fmt.Errorf("text is required")
	}
	if a.Bullet {
		text = "- " + strings.Join(strings.Fields(text), " ")
	}
	idx, err := d.loadNotes()
	if err != nil {
		return nil, err
	}
	id, ok := idx.find(a.ID)
	if !ok {
		if !a.Create {
			return nil, fmt.Errorf("no note %q; set create to make it", a.ID)
		}
		id, err = d.createNote(idx, a.ID, text)
		if err != nil {
			return nil, err
		}
		return mcp.JSONResult(map[string]any{"id": id, "title": idx.Notes[id].Title, "created": true}), nil
	}
	m := idx.Notes[id]
	path := d.noteFile(id, m)
	old, _ := os.ReadFile(path)
	var next string
	if m.IsMarkdown {
		next = string(old)
		if next != "" && !strings.HasSuffix(next, "\n") {
			next += "\n"
		}
		next += text + "\n"
	} else {
		next = string(old) + "<p>" + html.EscapeString(text) + "</p>"
	}
	if err := fsutil.WriteFile(path, []byte(next), 0o644); err != nil {
		return nil, err
	}
	m.Modified = isoNow(d.now())
	idx.Notes[id] = m
	if err := d.saveNotes(idx); err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"id": id, "title": m.Title, "appended": text}), nil
}
