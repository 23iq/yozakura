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

// maxFetchOutput caps what is kept of fastfetch's output: a logo or config
// of the user's could make it print without end.
const maxFetchOutput = 256 << 10

// cappedBuffer keeps the first max bytes written and discards the rest
// (the writer never fails, so the process is not cut off mid-write).
type cappedBuffer struct {
	buf bytes.Buffer
	max int
}

func (c *cappedBuffer) Write(p []byte) (int, error) {
	if room := c.max - c.buf.Len(); room > 0 {
		c.buf.Write(p[:min(len(p), room)])
	}
	return len(p), nil
}

func (c *cappedBuffer) String() string { return c.buf.String() }

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
	out, err := runFetch(ctx, bin, args, cfg.LoginShell)
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

// fetchArgv runs bin under the user's login shell, as a new terminal would,
// so fastfetch reports that shell (not the daemon) as the shell. The
// command and its arguments stay argv: the shell code is constant, and
// "; :" keeps bash / zsh from replacing themselves with fastfetch.
func fetchArgv(bin string, args []string, shell string) []string {
	direct := append([]string{bin}, args...)
	if !filepath.IsAbs(shell) {
		return direct
	}
	if st, err := os.Stat(shell); err != nil || st.IsDir() || st.Mode()&0o111 == 0 {
		return direct
	}
	switch filepath.Base(shell) {
	case "fish":
		return append([]string{shell, "--no-config", "-c", "$argv[1] $argv[2..-1]", "--"}, direct...)
	case "bash", "zsh", "sh", "dash":
		return append([]string{shell, "-c", `"$0" "$@"; :`}, direct...)
	}
	return direct
}

func runFetch(ctx context.Context, bin string, args []string, shell string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, fetchBudget)
	defer cancel()
	argv := fetchArgv(bin, args, shell)
	cmd := exec.CommandContext(ctx, argv[0], argv[1:]...)
	// the user's own environment (their fastfetch config for "own", the
	// detection of shell / terminal / WM), with colours on and no terminal
	// graphics
	var env []string
	for _, kv := range os.Environ() {
		k, _, _ := strings.Cut(kv, "=")
		switch k {
		case "NO_COLOR", "TERM", "COLORTERM", "COLUMNS", "KITTY_WINDOW_ID", "TERM_PROGRAM":
			continue
		}
		env = append(env, kv)
	}
	// the preview is a kitty window: fastfetch names kitty as the terminal
	cmd.Env = append(env, "TERM=xterm-256color", "COLORTERM=truecolor", "COLUMNS=120", "TERM_PROGRAM=kitty")
	stdout, stderr := &cappedBuffer{max: maxFetchOutput}, &cappedBuffer{max: 4 << 10}
	cmd.Stdout, cmd.Stderr = stdout, stderr
	if err := cmd.Run(); err != nil {
		if ctx.Err() != nil {
			err = ctx.Err()
		}
		return "", fmt.Errorf("%s: %w: %s", filepath.Base(bin), err, stderr.String())
	}
	return stdout.String(), nil
}
