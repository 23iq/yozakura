package updatechannel

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

func gitIn(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", dir}, args...)...)
	cmd.Env = append(os.Environ(), "GIT_AUTHOR_NAME=t", "GIT_AUTHOR_EMAIL=t@t", "GIT_COMMITTER_NAME=t",
		"GIT_COMMITTER_EMAIL=t@t", "GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_NOSYSTEM=1")
	out, err := cmd.CombinedOutput()
	mustOK(t, err, "git %v: %s", args, out)
	return strings.TrimSpace(string(out))
}

// remoteWithTags: a bare "origin" whose main has commits tagged 0.3.0,
// 0.3.1 (annotated) and 0.3.2-beta.1, then one untagged commit; the clone
// is at the tip of main.
func remoteWithTags(t *testing.T) (origin, clone string) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git not installed")
	}
	root := t.TempDir()
	work := filepath.Join(root, "work")
	origin = filepath.Join(root, "origin.git")
	clone = filepath.Join(root, "clone")
	mustOK(t, os.MkdirAll(work, 0o755))
	gitIn(t, work, "init", "-q", "-b", "main")
	for _, v := range []string{"0.3.0", "0.3.1", "0.3.2-beta.1", "0.3.2-beta.1"} {
		mustOK(t, os.WriteFile(filepath.Join(work, "version"), []byte(v+"\n"), 0o644))
		gitIn(t, work, "add", "version")
		gitIn(t, work, "commit", "-q", "--allow-empty", "-m", "v"+v)
	}
	gitIn(t, work, "tag", "0.3.0", "HEAD~3")
	gitIn(t, work, "tag", "-a", "-m", "release", "0.3.1", "HEAD~2")
	gitIn(t, work, "tag", "0.3.2-beta.1", "HEAD~1")
	gitIn(t, root, "clone", "-q", "--bare", work, origin)
	gitIn(t, root, "clone", "-q", origin, clone)
	return origin, clone
}

func TestGitRepoResolve(t *testing.T) {
	_, clone := remoteWithTags(t)
	repo := GitRepo{Dir: clone}
	tags, err := repo.RemoteTags()
	mustOK(t, err)
	assert.Len(t, tags, 3)
	// The annotated tag resolves to its commit, not the tag object.
	assert.Equal(t, gitIn(t, clone, "rev-parse", "0.3.1^{commit}"), tags["0.3.1"])

	st := Resolve(repo, Stable, "0.3.2-beta.1")
	assert.Equal(t, UpToDate, st.State, "main is ahead of every tag")
	assert.Equal(t, "0.3.1", st.Target)
	st = Resolve(repo, Beta, "0.3.2-beta.1")
	assert.Equal(t, UpToDate, st.State)
	assert.Equal(t, "0.3.2-beta.1", st.Target)
	st = Resolve(repo, Git, "")
	assert.Equal(t, UpToDate, st.State)
	assert.Equal(t, "main", st.Branch)

	// On the 0.3.0 tag: both tag channels move forward, git returns to main.
	gitIn(t, clone, "checkout", "-q", "--detach", "0.3.0")
	assert.Equal(t, "", repo.Branch())
	assert.Equal(t, Available, Resolve(repo, Stable, "0.3.0").State)
	assert.Equal(t, "0.3.2-beta.1", Resolve(repo, Beta, "0.3.0").Target)
	st = Resolve(repo, Git, "0.3.0")
	assert.Equal(t, Available, st.State)
	assert.Equal(t, "main", st.Target)
	assert.False(t, repo.Dirty())
	mustOK(t, os.WriteFile(filepath.Join(clone, "version"), []byte("x\n"), 0o644))
	assert.True(t, repo.Dirty())
}

func TestGitRepoOffline(t *testing.T) {
	_, clone := remoteWithTags(t)
	gitIn(t, clone, "remote", "set-url", "origin", filepath.Join(t.TempDir(), "gone.git"))
	repo := GitRepo{Dir: clone}
	st := Resolve(repo, Beta, "0.3.1")
	assert.Equal(t, Unknown, st.State)
	assert.Contains(t, st.Note, "cannot reach the remote")
	assert.Equal(t, Unknown, Resolve(repo, Git, "").State)
}

func TestGitRepoFetch(t *testing.T) {
	origin, clone := remoteWithTags(t)
	other := filepath.Join(t.TempDir(), "other")
	gitIn(t, filepath.Dir(other), "clone", "-q", origin, other)
	gitIn(t, other, "commit", "-q", "--allow-empty", "-m", "0.3.2")
	gitIn(t, other, "tag", "0.3.2")
	gitIn(t, other, "push", "-q", "origin", "main", "0.3.2")

	repo := GitRepo{Dir: clone}
	st := Resolve(repo, Stable, "0.3.2-beta.1")
	assert.Equal(t, Available, st.State, "a tag not fetched yet but newer is an update")
	mustOK(t, repo.Fetch())
	st = Resolve(repo, Stable, "0.3.2-beta.1")
	assert.Equal(t, Available, st.State)
	assert.True(t, repo.IsAncestor(mustHead(t, repo), st.TargetCommit))
}

func mustHead(t *testing.T, r GitRepo) string {
	h, err := r.Head()
	mustOK(t, err)
	return h
}
