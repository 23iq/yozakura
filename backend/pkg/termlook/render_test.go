package termlook

import (
	"bytes"
	"encoding/json"
	"flag"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/pelletier/go-toml/v2"

	"yozakura/backend/pkg/brand"
)

var update = flag.Bool("update", false, "rewrite golden files")

var goldenIDs = []string{"sakura-powerline", "pure", "capsule-right"}

func checkGolden(t *testing.T, name, got string) {
	t.Helper()
	path := filepath.Join("testdata", name)
	if *update {
		if err := os.WriteFile(path, []byte(got), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	want, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read golden (run with -update): %v", err)
	}
	if string(want) != got {
		t.Errorf("%s differs from golden; rerun with -update if intended\n--- got ---\n%s", name, got)
	}
}

func TestGoldenStarship(t *testing.T) {
	pal := fixturePalette(t)
	for _, id := range goldenIDs {
		checkGolden(t, id+".starship.toml", RenderStarship(presetByID(t, id), pal))
	}
}

func TestGoldenOMP(t *testing.T) {
	pal := fixturePalette(t)
	for _, id := range goldenIDs {
		checkGolden(t, id+".omp.json", RenderOMP(presetByID(t, id), pal))
	}
}

func TestRenderOutputsAreASCIIForGlyphs(t *testing.T) {
	pal := fixturePalette(t)
	for _, p := range loadAll(t) {
		for name, out := range map[string]string{"starship": RenderStarship(p, pal), "omp": RenderOMP(p, pal)} {
			if hasPUA(out) {
				t.Errorf("%s/%s: raw Private-Use glyphs in output (should be escaped)", p.ID, name)
			}
		}
	}
}

func TestStarshipParsesAsTOML(t *testing.T) {
	pal := fixturePalette(t)
	for _, p := range loadAll(t) {
		var doc map[string]any
		if err := toml.Unmarshal([]byte(RenderStarship(p, pal)), &doc); err != nil {
			t.Fatalf("%s: %v", p.ID, err)
		}
		if doc["palette"] != brand.AppID {
			t.Errorf("%s: palette = %v", p.ID, doc["palette"])
		}
		pals, _ := doc["palettes"].(map[string]any)
		yz, _ := pals[brand.AppID].(map[string]any)
		if yz["on_primary"] != pal["onPrimary"] || len(yz) != len(Roles) {
			t.Errorf("%s: palettes.yozakura = %v", p.ID, yz)
		}
		if strings.Count(RenderStarship(p, pal), "\"#") != len(Roles) {
			t.Errorf("%s: hex colors outside the palette", p.ID)
		}
	}
}

func TestOMPIsValidJSON(t *testing.T) {
	pal := fixturePalette(t)
	for _, p := range loadAll(t) {
		var doc struct {
			Schema  string            `json:"$schema"`
			Version int               `json:"version"`
			Palette map[string]string `json:"palette"`
			Blocks  []struct {
				Type      string `json:"type"`
				Alignment string `json:"alignment"`
				Segments  []struct {
					Type       string `json:"type"`
					Style      string `json:"style"`
					Foreground string `json:"foreground"`
					Background string `json:"background"`
					Template   string `json:"template"`
				} `json:"segments"`
			} `json:"blocks"`
		}
		out := RenderOMP(p, pal)
		dec := json.NewDecoder(strings.NewReader(out))
		if err := dec.Decode(&doc); err != nil {
			t.Fatalf("%s: %v", p.ID, err)
		}
		if !strings.Contains(doc.Schema, "oh-my-posh") || doc.Version != 4 || len(doc.Blocks) == 0 {
			t.Errorf("%s: bad header %q v%d", p.ID, doc.Schema, doc.Version)
		}
		if doc.Palette["primary"] != pal["primary"] {
			t.Errorf("%s: palette not embedded", p.ID)
		}
		for _, b := range doc.Blocks {
			if b.Type != "prompt" && b.Type != "rprompt" {
				t.Errorf("%s: block type %q", p.ID, b.Type)
			}
			for _, s := range b.Segments {
				if s.Type == "" || s.Template == "" || !contains([]string{"plain", "powerline", "diamond"}, s.Style) {
					t.Errorf("%s: bad segment %+v", p.ID, s)
				}
				for _, c := range []string{s.Foreground, s.Background} {
					if c != "" && c != "transparent" && !strings.HasPrefix(c, "p:") {
						t.Errorf("%s: color %q is not a palette reference", p.ID, c)
					}
				}
			}
		}
	}
}

// TestStarshipRuns renders every preset through the real starship binary in
// a git repo with changes; skipped when starship or git are missing.
func TestStarshipRuns(t *testing.T) {
	bin, err := exec.LookPath("starship")
	if err != nil {
		t.Skip("starship not installed")
	}
	repo := fixtureRepo(t)
	pal := fixturePalette(t)
	for _, p := range loadAll(t) {
		cfg := filepath.Join(t.TempDir(), "starship.toml")
		if err := os.WriteFile(cfg, []byte(RenderStarship(p, pal)), 0o644); err != nil {
			t.Fatal(err)
		}
		for _, args := range [][]string{
			{"prompt", "--path", repo, "--status", "1", "--cmd-duration", "3500", "--jobs", "1"},
			{"prompt", "--right", "--path", repo},
		} {
			cmd := exec.Command(bin, args...)
			cmd.Dir = repo
			cmd.Env = append(os.Environ(), "STARSHIP_CONFIG="+cfg, "STARSHIP_LOG=warn", "STARSHIP_CACHE="+t.TempDir())
			var stderr bytes.Buffer
			cmd.Stderr = &stderr
			if err := cmd.Run(); err != nil {
				t.Errorf("%s %v: %v (%s)", p.ID, args, err, stderr.String())
			}
			if s := strings.TrimSpace(stderr.String()); s != "" {
				t.Errorf("%s %v: starship warned: %s", p.ID, args, s)
			}
		}
	}
}

func fixtureRepo(t *testing.T) string {
	t.Helper()
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git not installed")
	}
	dir := t.TempDir()
	for _, args := range [][]string{
		{"init", "-q", "-b", "main"},
		{"-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "init"},
	} {
		if out, err := exec.Command("git", append([]string{"-C", dir}, args...)...).CombinedOutput(); err != nil {
			t.Skipf("git %v: %v %s", args, err, out)
		}
	}
	if err := os.WriteFile(filepath.Join(dir, "go.mod"), []byte("module x\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	return dir
}

// TestOMPRuns renders every preset through a real oh-my-posh ($OMP_BIN or
// oh-my-posh on PATH); skipped when neither exists. oh-my-posh exits 0 even
// on a broken config, so its output is checked for error text.
func TestOMPRuns(t *testing.T) {
	bin := os.Getenv("OMP_BIN")
	if bin == "" {
		var err error
		if bin, err = exec.LookPath("oh-my-posh"); err != nil {
			t.Skip("oh-my-posh not installed (set OMP_BIN to a binary)")
		}
	}
	repo := fixtureRepo(t)
	pal := fixturePalette(t)
	for _, p := range loadAll(t) {
		cfg := filepath.Join(t.TempDir(), "omp.json")
		if err := os.WriteFile(cfg, []byte(RenderOMP(p, pal)), 0o644); err != nil {
			t.Fatal(err)
		}
		for _, args := range [][]string{
			{"print", "primary", "--status", "1", "--execution-time", "4200"},
			{"print", "right"},
		} {
			args = append(args, "--config", cfg, "--shell", "fish", "--pwd", repo)
			cmd := exec.Command(bin, args...)
			cmd.Dir = repo
			cmd.Env = append(os.Environ(), "HOME="+t.TempDir())
			var stdout, stderr bytes.Buffer
			cmd.Stdout, cmd.Stderr = &stdout, &stderr
			if err := cmd.Run(); err != nil {
				t.Errorf("%s %v: %v (%s)", p.ID, args[:2], err, stderr.String())
			}
			out := strings.ToLower(stdout.String() + stderr.String())
			for _, bad := range []string{"error", "unable to"} {
				if strings.Contains(out, bad) {
					t.Errorf("%s %v: oh-my-posh reported %q: %q", p.ID, args[:2], bad, stdout.String()+stderr.String())
				}
			}
			if args[1] == "primary" && stdout.Len() == 0 {
				t.Errorf("%s: empty prompt", p.ID)
			}
		}
	}
}
