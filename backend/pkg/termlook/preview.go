package termlook

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"time"
)

// PreviewResult is a rendered prompt. Exact is true when a real engine drew
// it, false for the approximate Go renderer.
type PreviewResult struct {
	Left   [][]Span
	Right  []Span
	Exact  bool
	Engine string
	// Reason says why the preview is approximate: "engine_missing",
	// "git_missing", "timeout" or "error". Empty when Exact.
	Reason string
}

var (
	errEngineMissing = errors.New("engine not installed")
	errGitMissing    = errors.New("git not installed")
)

// engineBudget bounds each engine run.
const engineBudget = 3 * time.Second

func reasonOf(err error) string {
	switch {
	case errors.Is(err, errEngineMissing):
		return "engine_missing"
	case errors.Is(err, errGitMissing):
		return "git_missing"
	case errors.Is(err, context.DeadlineExceeded):
		return "timeout"
	}
	return "error"
}

// Preview renders preset p for cfg's engine, using the real engine in a
// fixture repo when it is installed and falling back to the approximate
// renderer when it is not (or fails).
func Preview(ctx context.Context, cfg Config, p Preset, pal Palette, env Env, width int) (PreviewResult, error) {
	if width < 20 {
		width = 80
	}
	res, err := previewExact(ctx, cfg, p, pal, env, width)
	if err == nil {
		return res, nil
	}
	left, right := RenderApprox(p, pal)
	return PreviewResult{Left: left, Right: right, Engine: cfg.Engine, Reason: reasonOf(err)}, nil
}

func previewExact(ctx context.Context, cfg Config, p Preset, pal Palette, env Env, width int) (PreviewResult, error) {
	bin := "starship"
	if cfg.Engine == EngineOMP {
		bin = "oh-my-posh"
	}
	path, ok := env.look(bin)
	if !ok {
		return PreviewResult{}, fmt.Errorf("%s: %w", bin, errEngineMissing)
	}
	dir, err := fixtureDir(ctx, env)
	if err != nil {
		return PreviewResult{}, err
	}
	tmp, err := os.MkdirTemp("", "termlook-")
	if err != nil {
		return PreviewResult{}, err
	}
	defer os.RemoveAll(tmp)
	file := filepath.Join(tmp, filepath.Base(ConfigFile(cfg, env)))
	if err := os.WriteFile(file, []byte(Render(cfg, p, pal)), 0o600); err != nil {
		return PreviewResult{}, err
	}
	w := strconv.Itoa(width)
	var primary, right []string
	if cfg.Engine == EngineOMP {
		base := []string{"print", "", "--config", file, "--pwd", dir, "--shell", "fish", "--terminal-width", w}
		primary, right = withArg(base, 1, "primary"), withArg(base, 1, "right")
	} else {
		primary = []string{"prompt", "--path", dir, "--terminal-width", w, "--status", "0", "--cmd-duration", "3200", "--jobs", "0"}
		right = append([]string{"prompt", "--right"}, primary[1:]...)
	}
	out, err := runEngine(ctx, path, primary, file, tmp)
	if err != nil {
		return PreviewResult{}, err
	}
	res := PreviewResult{Left: ParseANSI(out), Exact: true, Engine: cfg.Engine}
	if len(p.Right) > 0 {
		rout, err := runEngine(ctx, path, right, file, tmp)
		if err != nil {
			return PreviewResult{}, err
		}
		for _, line := range ParseANSI(rout) {
			res.Right = append(res.Right, line...)
		}
	}
	return res, nil
}

func withArg(a []string, i int, v string) []string {
	out := append([]string(nil), a...)
	out[i] = v
	return out
}

func runEngine(ctx context.Context, bin string, args []string, cfgFile, home string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, engineBudget)
	defer cancel()
	cmd := exec.CommandContext(ctx, bin, args...)
	cmd.Env = []string{
		"PATH=" + os.Getenv("PATH"), "HOME=" + home, "TERM=xterm-256color", "COLORTERM=truecolor",
		"LANG=C.UTF-8", "STARSHIP_CONFIG=" + cfgFile, "STARSHIP_SHELL=", "STARSHIP_LOG=error",
	}
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
