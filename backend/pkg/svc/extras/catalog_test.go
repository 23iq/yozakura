package extras

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"yozakura/backend/pkg/apphooks"
)

const repoRoot = "../../../.."

func loadReal(t *testing.T) *Catalog {
	t.Helper()
	c, err := LoadCatalog(filepath.Join(repoRoot, "assets", "catalog", "extras.json"))
	if err != nil {
		t.Fatalf("LoadCatalog: %v", err)
	}
	return c
}

func base() *Catalog {
	return &Catalog{
		Categories: []Category{{ID: "agents"}},
		Entries: []Entry{
			{ID: "a", Category: "agents", Install: Install{Npm: "foo"}},
			{ID: "b", Category: "agents", Install: Install{Npm: "bar"}, Requires: []string{"a"}},
		},
	}
}

func TestRealCatalogValid(t *testing.T) {
	c := loadReal(t)
	if len(c.Categories) != 10 {
		t.Fatalf("categories = %d", len(c.Categories))
	}
	for _, id := range []string{"claude-code", "ollama", "voice", "ghostty", "vesktop", "thunar"} {
		if _, ok := c.Get(id); !ok {
			t.Errorf("missing entry %s", id)
		}
	}
	if _, ok := c.Get("nope"); ok {
		t.Error("Get(nope) should be false")
	}
}

func TestValidateRejects(t *testing.T) {
	cases := map[string]func(c *Catalog){
		"duplicate id":    func(c *Catalog) { c.Entries[1].ID = "a" },
		"unknown cat":     func(c *Catalog) { c.Entries[0].Category = "x" },
		"unknown require": func(c *Catalog) { c.Entries[0].Requires = []string{"zzz"} },
		"cycle":           func(c *Catalog) { c.Entries[0].Requires = []string{"b"} },
		"bad pkg": func(c *Catalog) {
			c.Entries[0].Install.Arch = &Method{Pkgs: []string{"foo;rm"}}
		},
		"bad aur": func(c *Catalog) {
			c.Entries[0].Install.Arch = &Method{AUR: []string{"$(x)"}}
		},
		"evil host": func(c *Catalog) {
			c.Entries[0].Install.Script = &ScriptSpec{URL: "https://evil.com/i.sh"}
		},
		"http script": func(c *Catalog) {
			c.Entries[0].Install.Script = &ScriptSpec{URL: "http://claude.ai/install.sh"}
		},
		"bad script arg": func(c *Catalog) {
			c.Entries[0].Install.Script = &ScriptSpec{URL: "https://claude.ai/x", Args: []string{"; rm"}}
		},
		"no method":  func(c *Catalog) { c.Entries[0].Install = Install{} },
		"bad shell":  func(c *Catalog) { c.Entries[0].Install.Shell = "../x.sh" },
		"bad font":   func(c *Catalog) { c.Entries[0].Detect.Fonts = []string{"Nerd $(x)"} },
		"empty font": func(c *Catalog) { c.Entries[0].Detect.Fonts = []string{""} },
	}
	for name, mut := range cases {
		c := base()
		mut(c)
		if err := c.Validate(); err == nil {
			t.Errorf("%s: expected error", name)
		}
	}
	if err := base().Validate(); err != nil {
		t.Fatalf("base should be valid: %v", err)
	}
}

func TestIconsExist(t *testing.T) {
	data, err := os.ReadFile(filepath.Join(repoRoot, "modules", "theme", "Icons.qml"))
	if err != nil {
		t.Fatal(err)
	}
	re := regexp.MustCompile(`property string (\w+):`)
	have := map[string]bool{}
	for _, m := range re.FindAllStringSubmatch(string(data), -1) {
		have[m[1]] = true
	}
	c := loadReal(t)
	for _, cat := range c.Categories {
		if !have[cat.Icon] {
			t.Errorf("category %s: icon %q not in Icons.qml", cat.ID, cat.Icon)
		}
	}
	for _, e := range c.Entries {
		if !e.Hidden && !have[e.Icon] {
			t.Errorf("entry %s: icon %q not in Icons.qml", e.ID, e.Icon)
		}
	}
}

func TestTranslationsExist(t *testing.T) {
	files, _ := filepath.Glob(filepath.Join(repoRoot, "translations", "[a-z][a-z].json"))
	c := loadReal(t)
	for _, f := range files {
		data, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}
		m := map[string]string{}
		if err := json.Unmarshal(data, &m); err != nil {
			t.Fatal(err)
		}
		need := []string{}
		for _, cat := range c.Categories {
			if cat.Name != "extras.cat."+cat.ID {
				t.Errorf("category %s name key = %q", cat.ID, cat.Name)
			}
			need = append(need, cat.Name)
		}
		for _, e := range c.Entries {
			if !e.Hidden {
				need = append(need, "extras."+e.ID+".desc")
			}
		}
		for _, k := range need {
			if strings.TrimSpace(m[k]) == "" {
				t.Errorf("%s: missing %s", filepath.Base(f), k)
			}
		}
	}
}

// Every catalog post "apphook:<id>" names a registered hook (an unknown
// one would fail silently after a successful install).
func TestCatalogPostHooksRegistered(t *testing.T) {
	for _, e := range loadReal(t).Entries {
		for _, p := range e.Post {
			prefix, id, _ := strings.Cut(p, ":")
			if prefix != "apphook" {
				t.Errorf("%s: unknown post action %q", e.ID, p)
				continue
			}
			if _, ok := apphooks.Get(id); !ok {
				t.Errorf("%s: post %q has no registered hook", e.ID, p)
			}
		}
	}
}
