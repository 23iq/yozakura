package termlook

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

const fetchAssets = "../../../assets/terminal/fastfetch"

func testPalette(t *testing.T) Palette {
	t.Helper()
	data, err := os.ReadFile("testdata/colors.json")
	if err != nil {
		t.Fatal(err)
	}
	pal, err := PaletteFromColorsJSON(data)
	if err != nil {
		t.Fatal(err)
	}
	return pal
}

func loadFetch(t *testing.T) []FetchPreset {
	t.Helper()
	ps, err := LoadFetchPresets(fetchAssets)
	if err != nil {
		t.Fatal(err)
	}
	return ps
}

func TestBundledFetchPresetsLoad(t *testing.T) {
	ps := loadFetch(t)
	var ids []string
	for _, p := range ps {
		ids = append(ids, p.ID)
		if p.Own != (p.Config == nil) {
			t.Errorf("%s: own=%v but config=%v", p.ID, p.Own, p.Config != nil)
		}
	}
	if got := strings.Join(ids, ","); got != "sakura,compact,boxed,full,minimal,own" {
		t.Errorf("presets = %s", got)
	}
}

// colourNames are fastfetch colour names a rendered config must not keep
// where the palette maps them.
var leftoverName = regexp.MustCompile(`\{#(bold_|light_|dim_)*(magenta|blue|cyan|yellow|green|red|white|black)\}`)

func TestRenderFetchMapsEveryColourToThePalette(t *testing.T) {
	pal := testPalette(t)
	used := map[string]bool{}
	for _, c := range pal {
		used[c] = true
	}
	for _, p := range loadFetch(t) {
		if p.Own {
			if _, err := RenderFetch(p, pal, FetchLogo{}); err == nil {
				t.Error("own must not render a config")
			}
			continue
		}
		out, err := RenderFetch(p, pal, FetchLogo{Kind: "file", Source: "/l.txt"})
		if err != nil {
			t.Fatalf("%s: %v", p.ID, err)
		}
		var cfg map[string]any
		if err := json.Unmarshal(out, &cfg); err != nil {
			t.Fatalf("%s: invalid JSON: %v", p.ID, err)
		}
		if m := leftoverName.Find(out); m != nil {
			t.Errorf("%s: unmapped colour %s", p.ID, m)
		}
		// every colour value is a palette colour, possibly with styles
		var walk func(v any, colour bool)
		walk = func(v any, colour bool) {
			switch x := v.(type) {
			case map[string]any:
				for k, val := range x {
					walk(val, colour || isColorKey(k))
				}
			case []any:
				for _, val := range x {
					walk(val, colour)
				}
			case string:
				if colour {
					hex := x[strings.LastIndex(x, "_")+1:]
					if !used[hex] {
						t.Errorf("%s: colour %q is not from the palette", p.ID, x)
					}
				}
			}
		}
		walk(cfg["display"], false)
		if p.Logo {
			logo := cfg["logo"].(map[string]any)
			if logo["type"] != "file" || logo["source"] != "/l.txt" {
				t.Errorf("%s: logo %v", p.ID, logo)
			}
			if logo["padding"] == nil {
				t.Errorf("%s: the preset's logo padding was dropped", p.ID)
			}
			walk(logo["color"], true)
		}
	}
}

func TestFetchColor(t *testing.T) {
	pal := Palette{"primary": "#AA0000", "outline": "#555555", "tertiary": "#00aa00"}
	for in, want := range map[string]string{
		"magenta":       "#aa0000",
		"bold_magenta":  "bold_#aa0000",
		"light_magenta": "#aa0000",
		"light_black":   "#555555",
		"italic_yellow": "italic_#00aa00",
		"default":       "default",
		"#123456":       "#123456",
		"38;2;1;2;3":    "38;2;1;2;3",
		"blue":          "blue", // no secondary in this palette: unchanged
	} {
		if got := fetchColor(in, pal); got != want {
			t.Errorf("fetchColor(%q) = %q, want %q", in, got, want)
		}
	}
	got := mapFetchColors(map[string]any{"format": "{#magenta}x{#}y{#light_black}@{#weird}"}, "", "", pal)
	if s := got.(map[string]any)["format"]; s != "{##aa0000}x{#}y{##555555}@{#weird}" {
		t.Errorf("format = %v", s)
	}
}

func TestRenderFetchLogos(t *testing.T) {
	pal := testPalette(t)
	p, _ := FindFetchPreset(loadFetch(t), "sakura")
	logo := func(l FetchLogo) map[string]any {
		out, err := RenderFetch(p, pal, l)
		if err != nil {
			t.Fatal(err)
		}
		var cfg map[string]any
		_ = json.Unmarshal(out, &cfg)
		return cfg["logo"].(map[string]any)
	}
	if l := logo(FetchLogo{Kind: LogoDistro}); l["type"] != nil || l["source"] != nil {
		t.Errorf("distro: %v", l)
	}
	if l := logo(FetchLogo{Kind: LogoNone}); l["type"] != "none" {
		t.Errorf("none: %v", l)
	}
	l := logo(FetchLogo{Kind: "kitty-direct", Source: "/p.png", Width: 20, Height: 10})
	if l["type"] != "kitty-direct" || l["width"] != float64(20) || l["height"] != float64(10) {
		t.Errorf("kitty: %v", l)
	}
	if _, err := RenderFetch(p, pal, FetchLogo{Kind: "auto"}); err == nil {
		t.Error("an unknown logo kind must fail (auto would print a picture as text)")
	}
	// a look without a logo keeps its own
	m, _ := FindFetchPreset(loadFetch(t), "minimal")
	out, _ := RenderFetch(m, pal, FetchLogo{Kind: "file", Source: "/x"})
	if !strings.Contains(string(out), `"type": "none"`) || strings.Contains(string(out), "/x") {
		t.Errorf("minimal logo: %s", out)
	}
	// no palette yet: logo colours are left to the terminal
	out, _ = RenderFetch(p, nil, FetchLogo{Kind: "file", Source: "/l"})
	var cfg map[string]any
	_ = json.Unmarshal(out, &cfg)
	if c := cfg["logo"].(map[string]any)["color"].(map[string]any); len(c) != 0 {
		t.Errorf("colours without a palette: %v", c)
	}
}

func TestLoadFetchPresetsRejectsBadIndex(t *testing.T) {
	for name, idx := range map[string]string{
		"no own":     `{"presets":[{"id":"a","description":"term.fetch.preset.a.desc","logo":true}]}`,
		"bad desc":   `{"presets":[{"id":"own","description":"x","own":true}]}`,
		"bad id":     `{"presets":[{"id":"A B","description":"term.fetch.preset.A B.desc"}]}`,
		"own not id": `{"presets":[{"id":"own","description":"term.fetch.preset.own.desc"}]}`,
	} {
		dir := t.TempDir()
		if err := os.WriteFile(filepath.Join(dir, "presets.json"), []byte(idx), 0o644); err != nil {
			t.Fatal(err)
		}
		if _, err := LoadFetchPresets(dir); err == nil {
			t.Errorf("%s: accepted", name)
		}
	}
}
