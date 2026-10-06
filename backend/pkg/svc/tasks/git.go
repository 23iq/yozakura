package tasks

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"yozakura/backend/pkg/brand"
)

// git runs `git -C dir args...` (argv only, never a shell) with a timeout
// and returns trimmed stdout; the error carries stderr.
func git(dir string, args ...string) (string, error) {
	out, err := gitRaw(dir, nil, args...)
	return strings.TrimRight(string(out), "\n"), err
}

func gitRaw(dir string, env []string, args ...string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "git", append([]string{"-C", dir}, args...)...)
	cmd.Env = append(os.Environ(), "GIT_TERMINAL_PROMPT=0", "LC_ALL=C")
	cmd.Env = append(cmd.Env, env...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		msg := strings.TrimSpace(stderr.String())
		if msg == "" {
			msg = strings.TrimSpace(string(out))
		}
		return out, fmt.Errorf("git %s: %s", args[0], firstNonEmpty(msg, err.Error()))
	}
	return out, nil
}

func firstNonEmpty(v ...string) string {
	for _, s := range v {
		if s != "" {
			return s
		}
	}
	return ""
}

// isGitRepo reports whether dir is inside a work tree.
func isGitRepo(dir string) bool {
	out, err := git(dir, "rev-parse", "--is-inside-work-tree")
	return err == nil && out == "true"
}

// repoRoot returns the top-level directory of the work tree holding dir.
func repoRoot(dir string) (string, error) { return git(dir, "rev-parse", "--show-toplevel") }

// currentBranch returns the checked-out branch ("" when detached).
func currentBranch(dir string) string {
	out, err := git(dir, "symbolic-ref", "--quiet", "--short", "HEAD")
	if err != nil {
		return ""
	}
	return out
}

// addWorktree creates path on a new branch from base.
func addWorktree(repo, path, branch, base string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	_, err := git(repo, "worktree", "add", "-b", branch, path, base)
	return err
}

// removeWorktree deletes the worktree and its branch; missing ones are fine.
func removeWorktree(repo, path, branch string) error {
	var errs []error
	if path != "" {
		if _, err := os.Stat(path); err == nil {
			if _, err := git(repo, "worktree", "remove", "--force", path); err != nil {
				errs = append(errs, err)
			}
		}
		_, _ = git(repo, "worktree", "prune")
	}
	if branch != "" {
		if _, err := git(repo, "rev-parse", "--verify", "--quiet", "refs/heads/"+branch); err == nil {
			if _, err := git(repo, "branch", "-D", branch); err != nil {
				errs = append(errs, err)
			}
		}
	}
	return errors.Join(errs...)
}

// botIdentity signs the temporary commits on task branches (they are
// squashed away on accept), so a missing user identity cannot block them.
var botIdentity = []string{
	"GIT_AUTHOR_NAME=" + brand.DisplayName, "GIT_AUTHOR_EMAIL=" + brand.AppID + "@localhost",
	"GIT_COMMITTER_NAME=" + brand.DisplayName, "GIT_COMMITTER_EMAIL=" + brand.AppID + "@localhost",
}

// snapshot commits everything left uncommitted in a task worktree; it
// returns false when there was nothing to commit.
func snapshot(worktree, message string) (bool, error) {
	if _, err := git(worktree, "add", "-A"); err != nil {
		return false, err
	}
	if _, err := git(worktree, "diff", "--cached", "--quiet"); err == nil {
		return false, nil
	}
	_, err := gitRaw(worktree, botIdentity, "commit", "--no-verify", "-q", "-m", message)
	return err == nil, err
}

// changeStats is the diff of rev (the work tree when "") against base.
func changeStats(dir, base, rev string) (*ChangeStats, error) {
	args := []string{"diff", "--numstat", base}
	if rev != "" {
		args = append(args, rev)
	}
	out, err := git(dir, args...)
	if err != nil {
		return nil, err
	}
	cs := &ChangeStats{Paths: []string{}}
	for _, line := range strings.Split(out, "\n") {
		f := strings.SplitN(line, "\t", 3)
		if len(f) != 3 {
			continue
		}
		ins, _ := strconv.Atoi(f[0])
		del, _ := strconv.Atoi(f[1])
		cs.Files++
		cs.Insertions += ins
		cs.Deletions += del
		cs.Paths = append(cs.Paths, f[2])
	}
	return cs, nil
}

// dirtyPaths lists paths with uncommitted changes (tracked or untracked).
func dirtyPaths(dir string) ([]string, error) {
	out, err := gitRaw(dir, nil, "status", "--porcelain=v1", "-z", "--untracked-files=all")
	if err != nil {
		return nil, err
	}
	var paths []string
	entries := strings.Split(string(out), "\x00")
	for i := 0; i < len(entries); i++ {
		e := entries[i]
		if len(e) < 4 {
			continue
		}
		paths = append(paths, e[3:])
		if e[0] == 'R' || e[0] == 'C' {
			i++ // the rename source follows
			if i < len(entries) && entries[i] != "" {
				paths = append(paths, entries[i])
			}
		}
	}
	return paths, nil
}

// ConflictError is returned by Accept when the main checkout cannot take
// the task's changes; Paths names the files involved.
type ConflictError struct {
	Reason string   `json:"reason"` // dirty | conflict | detached
	Paths  []string `json:"paths"`
}

func (e *ConflictError) Error() string {
	switch e.Reason {
	case "dirty":
		return "the project has uncommitted changes in files this task changes: " + strings.Join(e.Paths, ", ") +
			" (commit or stash them first)"
	case "conflict":
		return "the task's changes conflict with the current branch in: " + strings.Join(e.Paths, ", ")
	}
	return "the project is not on a branch (detached HEAD)"
}

// integrate puts branch's changes onto the project's current branch as one
// commit (squash) or a merge commit, without touching unrelated local
// changes: the result is computed with merge-tree/commit-tree and then
// fast-forwarded into the checkout. Returns the new commit.
func integrate(project, branch, message, mode string) (string, error) {
	if currentBranch(project) == "" {
		return "", &ConflictError{Reason: "detached"}
	}
	head, err := git(project, "rev-parse", "HEAD")
	if err != nil {
		return "", err
	}
	base, err := git(project, "merge-base", head, branch)
	if err != nil {
		return "", err
	}
	changed, err := git(project, "diff", "--name-only", base, branch)
	if err != nil {
		return "", err
	}
	if strings.TrimSpace(changed) == "" {
		return "", errors.New("the task made no changes")
	}
	dirty, err := dirtyPaths(project)
	if err != nil {
		return "", err
	}
	if both := intersect(strings.Split(changed, "\n"), dirty); len(both) > 0 {
		return "", &ConflictError{Reason: "dirty", Paths: both}
	}
	out, mergeErr := gitRaw(project, nil, "merge-tree", "--write-tree", "--name-only", "--no-messages", head, branch)
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	if mergeErr != nil {
		if len(lines) > 1 {
			return "", &ConflictError{Reason: "conflict", Paths: uniq(lines[1:])}
		}
		return "", mergeErr
	}
	tree := strings.TrimSpace(lines[0])
	args := []string{"commit-tree", tree, "-p", head}
	if mode == "merge" {
		args = append(args, "-p", branch)
	}
	commit, err := git(project, append(args, "-m", message)...)
	if err != nil {
		return "", err
	}
	if _, err := git(project, "merge", "--ff-only", "-q", commit); err != nil {
		return "", err
	}
	return commit, nil
}

// commitInPlace commits every change of an in-place task.
func commitInPlace(project, message string) (string, error) {
	if _, err := git(project, "add", "-A"); err != nil {
		return "", err
	}
	if _, err := git(project, "diff", "--cached", "--quiet"); err == nil {
		return "", errors.New("the task made no changes")
	}
	if _, err := git(project, "commit", "-q", "-m", message); err != nil {
		return "", err
	}
	return git(project, "rev-parse", "HEAD")
}

func intersect(a, b []string) []string {
	set := map[string]bool{}
	for _, x := range b {
		set[x] = true
	}
	var out []string
	for _, x := range a {
		if x != "" && set[x] {
			out = append(out, x)
		}
	}
	return uniq(out)
}

func uniq(in []string) []string {
	seen := map[string]bool{}
	out := []string{}
	for _, s := range in {
		if s = strings.TrimSpace(s); s != "" && !seen[s] {
			seen[s] = true
			out = append(out, s)
		}
	}
	return out
}
