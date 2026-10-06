package termlook

import (
	"context"
	"os/exec"
	"strings"
	"testing"
)

func plain(spans []Span) string {
	var b strings.Builder
	for _, s := range spans {
		b.WriteString(s.Text)
	}
	return b.String()
}

func lookReal(bin string) (string, bool) {
	p, err := exec.LookPath(bin)
	return p, err == nil
}

func TestApproxSakura(t *testing.T) {
	pal := fixturePalette(t)
	left, right := RenderApprox(presetByID(t, "sakura-powerline"), pal)
	if len(left) != 1 || len(right) != 0 {
		t.Fatalf("lines = %d, right = %d", len(left), len(right))
	}
	line := left[0]
	if got := plain(line); !strings.Contains(got, "~/projects/yozakura") || !strings.Contains(got, "main") || !strings.HasSuffix(got, "❯ ") {
		t.Errorf("text = %q", got)
	}
	colors := map[string]bool{}
	for _, s := range line {
		colors[s.FG], colors[s.BG] = true, true
	}
	for _, role := range []string{"primary", "onPrimary", "secondary", "tertiary"} {
		if !colors[pal[role]] {
			t.Errorf("palette role %s (%s) not used", role, pal[role])
		}
	}
	for c := range colors {
		if c != "" && !hexRe.MatchString(c) {
			t.Errorf("non-palette color %q", c)
		}
	}
	// Separators sit between the first two segments with prev bg as fg.
	var sep *Span
	for i := range line {
		if line[i].Text == SeparatorGlyphs["powerline"][0] {
			sep = &line[i]
			break
		}
	}
	if sep == nil || sep.FG != pal[presetByID(t, "sakura-powerline").Left[0].BG] {
		t.Errorf("first separator = %+v", sep)
	}
}

func TestApproxAllPresets(t *testing.T) {
	pal := fixturePalette(t)
	for _, p := range loadAll(t) {
		left, right := RenderApprox(p, pal)
		if len(left) != p.Lines {
			t.Errorf("%s: %d lines, want %d", p.ID, len(left), p.Lines)
		}
		if (len(right) > 0) != (len(p.Right) > 0) {
			t.Errorf("%s: right = %d spans, preset has %d", p.ID, len(right), len(p.Right))
		}
		for _, l := range append(left, right) {
			for _, s := range l {
				if s.Text == "" {
					t.Errorf("%s: empty span", p.ID)
				}
			}
		}
	}
	plainP := presetByID(t, "plain")
	left, _ := RenderApprox(plainP, pal)
	for _, s := range left[0] {
		if hasPUA(s.Text) {
			t.Errorf("plain preview has a Nerd Font glyph: %q", s.Text)
		}
	}
	two, _ := RenderApprox(presetByID(t, "two-line-box"), pal)
	if !strings.HasPrefix(plain(two[0]), frameTop) || !strings.HasPrefix(plain(two[1]), frameBottom) {
		t.Errorf("frame missing: %q / %q", plain(two[0]), plain(two[1]))
	}
}

func TestPreviewFallsBackWithoutEngine(t *testing.T) {
	env := testEnv(t)
	env.LookPath = func(string) (string, bool) { return "", false }
	for _, eng := range []string{EngineStarship, EngineOMP} {
		res, err := Preview(context.Background(), Config{Engine: eng}, presetByID(t, "capsule-right"), fixturePalette(t), env, 80)
		if err != nil {
			t.Fatal(err)
		}
		if res.Exact || res.Engine != eng || len(res.Left) != 1 || len(res.Right) == 0 {
			t.Errorf("%s: %+v", eng, res)
		}
	}
}

func TestPreviewRealStarship(t *testing.T) {
	for _, bin := range []string{"starship", "git"} {
		if _, ok := lookReal(bin); !ok {
			t.Skipf("%s not installed", bin)
		}
	}
	env := testEnv(t)
	env.CacheHome = t.TempDir()
	env.LookPath = lookReal
	pal := fixturePalette(t)
	res, err := Preview(context.Background(), Config{Engine: EngineStarship}, presetByID(t, "capsule-right"), pal, env, 80)
	if err != nil {
		t.Fatal(err)
	}
	if !res.Exact {
		t.Fatal("expected an exact preview")
	}
	left := plain(res.Left[0])
	for _, want := range []string{"yozakura", "main", "❯"} {
		if !strings.Contains(left, want) {
			t.Errorf("left %q lacks %q", left, want)
		}
	}
	if !strings.Contains(left, "?") && !strings.Contains(left, "!") {
		t.Errorf("git status missing: %q", left)
	}
	if r := plain(res.Right); !strings.Contains(r, "3s") {
		t.Errorf("right %q lacks the duration", r)
	}
	for _, line := range res.Left {
		for _, s := range line {
			if strings.ContainsRune(s.Text, 0x1b) {
				t.Errorf("escape leaked: %q", s.Text)
			}
		}
	}
}
