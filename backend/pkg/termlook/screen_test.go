package termlook

import (
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func screenText(lines [][]Span) []string {
	out := make([]string, len(lines))
	for i, l := range lines {
		var b strings.Builder
		for _, s := range l {
			b.WriteString(s.Text)
		}
		out[i] = strings.TrimRight(b.String(), " ")
	}
	return out
}

func TestRenderScreenFollowsFastfetchCursorMoves(t *testing.T) {
	// fastfetch aligns values with CHA; a picture logo moves up and right
	in := "\x1b[mLOGO  \x1b[1;31mos\x1b[m  \x1b[14GArch\r\n" +
		"LOGO  \x1b[1;31mkernel\x1b[m  \x1b[14G6.12\n" +
		"\x1b_Ga=T,f=100;AAAA\x1b\\\x1b[2A\x1b[20Cx\x1b[2B\ry\x1b[Kz\rzz\x1b[K"
	lines := RenderScreen(in, ANSI16)
	got := screenText(lines)
	want := []string{"LOGO  os     Arch   x", "LOGO  kernel 6.12", "zz"}
	if strings.Join(got, "|") != strings.Join(want, "|") {
		t.Fatalf("got %q\nwant %q", got, want)
	}
	if lines[0][1].Text != "os" || lines[0][1].FG != ANSI16[1] || !lines[0][1].Bold {
		t.Errorf("styles: %+v", lines[0])
	}
	if last := lines[0][len(lines[0])-1]; last.FG != "" || last.Text != "     Arch   x" {
		t.Errorf("unwritten cells must be blank default cells: %+v", lines[0])
	}
}

func TestFetchSamplesExistAndFollowThePalette(t *testing.T) {
	pal := testPalette(t)
	for _, p := range loadFetch(t) {
		lines, err := FetchSample(fetchAssets, p.ID, pal, ANSI16)
		if err != nil {
			t.Fatalf("%s: %v", p.ID, err)
		}
		text := strings.Join(screenText(lines), "\n")
		if !strings.Contains(text, "user") || !strings.Contains(text, "yozakura") {
			t.Errorf("%s: sample without the sample user@host:\n%s", p.ID, text)
		}
		seen := map[string]bool{}
		for _, l := range lines {
			for _, s := range l {
				if strings.HasPrefix(s.FG, "#fe00") || strings.HasPrefix(s.BG, "#fe00") {
					t.Errorf("%s: marker colour left in %q", p.ID, s.Text)
				}
				seen[s.FG] = true
			}
		}
		if !seen[pal["primary"]] {
			t.Errorf("%s: the primary colour is not used", p.ID)
		}
		if p.Logo && !strings.Contains(text, "▗▄▖▗▄▖") {
			t.Errorf("%s: sample without the sakura logo:\n%s", p.ID, text)
		}
	}
	// without a palette the roles take the terminal's colours
	lines, err := FetchSample(fetchAssets, "sakura", nil, ANSI16)
	if err != nil {
		t.Fatal(err)
	}
	for _, l := range lines {
		for _, s := range l {
			if strings.HasPrefix(s.FG, "#fe00") {
				t.Fatalf("marker without a palette: %+v", s)
			}
		}
	}
	if _, err := FetchSample(fetchAssets, "../x", pal, ANSI16); err == nil {
		t.Error("a path-like id was accepted")
	}
}

func TestSampleConfigHasNoDetectedValues(t *testing.T) {
	for _, p := range loadFetch(t) {
		if p.Own {
			continue
		}
		before, _ := json.Marshal(p.Config)
		s, err := SampleConfig(p)
		if after, _ := json.Marshal(p.Config); string(after) != string(before) {
			t.Errorf("%s: SampleConfig changed the preset", p.ID)
		}
		if err != nil {
			t.Fatalf("%s: %v", p.ID, err)
		}
		for _, m := range s.Config["modules"].([]any) {
			obj, ok := m.(map[string]any)
			if !ok {
				if m != "break" && m != "separator" {
					t.Errorf("%s: module %v left as is", p.ID, m)
				}
				continue
			}
			if typ := obj["type"]; typ != "custom" && typ != "separator" && typ != "break" {
				t.Errorf("%s: module %v still detects", p.ID, obj)
			}
			if f, _ := obj["format"].(string); strings.Contains(f, "-name}") || strings.Contains(f, "{release}") {
				t.Errorf("%s: unfilled variable in %q", p.ID, f)
			}
		}
	}
	if got := sampleFormat("uptime", "up {?days}{days}d {?}{hours}h {minutes}m"); got != "up 3h 12m" {
		t.Errorf("uptime sample %q", got)
	}
}

// With fastfetch missing the preview is the sample (not exact, reason
// fastfetch_missing); with a fake fastfetch its output is rendered.
func TestFetchPreviewFallsBackToTheSample(t *testing.T) {
	pal := testPalette(t)
	env := greetEnv(t, "bash")
	res, err := FetchPreview(context.Background(), GreetingConfig{Preset: "boxed", Logo: LogoSakura}, loadFetch(t), pal, fetchAssets, env, ANSI16)
	if err != nil {
		t.Fatal(err)
	}
	if res.Exact || res.Reason != "fastfetch_missing" || len(res.Lines) < 10 {
		t.Errorf("missing: %+v", res)
	}
	dir := t.TempDir()
	fake := filepath.Join(dir, "fastfetch")
	// prints its arguments: the config it was given is a temp file
	writeFile(t, fake, "#!/bin/sh\nprintf 'ARGS %s %s\\n\\033[31mred\\033[m\\n' \"$1\" \"$3\"\n")
	if err := os.Chmod(fake, 0o755); err != nil {
		t.Fatal(err)
	}
	env.LookPath = func(bin string) (string, bool) { return fake, bin == "fastfetch" }
	res, err = FetchPreview(context.Background(), GreetingConfig{Preset: "sakura", Logo: LogoSakura}, loadFetch(t), pal, fetchAssets, env, ANSI16)
	if err != nil {
		t.Fatal(err)
	}
	text := screenText(res.Lines)
	if !res.Exact || len(text) != 2 || !strings.HasPrefix(text[0], "ARGS --config ") || text[1] != "red" {
		t.Errorf("exact: %+v %q", res, text)
	}
	if _, err := os.Stat(filepath.Join(env.ConfigHome, env.AppID, "fastfetch.jsonc")); err == nil {
		t.Error("the preview wrote the user's config")
	}
	res, _ = FetchPreview(context.Background(), GreetingConfig{Preset: FetchOwn}, loadFetch(t), pal, fetchAssets, env, ANSI16)
	if text := screenText(res.Lines); !strings.HasPrefix(text[0], "ARGS --pipe") {
		t.Errorf("own preview args %q", text)
	}
}

func TestFetchArgvRunsUnderTheLoginShell(t *testing.T) {
	dir := t.TempDir()
	for _, name := range []string{"bash", "fish", "nu"} {
		writeFile(t, filepath.Join(dir, name), "#!/bin/sh\n")
		if err := os.Chmod(filepath.Join(dir, name), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	args := []string{"--config", "/a b/c'd.jsonc"}
	got := fetchArgv("/usr/bin/fastfetch", args, filepath.Join(dir, "bash"))
	if strings.Join(got[1:], "|") != `-c|"$0" "$@"; :|/usr/bin/fastfetch|--config|/a b/c'd.jsonc` {
		t.Errorf("bash argv %q", got)
	}
	got = fetchArgv("/usr/bin/fastfetch", args, filepath.Join(dir, "fish"))
	if got[len(got)-1] != "/a b/c'd.jsonc" || got[3] != "$argv[1] $argv[2..-1]" {
		t.Errorf("fish argv %q", got)
	}
	for _, shell := range []string{"", "bash", filepath.Join(dir, "nu"), filepath.Join(dir, "missing")} {
		if got := fetchArgv("/usr/bin/fastfetch", args, shell); got[0] != "/usr/bin/fastfetch" {
			t.Errorf("%q: %q", shell, got)
		}
	}
	if bash, err := exec.LookPath("bash"); err == nil {
		argv := fetchArgv("printf", []string{"%s|", "a b", "$(x)"}, bash)
		out, err := exec.Command(argv[0], argv[1:]...).Output()
		if err != nil || string(out) != "a b|$(x)|" {
			t.Errorf("bash ran %q: %v", out, err)
		}
	}
}
