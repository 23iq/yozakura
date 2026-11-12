package main

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/catalog"
)

func gitT(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", dir}, args...)...)
	cmd.Env = append(os.Environ(), "GIT_AUTHOR_NAME=t", "GIT_AUTHOR_EMAIL=t@t", "GIT_COMMITTER_NAME=t",
		"GIT_COMMITTER_EMAIL=t@t", "GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_NOSYSTEM=1")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v: %s", args, err, out)
	}
	return strings.TrimSpace(string(out))
}

// fakeCheckout: a bare origin whose main has commits tagged 0.4.0, 0.4.1
// and 0.4.2-beta.1 plus one untagged commit, and a clone of it at the tip
// of main (how existing installs sit today). Its install.sh only has to
// exist and know --ref (the installer itself is replaced in the tests).
func fakeCheckout(t *testing.T) (clone string) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git not installed")
	}
	root := t.TempDir()
	work := filepath.Join(root, "work")
	clone = filepath.Join(root, "clone")
	if err := os.MkdirAll(work, 0o755); err != nil {
		t.Fatal(err)
	}
	gitT(t, work, "init", "-q", "-b", "main")
	os.WriteFile(filepath.Join(work, "install.sh"), []byte("# --ref) is understood\n"), 0o755)
	os.WriteFile(filepath.Join(work, "shell.qml"), []byte("\n"), 0o644)
	for _, v := range []string{"0.4.0", "0.4.1", "0.4.2-beta.1", "0.4.2-beta.1"} {
		os.WriteFile(filepath.Join(work, "version"), []byte(v+"\n"), 0o644)
		gitT(t, work, "add", ".")
		gitT(t, work, "commit", "-q", "--allow-empty", "-m", v)
	}
	gitT(t, work, "tag", "0.4.0", "HEAD~3")
	gitT(t, work, "tag", "-a", "-m", "release", "0.4.1", "HEAD~2")
	gitT(t, work, "tag", "0.4.2-beta.1", "HEAD~1")
	gitT(t, root, "clone", "-q", "--bare", work, filepath.Join(root, "origin.git"))
	gitT(t, root, "clone", "-q", filepath.Join(root, "origin.git"), clone)
	return clone
}

type updateRun struct {
	env       *updateEnv
	installer [][]string
	out, errb bytes.Buffer
}

func newUpdateRun(t *testing.T, src string) *updateRun {
	sandbox(t)
	r := &updateRun{}
	r.env = &updateEnv{
		out: &r.out, errOut: &r.errb, src: src,
		store: func() (*catalog.Store, error) {
			env, err := loadConfigEnv()
			if err != nil {
				return nil, err
			}
			return env.store, nil
		},
		runInstaller: func(args []string) error { r.installer = append(r.installer, args); return nil },
	}
	return r
}

func (r *updateRun) run(args ...string) int {
	r.out.Reset()
	r.errb.Reset()
	return runUpdate(args, r.env)
}

func TestUpdateChannelShowAndSet(t *testing.T) {
	clone := fakeCheckout(t)
	r := newUpdateRun(t, clone)
	head := gitT(t, clone, "rev-parse", "--short=7", "HEAD")

	assert.Equal(t, 0, r.run("channel"))
	out := r.out.String()
	assert.Contains(t, out, "Installed  0.4.2-beta.1 ("+head+", on main)")
	assert.Contains(t, out, "Channel    stable (default)")
	assert.Contains(t, out, "Target     0.4.1 (")
	assert.Contains(t, out, "Status     up to date")

	assert.Equal(t, 0, r.run("channel", "beta"))
	out = r.out.String()
	assert.Contains(t, out, "Update channel: stable -> beta (saved as system.updateChannel)")
	assert.Contains(t, out, "Channel    beta (system.updateChannel)")
	assert.Contains(t, out, "Target     0.4.2-beta.1 (")
	assert.Empty(t, r.installer, "setting the channel does not update")

	home, _ := os.UserHomeDir()
	data, err := os.ReadFile(filepath.Join(home, "xdg_config_home", brand.AppID, "config", "system.json"))
	assert.NoError(t, err)
	assert.Contains(t, string(data), `"updateChannel": "beta"`)

	assert.Equal(t, 0, r.run("channel", "beta"))
	assert.Contains(t, r.out.String(), "Update channel: beta (unchanged)")

	assert.Equal(t, 2, r.run("channel", "nightly"))
	assert.Contains(t, r.errb.String(), `unknown channel "nightly" (one of: stable, beta, git)`)
	assert.Equal(t, 2, r.run("channel", "beta", "git"))

	// git: the tip of main, which the clone already has
	assert.Equal(t, 0, r.run("channel", "git"))
	assert.Contains(t, r.out.String(), "Target     main (")
	assert.Contains(t, r.out.String(), "Status     up to date")
}

func TestUpdateChannelOffline(t *testing.T) {
	clone := fakeCheckout(t)
	gitT(t, clone, "remote", "set-url", "origin", filepath.Join(t.TempDir(), "gone.git"))
	r := newUpdateRun(t, clone)
	assert.Equal(t, 0, r.run("channel"), "offline is not a failure")
	assert.Contains(t, r.out.String(), "Target     unknown: cannot reach the remote")
	assert.Equal(t, 0, r.run("--check"))
	assert.Contains(t, r.out.String(), "Target     unknown")
	assert.Equal(t, 1, r.run(), "an update needs the remote")
	assert.Contains(t, r.errb.String(), "cannot fetch updates")
	assert.Empty(t, r.installer)
}

func TestUpdateStaysAheadOfReleases(t *testing.T) {
	clone := fakeCheckout(t)
	r := newUpdateRun(t, clone)
	before := gitT(t, clone, "rev-parse", "HEAD")

	assert.Equal(t, 0, r.run("--check"))
	assert.Contains(t, r.out.String(), "Status     up to date")

	assert.Equal(t, 0, r.run())
	assert.Contains(t, r.out.String(), "is up to date on the stable channel (newest release: 0.4.1)")
	assert.Equal(t, 0, r.run("--channel", "beta"))
	assert.Contains(t, r.out.String(), "is up to date on the beta channel (newest release: 0.4.2-beta.1)")
	assert.Empty(t, r.installer, "main past the newest tag is never rewound")
	assert.Equal(t, before, gitT(t, clone, "rev-parse", "HEAD"))
}

func TestUpdateMovesToTheChannelTarget(t *testing.T) {
	clone := fakeCheckout(t)
	gitT(t, clone, "checkout", "-q", "--detach", "0.4.0")
	r := newUpdateRun(t, clone)
	script := filepath.Join(clone, "install.sh")

	assert.Equal(t, 0, r.run("--check"))
	assert.Contains(t, r.out.String(), "Status     update available: "+brand.AppID+" update")
	assert.Empty(t, r.installer, "--check changes nothing")

	assert.Equal(t, 0, r.run())
	assert.Contains(t, r.out.String(), "to 0.4.1 (stable channel)")
	assert.Equal(t, []string{script, "--update", "--dir", clone, "--channel", "stable", "--ref", "0.4.1"}, r.installer[0])

	assert.Equal(t, 0, r.run("--channel", "beta"))
	assert.Equal(t, []string{script, "--update", "--dir", clone, "--channel", "beta", "--ref", "0.4.2-beta.1"}, r.installer[1])

	// git from a release checkout: back to main, no tag
	assert.Equal(t, 0, r.run("--channel=git"))
	assert.Equal(t, []string{script, "--update", "--dir", clone, "--channel", "git"}, r.installer[2])

	assert.Equal(t, 2, r.run("--channel", "nightly"))
	assert.Equal(t, 2, r.run("now"))
}

func TestUpdateGitChannelAlwaysRunsTheInstaller(t *testing.T) {
	clone := fakeCheckout(t)
	r := newUpdateRun(t, clone)
	assert.Equal(t, 0, r.run("channel", "git"))
	assert.Equal(t, 0, r.run())
	assert.Len(t, r.installer, 1, "git pulls and rebuilds as before channels")
	assert.Equal(t, []string{"--channel", "git"}, r.installer[0][len(r.installer[0])-2:])
}

func TestUpdateRefusesASilentDowngrade(t *testing.T) {
	clone := fakeCheckout(t)
	// a local line off 0.4.0 that already says 0.5.0
	gitT(t, clone, "checkout", "-q", "-b", "local", "0.4.0")
	os.WriteFile(filepath.Join(clone, "version"), []byte("0.5.0\n"), 0o644)
	gitT(t, clone, "commit", "-q", "-am", "0.5.0")
	r := newUpdateRun(t, clone)

	assert.Equal(t, 0, r.run("--check"))
	assert.Contains(t, r.out.String(), "it stays unless you pass --allow-downgrade")
	assert.Equal(t, 0, r.run())
	assert.Contains(t, r.out.String(), "is ahead of 0.4.1, the newest stable release; it stays as it is")
	assert.Empty(t, r.installer)

	assert.Equal(t, 0, r.run("--allow-downgrade"))
	assert.Equal(t, []string{"--channel", "stable", "--ref", "0.4.1"}, r.installer[0][len(r.installer[0])-4:])
}

func TestUpdateOldInstallerOnlyFollowsGit(t *testing.T) {
	clone := fakeCheckout(t)
	gitT(t, clone, "checkout", "-q", "--detach", "0.4.0")
	os.WriteFile(filepath.Join(clone, "install.sh"), []byte("# no channels\n"), 0o755)
	r := newUpdateRun(t, clone)
	assert.Equal(t, 1, r.run())
	assert.Contains(t, r.errb.String(), "predates update channels")
	assert.Equal(t, 0, r.run("--channel", "git"))
	assert.Equal(t, []string{filepath.Join(clone, "install.sh"), "--update", "--dir", clone}, r.installer[0])
}

func TestUpdateNixAndNoCheckout(t *testing.T) {
	r := newUpdateRun(t, t.TempDir())
	assert.Equal(t, 1, r.run())
	assert.Contains(t, r.errb.String(), "no git checkout")
	assert.Equal(t, 0, r.run("channel"))
	assert.Contains(t, r.out.String(), "Target     unknown (no git checkout)")

	r.env.nix = true
	assert.Equal(t, 0, r.run())
	assert.Contains(t, r.out.String(), "Update channels do not apply to Nix installs.")
	assert.Equal(t, 0, r.run("--check"))
	assert.Contains(t, r.out.String(), "do not apply")
	assert.Equal(t, 0, r.run("channel", "beta"))
	assert.Contains(t, r.out.String(), "channels do not apply")
	assert.Empty(t, r.installer)
}

func TestUpdateCompletion(t *testing.T) {
	for _, sh := range []string{"bash", "zsh", "fish"} {
		s, err := completionScript(sh)
		assert.NoError(t, err)
		assert.Contains(t, s, "channel --channel --check --allow-downgrade", sh)
		assert.Contains(t, s, "stable beta git", sh)
		assert.NotContains(t, s, "{updateSubs}", sh)
		assert.NotContains(t, s, "{channelNames}", sh)
	}
	s, _ := completionScript("bash")
	out, err := exec.Command("bash", "-n", "-c", s).CombinedOutput()
	assert.NoError(t, err, string(out))
}

func TestUpdateHelp(t *testing.T) {
	r := newUpdateRun(t, "")
	assert.Equal(t, 0, r.run("--help"))
	out := r.out.String()
	assert.Contains(t, out, brand.AppID+" update channel [stable|beta|git]")
	assert.Contains(t, out, brand.AppID+" config set\n                         system.updateChannel NAME")
	assert.NotContains(t, out, "{bin}")
	assert.NotContains(t, out, "{floor}")
	assert.Contains(t, out, "newer than 0.3.1 (the last one without update channels)")
}

// pushFromOther commits on origin's main from a second clone, tags the
// commit with each tag and pushes; deletes the remote tags in drop first.
func pushFromOther(t *testing.T, clone string, drop []string, tags ...string) {
	t.Helper()
	other := filepath.Join(t.TempDir(), "other")
	gitT(t, filepath.Dir(other), "clone", "-q", filepath.Join(filepath.Dir(clone), "origin.git"), other)
	for _, tag := range drop {
		gitT(t, other, "push", "-q", "origin", ":refs/tags/"+tag)
	}
	gitT(t, other, "commit", "-q", "--allow-empty", "-m", "upstream")
	gitT(t, other, "push", "-q", "origin", "main")
	for _, tag := range tags {
		gitT(t, other, "tag", tag)
		gitT(t, other, "push", "-q", "origin", tag)
	}
}

func TestUpdateOnlyPreChannelReleases(t *testing.T) {
	// Today's situation: every release predates update channels. Stable
	// and beta have no target; nothing moves, --allow-downgrade included.
	clone := fakeCheckout(t)
	pushFromOther(t, clone, []string{"0.4.0", "0.4.1", "0.4.2-beta.1"}, "0.3.0", "0.3.1")
	gitT(t, clone, "fetch", "-q", "--prune", "--prune-tags", "origin")
	before := gitT(t, clone, "rev-parse", "HEAD")
	r := newUpdateRun(t, clone)

	assert.Equal(t, 0, r.run("channel"))
	assert.Contains(t, r.out.String(), "Target     none: no release with update channels yet (0.3.1 and older predate them); staying on 0.4.2-beta.1 (")
	assert.Equal(t, 0, r.run("--check", "--channel", "beta"))
	assert.Contains(t, r.out.String(), "Target     none: no release with update channels yet")
	for _, args := range [][]string{{}, {"--channel", "beta"}, {"--allow-downgrade"}} {
		assert.Equal(t, 0, r.run(args...), args)
		assert.Contains(t, r.out.String(), "No release with update channels on the", args)
		assert.Contains(t, r.out.String(), "staying on 0.4.2-beta.1 (", args)
	}
	assert.Empty(t, r.installer)
	assert.Equal(t, before, gitT(t, clone, "rev-parse", "HEAD"))
}

func TestUpdateKeepsLocalCommits(t *testing.T) {
	// Main with a tweak committed here; then a newer release upstream.
	clone := fakeCheckout(t)
	os.WriteFile(filepath.Join(clone, "install.sh"), []byte("# --ref) --allow-downgrade) are understood\n"), 0o755)
	gitT(t, clone, "commit", "-q", "-am", "my tweak")
	pushFromOther(t, clone, nil, "0.5.0")
	r := newUpdateRun(t, clone)

	assert.Equal(t, 0, r.run("--check"))
	assert.Contains(t, r.out.String(), "Status     newer release, but the checkout has 1 commit on no branch of the remote; it stays unless you pass --allow-downgrade")
	assert.Equal(t, 0, r.run())
	assert.Contains(t, r.out.String(), "has 1 commit that is on no branch of the remote; 0.5.0, the newest stable release, does not contain it")
	assert.Contains(t, r.out.String(), brand.AppID+" update --channel stable --allow-downgrade")
	assert.Empty(t, r.installer)

	assert.Equal(t, 0, r.run("--allow-downgrade"))
	assert.Equal(t, []string{"--channel", "stable", "--ref", "0.5.0", "--allow-downgrade"}, r.installer[0][len(r.installer[0])-5:])
}

func TestUpdateLocalBranchIsBuiltAsItIs(t *testing.T) {
	clone := fakeCheckout(t)
	gitT(t, clone, "checkout", "-q", "-b", "mine")
	r := newUpdateRun(t, clone)
	assert.Equal(t, 0, r.run("--check", "--channel", "git"))
	assert.Contains(t, r.out.String(), "Status     local branch: "+brand.AppID+" update rebuilds it as it is")
	assert.Equal(t, 0, r.run("--channel", "git"))
	assert.Contains(t, r.out.String(), "Branch mine is not on the remote; rebuilding the checkout as it is.")
	assert.Equal(t, []string{"--channel", "git"}, r.installer[0][len(r.installer[0])-2:])
}

func TestUpdateReportsReadQuickly(t *testing.T) {
	// --check and `update channel` only report: a short remote timeout.
	repo := reportRepo("/src")
	assert.Equal(t, "/src", repo.Dir)
	assert.Equal(t, reportTimeout, repo.ReadTimeout)
	assert.LessOrEqual(t, reportTimeout, 10*time.Second)
}
