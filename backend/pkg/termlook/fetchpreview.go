package termlook

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// FetchPreviewResult is the greeting as fastfetch prints it. Exact is false
// when fastfetch could not run (Reason: fastfetch_missing, timeout, error):
// Lines are then the bundled sample of the look. ImageLogo: the custom
// picture shows in kitty only, the preview has the text logo used
// everywhere else.
type FetchPreviewResult struct {
	Lines     [][]Span
	Exact     bool
	Reason    string
	ImageLogo bool
}

// fetchBudget bounds one fastfetch run (it probes the GPU, packages, ...).
const fetchBudget = 6 * time.Second

// FetchPreview runs fastfetch with the config cfg would write (in a temp
// dir; nothing of the user's changes) and renders its output with table as
// the terminal's 16 colours. dir is assets/terminal/fastfetch.
func FetchPreview(ctx context.Context, cfg GreetingConfig, presets []FetchPreset, pal Palette, dir string, env Env, table [16]string) (FetchPreviewResult, error) {
	p, ok := FindFetchPreset(presets, cfg.Preset)
	if !ok {
		return FetchPreviewResult{}, fmt.Errorf("unknown fastfetch preset %q", cfg.Preset)
	}
	sample := func(reason string) (FetchPreviewResult, error) {
		lines, err := FetchSample(dir, p.ID, pal, table)
		return FetchPreviewResult{Lines: lines, Reason: reason}, err
	}
	bin, ok := env.look("fastfetch")
	if !ok {
		return sample("fastfetch_missing")
	}
	tmp, err := os.MkdirTemp("", "termfetch-")
	if err != nil {
		return FetchPreviewResult{}, err
	}
	defer os.RemoveAll(tmp)
	res := FetchPreviewResult{}
	args := []string{"--pipe", "false"}
	if !p.Own {
		penv := Env{Home: tmp, ConfigHome: tmp, AppID: "preview"}
		cmd, _, err := writeFetchConfigs(cfg, p, pal, SakuraLogoFile(dir), penv)
		if err != nil {
			return FetchPreviewResult{}, err
		}
		res.ImageLogo = cmd.kitty != ""
		args = append([]string{"--config", cmd.cfg}, args...)
	}
	out, err := runFetch(ctx, bin, args)
	if err != nil {
		s, serr := sample(reasonOf(err))
		s.ImageLogo = res.ImageLogo
		return s, serr
	}
	res.Lines, res.Exact = RenderScreen(out, table), true
	return res, nil
}

// SakuraLogoFile is the bundled text logo in dir (assets/terminal/fastfetch).
func SakuraLogoFile(dir string) string { return filepath.Join(dir, "logos", "sakura.txt") }

func runFetch(ctx context.Context, bin string, args []string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, fetchBudget)
	defer cancel()
	cmd := exec.CommandContext(ctx, bin, args...)
	// the user's own environment (their fastfetch config for "own", the
	// detection of shell / terminal / WM), with colours on and no terminal
	// graphics
	var env []string
	for _, kv := range os.Environ() {
		k, _, _ := strings.Cut(kv, "=")
		switch k {
		case "NO_COLOR", "TERM", "COLORTERM", "COLUMNS", "KITTY_WINDOW_ID":
			continue
		}
		env = append(env, kv)
	}
	cmd.Env = append(env, "TERM=xterm-256color", "COLORTERM=truecolor", "COLUMNS=120")
	var stdout, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	if err := cmd.Run(); err != nil {
		if ctx.Err() != nil {
			err = ctx.Err()
		}
		return "", fmt.Errorf("%s: %w: %s", filepath.Base(bin), err, stderr.String())
	}
	return stdout.String(), nil
}
