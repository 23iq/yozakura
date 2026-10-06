package yozakura

import (
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"html"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"yozakura/backend/pkg/fsutil"
)

// The Notes tab's storage (modules/widgets/dashboard/notes/NotesStore.qml):
// <dir>/index.json {"order": [id...], "notes": {id: {title, created,
// modified, isMarkdown}}} and one file per note, <dir>/notes/<id>.md
// (markdown) or <id>.html (rich text). Unknown index fields are kept.

type noteMeta struct {
	Title      string `json:"title"`
	Created    string `json:"created"`
	Modified   string `json:"modified"`
	IsMarkdown bool   `json:"isMarkdown"`
}

type notesIndex struct {
	raw   map[string]json.RawMessage
	Order []string
	Notes map[string]noteMeta
}

func (d Deps) notesDir() string { return d.NotesDir }

func (d Deps) loadNotes() (*notesIndex, error) {
	if d.notesDir() == "" {
		return nil, errors.New("notes folder unknown")
	}
	idx := &notesIndex{raw: map[string]json.RawMessage{}, Order: []string{}, Notes: map[string]noteMeta{}}
	data, err := os.ReadFile(filepath.Join(d.notesDir(), "index.json"))
	if errors.Is(err, os.ErrNotExist) || len(strings.TrimSpace(string(data))) == 0 {
		return idx, nil
	}
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal(data, &idx.raw); err != nil {
		return nil, fmt.Errorf("notes index: %v", err)
	}
	if o, ok := idx.raw["order"]; ok {
		_ = json.Unmarshal(o, &idx.Order)
	}
	if n, ok := idx.raw["notes"]; ok {
		_ = json.Unmarshal(n, &idx.Notes)
	}
	if idx.Notes == nil {
		idx.Notes = map[string]noteMeta{}
	}
	return idx, nil
}

func (d Deps) saveNotes(idx *notesIndex) error {
	order, _ := json.Marshal(idx.Order)
	notes, _ := json.Marshal(idx.Notes)
	idx.raw["order"], idx.raw["notes"] = order, notes
	data, err := json.MarshalIndent(idx.raw, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Join(d.notesDir(), "notes"), 0o755); err != nil {
		return err
	}
	return fsutil.WriteFile(filepath.Join(d.notesDir(), "index.json"), data, 0o644)
}

func (d Deps) noteFile(id string, m noteMeta) string {
	ext := ".html"
	if m.IsMarkdown {
		ext = ".md"
	}
	return filepath.Join(d.notesDir(), "notes", id+ext)
}

// readNote returns a note's text (rich-text notes as plain text).
func (d Deps) readNote(id string, m noteMeta) (string, error) {
	data, err := os.ReadFile(d.noteFile(id, m))
	if errors.Is(err, os.ErrNotExist) {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	if m.IsMarkdown {
		return string(data), nil
	}
	return htmlText(string(data)), nil
}

var (
	blockTag = regexp.MustCompile(`(?i)<\s*(br|/p|/div|/h[1-6]|/li|/tr)\s*/?>`)
	anyTag   = regexp.MustCompile(`<[^>]*>`)
	blankRun = regexp.MustCompile(`\n{3,}`)
)

// htmlText is a readable plain-text rendering of a rich-text note.
func htmlText(s string) string {
	s = blockTag.ReplaceAllString(s, "\n")
	s = anyTag.ReplaceAllString(s, "")
	s = html.UnescapeString(s)
	return strings.TrimSpace(blankRun.ReplaceAllString(s, "\n\n"))
}

// findNote resolves an id or a title (exact, then case-insensitive, then
// substring) to a note id.
func (idx *notesIndex) find(ref string) (string, bool) {
	ref = strings.TrimSpace(ref)
	if _, ok := idx.Notes[ref]; ok {
		return ref, true
	}
	low := strings.ToLower(ref)
	for _, pass := range []func(string) bool{
		func(t string) bool { return t == ref },
		func(t string) bool { return strings.ToLower(t) == low },
		func(t string) bool { return low != "" && strings.Contains(strings.ToLower(t), low) },
	} {
		for _, id := range idx.Order {
			if m, ok := idx.Notes[id]; ok && pass(m.Title) {
				return id, true
			}
		}
	}
	return "", false
}

func newNoteID() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

func isoNow(t time.Time) string { return t.UTC().Format("2006-01-02T15:04:05.000Z") }
