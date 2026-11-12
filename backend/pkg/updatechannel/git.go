package updatechannel

import (
	"context"
	"fmt"
	"strconv"
	"strings"
	"time"

	"yozakura/backend/pkg/proc"
)

// remoteTimeout bounds one ls-remote: a slow network gives "unknown"
// instead of a hung command.
const remoteTimeout = 30 * time.Second

// GitRepo is a checkout read through the git binary. Remote reads use
// ls-remote, which changes nothing in the checkout.
type GitRepo struct {
	Dir    string
	Remote string // default "origin"
	// ReadTimeout bounds one ls-remote (default 30 s); the read-only
	// reports use a shorter one so an offline check answers quickly.
	ReadTimeout time.Duration
}

func (g GitRepo) readTimeout() time.Duration {
	if g.ReadTimeout > 0 {
		return g.ReadTimeout
	}
	return remoteTimeout
}

func (g GitRepo) remote() string {
	if g.Remote == "" {
		return "origin"
	}
	return g.Remote
}

func (g GitRepo) git(timeout time.Duration, args ...string) (string, error) {
	out, err := proc.RunWith(context.Background(), proc.Options{Timeout: timeout},
		"git", append([]string{"-C", g.Dir}, args...)...)
	return strings.TrimSpace(string(out)), err
}

// Head implements Repo.
func (g GitRepo) Head() (string, error) {
	return g.git(0, "rev-parse", "HEAD")
}

// Branch implements Repo.
func (g GitRepo) Branch() string {
	b, err := g.git(0, "symbolic-ref", "--quiet", "--short", "HEAD")
	if err != nil {
		return ""
	}
	return b
}

// RemoteTags implements Repo: annotated tags resolve to their commit.
func (g GitRepo) RemoteTags() (map[string]string, error) {
	out, err := g.git(g.readTimeout(), "ls-remote", "--tags", g.remote())
	if err != nil {
		return nil, err
	}
	return parseLsRemoteTags(out), nil
}

func parseLsRemoteTags(out string) map[string]string {
	tags := map[string]string{}
	peeled := map[string]bool{}
	for _, line := range strings.Split(out, "\n") {
		sha, ref, ok := strings.Cut(strings.TrimSpace(line), "\t")
		if !ok || !strings.HasPrefix(ref, "refs/tags/") {
			continue
		}
		name := strings.TrimPrefix(ref, "refs/tags/")
		if base, isPeeled := strings.CutSuffix(name, "^{}"); isPeeled {
			tags[base], peeled[base] = sha, true
		} else if !peeled[name] {
			tags[name] = sha
		}
	}
	return tags
}

// RemoteBranch implements Repo.
func (g GitRepo) RemoteBranch(name string) (string, error) {
	out, err := g.git(g.readTimeout(), "ls-remote", "--heads", g.remote(), "refs/heads/"+name)
	if err != nil {
		return "", err
	}
	sha, _, _ := strings.Cut(out, "\t")
	if sha == "" {
		return "", fmt.Errorf("no branch %s on %s: %w", name, g.remote(), ErrNoBranch)
	}
	return sha, nil
}

// IsAncestor implements Repo.
func (g GitRepo) IsAncestor(a, b string) bool {
	if a == "" || b == "" {
		return false
	}
	_, err := g.git(0, "merge-base", "--is-ancestor", a, b)
	return err == nil
}

// LocalCommits implements Repo; 0 when git cannot tell.
func (g GitRepo) LocalCommits(exclude []string) int {
	args := []string{"rev-list", "--count", "HEAD", "--not", "--remotes"}
	for _, c := range exclude {
		// rev-list fails on a commit this checkout does not have
		if g.IsAncestor(c, c) {
			args = append(args, c)
		}
	}
	out, err := g.git(0, args...)
	if err != nil {
		return 0
	}
	n, _ := strconv.Atoi(out)
	return n
}

// Fetch brings the remote's tags and branch tips into the checkout (refs
// only; the working tree is not touched). Tags are forced: a release tag
// moved or re-created on the remote replaces the local one instead of
// failing every later fetch ("would clobber existing tag").
func (g GitRepo) Fetch() error {
	_, err := g.git(-1, "fetch", "--quiet", "--tags", "--force", g.remote())
	return err
}

// Dirty reports tracked files changed in the working tree.
func (g GitRepo) Dirty() bool {
	out, err := g.git(0, "status", "--porcelain", "--untracked-files=no")
	return err == nil && out != ""
}
