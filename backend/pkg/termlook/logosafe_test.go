package termlook

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSanitizeLogoKeepsOnlyColours(t *testing.T) {
	for _, c := range []struct{ name, in, want string }{
		{"plain", "$1 /\\_/\\\n\t( o.o )\n", "$1 /\\_/\\\n\t( o.o )\n"},
		{"sgr", "\x1b[1;38;2;245;173;255mX\x1b[0m\x1b[38:5:13mY\x1b[m", "\x1b[1;38;2;245;173;255mX\x1b[0m\x1b[38:5:13mY\x1b[m"},
		{"osc 52 (clipboard)", "\x1b]52;c;cHduZWQ=\x07LOGO", "LOGO"},
		{"osc 0 (title), ST", "\x1b]0;HACKED\x1b\\LOGO", "LOGO"},
		{"cursor moves", "A\x1b[2J\x1b[10;10HB\x1b[3AC\x1b[?25l", "ABC"},
		{"private sgr-like", "\x1b[>4;2mX\x1b[?1m", "X"},
		{"dcs", "\x1bP+q544e\x1b\\X", "X"},
		{"apc / pm / sos", "\x1b_Gi=1;AAAA\x1b\\\x1b^pm\x07\x1bXsos\x1b\\X", "X"},
		{"unterminated osc", "X\x1b]52;c;cHduZWQ=", "X"},
		{"lone esc at eof", "X\x1b", "X"},
		{"esc esc", "X\x1b\x1b[31mY", "X\x1b[31mY"},
		{"two-char escapes", "\x1bcX\x1b7Y\x1b(0Z", "XYZ"},
		{"c0", "A\x07B\x08C\rD\x00E\x7fF", "ABCDEF"},
		{"c1", "A\u009b2JB\u009d0;t\u009cC\u0085D", "ABCD"},
		{"csi broken by newline", "A\x1b[12\nB", "A\nB"},
	} {
		if got := SanitizeLogo(c.in); got != c.want {
			t.Errorf("%s: %q -> %q, want %q", c.name, c.in, got, c.want)
		}
	}
}

// A downloaded .ans logo: the greeting prints our sanitised copy, never
// the file itself; the preview (another env) gets the same text.
func TestGreetingPrintsASanitisedCopyOfTheLogo(t *testing.T) {
	env := greetEnv(t)
	art := filepath.Join(env.Home, "dl", "logo.ans")
	writeFile(t, art, "\x1b]52;c;cHduZWQ=\x07\x1b]0;HACKED\x07\x1b[35mLOGO\x1b[0m $1x\x1b[5;5H\n")
	applyGreeting(t, GreetingConfig{On: true, Preset: "sakura", Logo: LogoCustom, LogoPath: art}, env)
	var conf map[string]any
	if err := json.Unmarshal([]byte(readFile(t, FetchConfigFile(env))), &conf); err != nil {
		t.Fatal(err)
	}
	logo := conf["logo"].(map[string]any)
	if logo["type"] != "file-raw" || logo["source"] != fetchLogoFile(env) {
		t.Errorf("logo %v", logo)
	}
	want := "\x1b[35mLOGO\x1b[0m $1x\n"
	if got := readFile(t, fetchLogoFile(env)); got != want {
		t.Errorf("copy %q", got)
	}
	// the preview's config (a temp env) reads the same sanitised text
	p, _ := FindFetchPreset(loadFetch(t), "sakura")
	penv := Env{Home: t.TempDir(), AppID: "preview"}
	penv.ConfigHome = penv.Home
	cmd, logoErr, err := writeFetchConfigs(GreetingConfig{Logo: LogoCustom, LogoPath: art}, p, testPalette(t), SakuraLogoFile(fetchAssets), penv)
	if err != nil || logoErr != "" {
		t.Fatal(err, logoErr)
	}
	if !strings.Contains(readFile(t, cmd.cfg), fetchLogoFile(penv)) || readFile(t, fetchLogoFile(penv)) != want {
		t.Errorf("preview logo %q", readFile(t, fetchLogoFile(penv)))
	}
	// the file is gone: the sakura logo
	if err := os.Remove(art); err != nil {
		t.Fatal(err)
	}
	st := applyGreeting(t, GreetingConfig{On: true, Preset: "sakura", Logo: LogoCustom, LogoPath: art}, env)
	if st.LogoError == "" || readFile(t, fetchLogoFile(env)) != readFile(t, SakuraLogoFile(fetchAssets)) {
		t.Errorf("missing logo: %+v", st)
	}
	// a file that turns binary after the check: the sakura logo as well
	if _, err := copyCustomLogo(SakuraLogoFile(fetchAssets), filepath.Join(t.TempDir(), "x")); err != nil {
		t.Errorf("copy of a good logo: %v", err)
	}
	bad := filepath.Join(env.Home, "bad.txt")
	writeFile(t, bad, "\xff\xfe")
	if _, err := copyCustomLogo(bad, filepath.Join(t.TempDir(), "x")); !isLogoError(err) {
		t.Errorf("binary logo: %v", err)
	}
	// a file that grew past the cap after the check: the read itself is capped
	grown := filepath.Join(env.Home, "grown.txt")
	writeFile(t, grown, strings.Repeat("x", MaxTextLogo+1))
	if _, err := copyCustomLogo(grown, filepath.Join(t.TempDir(), "x")); !errors.Is(err, ErrLogoTooLarge) {
		t.Errorf("grown logo: %v", err)
	}
	// off: the copy goes
	if err := RemoveGreeting(env); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(fetchLogoFile(env)); err == nil {
		t.Error("logo copy left")
	}
}
