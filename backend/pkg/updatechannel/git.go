package updatechannel

import (
	"context"
	"errors"
	"strings"
	"time"

	"yozakura/backend/pkg/proc"
)

// remoteTimeout bounds one ls-remote / fetch: a slow network gives "unknown"
// instead of a hung command.
const remoteTimeout = 30 * time.Second

// GitRepo is a checkout read through the git binary. Remote reads use
// ls-remote, which changes nothing in the checkout.
type GitRepo struct {
	Dir    string
	Remote string // default "origin"
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
	out, err := g.git(remoteTimeout, "ls-remote", "--tags", g.remote())
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
	out, err := g.git(remoteTimeout, "ls-remote", "--heads", g.remote(), "refs/heads/"+name)
	if err != nil {
		return "", err
	}
	sha, _, _ := strings.Cut(out, "\t")
	if sha == "" {
		return "", errors.New("no branch " + name + " on " + g.remote())
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

// Fetch brings the remote's tags and branch tips into the checkout (refs
// only; the working tree is not touched).
func (g GitRepo) Fetch() error {
	_, err := g.git(-1, "fetch", "--quiet", "--tags", g.remote())
	return err
}

// Dirty reports tracked files changed in the working tree.
func (g GitRepo) Dirty() bool {
	out, err := g.git(0, "status", "--porcelain", "--untracked-files=no")
	return err == nil && out != ""
}
