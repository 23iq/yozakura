// Package termlook holds Yozakura's terminal prompt presets: an
// engine-neutral description of a prompt whose colors are palette roles, and
// renderers that turn one into a Starship or oh-my-posh config.
package termlook

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"unicode"
	"unicode/utf8"
)

// Segment is one piece of the prompt. BG and FG are palette roles; BG is
// empty for segments drawn on the terminal background (layout "text").
type Segment struct {
	Type   string `json:"type"`
	BG     string `json:"bg,omitempty"`
	FG     string `json:"fg"`
	Icon   string `json:"icon,omitempty"`   // overrides the type icon; "none" hides it
	Style  string `json:"style,omitempty"`  // bold | italic
	Prefix string `json:"prefix,omitempty"` // connector text before ("on ", "via ")
	Suffix string `json:"suffix,omitempty"`
}

// PromptChar is the final prompt character.
type PromptChar struct {
	Symbol string `json:"symbol"`
	Error  string `json:"error,omitempty"` // defaults to Symbol
	Color  string `json:"color"`
}

// Preset is a prompt look. Layout decides how segments are joined:
// "powerline" (one connected bar, Separator between segments), "pills"
// (each segment capped on its own) or "text" (no backgrounds).
type Preset struct {
	ID          string     `json:"id"`
	Name        string     `json:"name"`        // proper noun, not translated
	Description string     `json:"description"` // i18n key term.prompt.<id>.desc
	Lines       int        `json:"lines"`       // 1 | 2
	Separator   string     `json:"separator"`
	Layout      string     `json:"layout"`
	Frame       bool       `json:"frame,omitempty"` // box corners on 2-line prompts
	Left        []Segment  `json:"left"`
	Right       []Segment  `json:"right,omitempty"`
	Char        PromptChar `json:"char"`
	NerdFont    bool       `json:"nerdFont"`
}

// SegmentTypes are the known segment types.
var SegmentTypes = []string{"os", "user", "host", "dir", "git_branch", "git_status", "langs",
	"duration", "time", "status", "jobs", "battery"}

// Layouts are the known ways of joining segments.
var Layouts = []string{"powerline", "pills", "text"}

// alwaysShown types render in every directory and state, so they can open
// a connected bar without leaving a dangling separator.
var alwaysShown = map[string]bool{"os": true, "user": true, "host": true, "dir": true, "time": true}

var idRe = regexp.MustCompile(`^[a-z0-9-]+$`)

// LoadPresets reads and validates every *.json preset in dir, sorted by id.
func LoadPresets(dir string) ([]Preset, error) {
	files, err := filepath.Glob(filepath.Join(dir, "*.json"))
	if err != nil {
		return nil, err
	}
	if len(files) == 0 {
		return nil, fmt.Errorf("no prompt presets in %s", dir)
	}
	seen := map[string]bool{}
	var out []Preset
	for _, f := range files {
		b, err := os.ReadFile(f)
		if err != nil {
			return nil, err
		}
		var p Preset
		dec := json.NewDecoder(strings.NewReader(string(b)))
		dec.DisallowUnknownFields()
		if err := dec.Decode(&p); err != nil {
			return nil, fmt.Errorf("%s: %w", filepath.Base(f), err)
		}
		if want := strings.TrimSuffix(filepath.Base(f), ".json"); p.ID != want {
			return nil, fmt.Errorf("%s: id %q does not match file name", filepath.Base(f), p.ID)
		}
		if p.Char.Error == "" {
			p.Char.Error = p.Char.Symbol
		}
		if err := p.Validate(); err != nil {
			return nil, fmt.Errorf("%s: %w", filepath.Base(f), err)
		}
		if seen[p.ID] {
			return nil, fmt.Errorf("duplicate preset id %q", p.ID)
		}
		seen[p.ID] = true
		out = append(out, p)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}

// Validate checks ids, roles, types and glyph use.
func (p Preset) Validate() error {
	if !idRe.MatchString(p.ID) {
		return fmt.Errorf("invalid id %q", p.ID)
	}
	if p.Name == "" || utf8.RuneCountInString(p.Name) > 40 {
		return fmt.Errorf("name must be 1-40 characters")
	}
	if p.Description != "term.prompt."+p.ID+".desc" {
		return fmt.Errorf("description must be the key term.prompt.%s.desc", p.ID)
	}
	if p.Lines != 1 && p.Lines != 2 {
		return fmt.Errorf("lines must be 1 or 2")
	}
	if _, ok := SeparatorGlyphs[p.Separator]; !ok {
		return fmt.Errorf("unknown separator %q", p.Separator)
	}
	if !contains(Layouts, p.Layout) {
		return fmt.Errorf("unknown layout %q", p.Layout)
	}
	if p.Layout != "text" && (p.Separator == "none" || p.Separator == "arrow") {
		return fmt.Errorf("layout %s needs a glyph separator", p.Layout)
	}
	if p.Frame && p.Lines != 2 {
		return fmt.Errorf("frame needs a 2-line prompt")
	}
	if len(p.Left) == 0 {
		return fmt.Errorf("left side is empty")
	}
	if !alwaysShown[p.Left[0].Type] {
		return fmt.Errorf("first left segment %q may be hidden; start with one of os/user/host/dir/time", p.Left[0].Type)
	}
	used := map[string]bool{}
	for _, s := range append(append([]Segment{}, p.Left...), p.Right...) {
		if err := p.validateSegment(s); err != nil {
			return fmt.Errorf("segment %s: %w", s.Type, err)
		}
		if used[s.Type] {
			return fmt.Errorf("segment %s used twice", s.Type)
		}
		used[s.Type] = true
	}
	if p.Char.Symbol == "" {
		return fmt.Errorf("char.symbol is empty")
	}
	if !contains(Roles, p.Char.Color) {
		return fmt.Errorf("char.color %q is not a role", p.Char.Color)
	}
	for _, s := range []string{p.Char.Symbol, p.Char.Error} {
		if err := p.checkText(s); err != nil {
			return fmt.Errorf("char: %w", err)
		}
	}
	if !p.NerdFont && hasPUA(SeparatorGlyphs[p.Separator][0]) {
		return fmt.Errorf("separator %s needs a Nerd Font", p.Separator)
	}
	return nil
}

func (p Preset) validateSegment(s Segment) error {
	if !contains(SegmentTypes, s.Type) {
		return fmt.Errorf("unknown type")
	}
	if !contains(Roles, s.FG) {
		return fmt.Errorf("fg %q is not a role", s.FG)
	}
	if p.Layout == "text" {
		if s.BG != "" {
			return fmt.Errorf("layout text has no backgrounds")
		}
	} else if !contains(Roles, s.BG) {
		return fmt.Errorf("bg %q is not a role", s.BG)
	}
	if s.Style != "" && s.Style != "bold" && s.Style != "italic" {
		return fmt.Errorf("style %q (bold|italic)", s.Style)
	}
	if (s.Type == "os" || s.Type == "battery" || s.Type == "langs") && s.Icon != "" {
		return fmt.Errorf("%s icons are dynamic and cannot be overridden", s.Type)
	}
	for _, t := range []string{s.Icon, s.Prefix, s.Suffix} {
		if err := p.checkText(t); err != nil {
			return err
		}
	}
	return nil
}

// checkText bounds preset-provided literal text.
func (p Preset) checkText(s string) error {
	if utf8.RuneCountInString(s) > 16 {
		return fmt.Errorf("text %q longer than 16 characters", s)
	}
	for _, r := range s {
		if unicode.IsControl(r) {
			return fmt.Errorf("control character in %q", s)
		}
	}
	if !p.NerdFont && hasPUA(s) {
		return fmt.Errorf("%q needs a Nerd Font but nerdFont is false", s)
	}
	return nil
}

func contains(list []string, s string) bool {
	for _, v := range list {
		if v == s {
			return true
		}
	}
	return false
}
