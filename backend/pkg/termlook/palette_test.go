package termlook

import (
	"os"
	"testing"
)

func fixturePalette(t *testing.T) Palette {
	t.Helper()
	b, err := os.ReadFile("testdata/colors.json")
	if err != nil {
		t.Fatal(err)
	}
	pal, err := PaletteFromColorsJSON(b)
	if err != nil {
		t.Fatalf("PaletteFromColorsJSON: %v", err)
	}
	return pal
}

func TestPaletteFromColorsJSON(t *testing.T) {
	pal := fixturePalette(t)
	want := map[string]string{
		"primary":     "#f5adff",
		"onPrimary":   "#520e62",
		"secondary":   "#e0bbe2",
		"onSecondary": "#412745",
		"tertiary":    "#ffb2bd",
		"onTertiary":  "#620b25",
		"surface":     "#171217",
		"surfaceHigh": "#2e282e",
		"onSurface":   "#ebdfe7",
		"outline":     "#9a8d99",
		"error":       "#ffb4ab",
		"onError":     "#690005",
		"success":     "#b7d085",
	}
	for role, hex := range want {
		if pal[role] != hex {
			t.Errorf("%s: want %s, got %q", role, hex, pal[role])
		}
	}
	for _, r := range Roles {
		if pal[r] == "" {
			t.Errorf("role %s missing", r)
		}
	}
}

func TestPaletteSuccessFallsBackToTertiary(t *testing.T) {
	pal, err := PaletteFromColorsJSON([]byte(`{"primary":"#111111","overPrimary":"#222222","secondary":"#333333",
		"overSecondary":"#444444","tertiary":"#ABCDEF","overTertiary":"#555555","surface":"#666666",
		"surfaceContainerHigh":"#777777","overSurface":"#888888","outline":"#999999","error":"#aaaaaa","overError":"#bbbbbb"}`))
	if err != nil {
		t.Fatal(err)
	}
	if pal["success"] != "#abcdef" {
		t.Fatalf("success fallback: got %q", pal["success"])
	}
}

func TestPaletteAcceptsOnNames(t *testing.T) {
	pal, err := PaletteFromColorsJSON([]byte(`{"primary":"#111111","onPrimary":"#222222","secondary":"#333333",
		"onSecondary":"#444444","tertiary":"#abcdef","onTertiary":"#555555","surface":"#666666",
		"surfaceContainerHigh":"#777777","onSurface":"#888888","outline":"#999999","error":"#aaaaaa","onError":"#bbbbbb"}`))
	if err != nil {
		t.Fatal(err)
	}
	if pal["onPrimary"] != "#222222" {
		t.Fatalf("onPrimary: got %q", pal["onPrimary"])
	}
}

func TestPaletteErrors(t *testing.T) {
	for name, in := range map[string]string{
		"not json":  `{`,
		"missing":   `{"primary":"#111111"}`,
		"bad color": `{"primary":"red","overPrimary":"#222222","secondary":"#333333","overSecondary":"#444444","tertiary":"#abcdef","overTertiary":"#555555","surface":"#666666","surfaceContainerHigh":"#777777","overSurface":"#888888","outline":"#999999","error":"#aaaaaa","overError":"#bbbbbb"}`,
	} {
		if _, err := PaletteFromColorsJSON([]byte(in)); err == nil {
			t.Errorf("%s: want error", name)
		}
	}
}
