package termlook

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"time"
)

var fixtureMu sync.Mutex

// fixtureBudget bounds the one-time creation of the fixture.
const fixtureBudget = 5 * time.Second

// fixtureDir returns the fixture git repo the real preview runs in,
// creating it once: branch main, one committed file, one modified file and
// a package.json so the node segment shows.
func fixtureDir(ctx context.Context, env Env) (string, error) {
	git, ok := env.look("git")
	if !ok {
		return "", errGitMissing
	}
	fixtureMu.Lock()
	defer fixtureMu.Unlock()
	dir := filepath.Join(env.cacheHome(), env.AppID, "term-fixture", "yozakura")
	if _, err := os.Stat(filepath.Join(dir, ".git", "HEAD")); err == nil {
		return dir, nil
	}
	ctx, cancel := context.WithTimeout(ctx, fixtureBudget)
	defer cancel()
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}
	write := func(name, body string) error { return os.WriteFile(filepath.Join(dir, name), []byte(body), 0o644) }
	if err := write("main.go", "package main\n"); err != nil {
		return "", err
	}
	if err := write("package.json", "{\"name\":\"yozakura\",\"version\":\"1.0.0\"}\n"); err != nil {
		return "", err
	}
	run := func(args ...string) error {
		cmd := exec.CommandContext(ctx, git, args...)
		cmd.Dir = dir
		cmd.Env = []string{"PATH=" + os.Getenv("PATH"), "HOME=" + dir, "GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_SYSTEM=/dev/null",
			"GIT_AUTHOR_DATE=2026-01-01T00:00:00Z", "GIT_COMMITTER_DATE=2026-01-01T00:00:00Z"}
		if out, err := cmd.CombinedOutput(); err != nil {
			return fmt.Errorf("git %v: %w: %s", args, err, out)
		}
		return nil
	}
	steps := [][]string{
		{"init", "-q", "-b", "main"},
		{"add", "main.go", "package.json"},
		{"-c", "user.name=yozakura", "-c", "user.email=yozakura@localhost", "-c", "commit.gpgsign=false", "commit", "-q", "-m", "fixture"},
	}
	for _, s := range steps {
		if err := run(s...); err != nil {
			_ = os.RemoveAll(filepath.Join(dir, ".git"))
			return "", err
		}
	}
	if err := write("main.go", "package main\n\nfunc main() {}\n"); err != nil {
		return "", err
	}
	return dir, nil
}
