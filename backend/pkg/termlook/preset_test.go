package termlook

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

const presetDir = "../../../assets/terminal/prompts"

var puaRe = regexp.MustCompile("[\U0000E000-\U0000F8FF\U000F0000-\U000FFFFF]")

func loadAll(t *testing.T) []Preset {
	t.Helper()
	ps, err := LoadPresets(presetDir)
	if err != nil {
		t.Fatalf("LoadPresets: %v", err)
	}
	return ps
}

func presetByID(t *testing.T, id string) Preset {
	t.Helper()
	for _, p := range loadAll(t) {
		if p.ID == id {
			return p
		}
	}
	t.Fatalf("preset %q not found", id)
	return Preset{}
}

func TestLoadPresetsRealDir(t *testing.T) {
	ps := loadAll(t)
	if len(ps) != 14 {
		t.Fatalf("want 14 presets, got %d", len(ps))
	}
	seen := map[string]bool{}
	for _, p := range ps {
		if seen[p.ID] {
			t.Errorf("duplicate id %q", p.ID)
		}
		seen[p.ID] = true
		if p.Description != "term.prompt."+p.ID+".desc" {
			t.Errorf("%s: description key %q", p.ID, p.Description)
		}
		glyphs := presetText(p)
		if p.ID == "plain" {
			if p.NerdFont {
				t.Errorf("plain must not need a Nerd Font")
			}
			if puaRe.MatchString(glyphs) {
				t.Errorf("plain contains Private-Use glyphs: %q", glyphs)
			}
			continue
		}
		if !p.NerdFont {
			t.Errorf("%s: want NerdFont true", p.ID)
		}
	}
	for _, id := range []string{"sakura-powerline", "cherry-blossom", "spaceship", "pure", "zen",
		"rounded-pills", "tokyo-rounded", "neon-slant", "flame", "two-line-box",
		"capsule-right", "arch-badge", "developer", "plain"} {
		if !seen[id] {
			t.Errorf("missing preset %q", id)
		}
	}
}

// presetText gathers every literal string a preset can put on screen.
func presetText(p Preset) string {
	var b strings.Builder
	b.WriteString(p.Char.Symbol + p.Char.Error + SeparatorGlyphs[p.Separator][0] + SeparatorGlyphs[p.Separator][1])
	for _, s := range append(append([]Segment{}, p.Left...), p.Right...) {
		b.WriteString(s.Icon + s.Prefix + s.Suffix + segmentIcon(p, s))
		if s.Type == "langs" && p.NerdFont {
			for _, l := range langs {
				b.WriteString(l.icon)
			}
		}
	}
	return b.String()
}

func writePreset(t *testing.T, dir, id, body string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(dir, id+".json"), []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestLoadPresetsRejectsInvalid(t *testing.T) {
	cases := map[string]string{
		"bad-role":   `{"id":"bad-role","name":"X","description":"term.prompt.bad-role.desc","lines":1,"separator":"none","layout":"text","nerdFont":true,"left":[{"type":"dir","fg":"hotpink"}],"char":{"symbol":">","color":"primary"}}`,
		"bad-type":   `{"id":"bad-type","name":"X","description":"term.prompt.bad-type.desc","lines":1,"separator":"none","layout":"text","nerdFont":true,"left":[{"type":"kubernetes","fg":"primary"}],"char":{"symbol":">","color":"primary"}}`,
		"hex-color":  `{"id":"hex-color","name":"X","description":"term.prompt.hex-color.desc","lines":1,"separator":"none","layout":"text","nerdFont":true,"left":[{"type":"dir","fg":"#ff0000"}],"char":{"symbol":">","color":"primary"}}`,
		"no-bg":      `{"id":"no-bg","name":"X","description":"term.prompt.no-bg.desc","lines":1,"separator":"powerline","layout":"powerline","nerdFont":true,"left":[{"type":"dir","fg":"primary"}],"char":{"symbol":">","color":"primary"}}`,
		"dup-type":   `{"id":"dup-type","name":"X","description":"term.prompt.dup-type.desc","lines":1,"separator":"none","layout":"text","nerdFont":true,"left":[{"type":"dir","fg":"primary"},{"type":"dir","fg":"primary"}],"char":{"symbol":">","color":"primary"}}`,
		"cond-first": `{"id":"cond-first","name":"X","description":"term.prompt.cond-first.desc","lines":1,"separator":"none","layout":"text","nerdFont":true,"left":[{"type":"git_branch","fg":"primary"}],"char":{"symbol":">","color":"primary"}}`,
		"pua-plain":  `{"id":"pua-plain","name":"X","description":"term.prompt.pua-plain.desc","lines":1,"separator":"none","layout":"text","nerdFont":false,"left":[{"type":"dir","fg":"primary","icon":"` + "\U0000F07C" + `"}],"char":{"symbol":">","color":"primary"}}`,
		"wrong-file": `{"id":"other","name":"X","description":"term.prompt.other.desc","lines":1,"separator":"none","layout":"text","nerdFont":true,"left":[{"type":"dir","fg":"primary"}],"char":{"symbol":">","color":"primary"}}`,
		"bad-lines":  `{"id":"bad-lines","name":"X","description":"term.prompt.bad-lines.desc","lines":3,"separator":"none","layout":"text","nerdFont":true,"left":[{"type":"dir","fg":"primary"}],"char":{"symbol":">","color":"primary"}}`,
		"bad-desc":   `{"id":"bad-desc","name":"X","description":"Pretty","lines":1,"separator":"none","layout":"text","nerdFont":true,"left":[{"type":"dir","fg":"primary"}],"char":{"symbol":">","color":"primary"}}`,
	}
	for name, body := range cases {
		t.Run(name, func(t *testing.T) {
			dir := t.TempDir()
			writePreset(t, dir, name, body)
			if _, err := LoadPresets(dir); err == nil {
				t.Fatalf("want error for %s", name)
			}
		})
	}
}

func TestLoadPresetsDefaultsErrorSymbol(t *testing.T) {
	dir := t.TempDir()
	writePreset(t, dir, "ok", `{"id":"ok","name":"Ok","description":"term.prompt.ok.desc","lines":1,"separator":"none","layout":"text","nerdFont":true,"left":[{"type":"dir","fg":"primary"}],"char":{"symbol":">","color":"primary"}}`)
	ps, err := LoadPresets(dir)
	if err != nil {
		t.Fatal(err)
	}
	if ps[0].Char.Error != ">" {
		t.Fatalf("error symbol should default to symbol, got %q", ps[0].Char.Error)
	}
}
