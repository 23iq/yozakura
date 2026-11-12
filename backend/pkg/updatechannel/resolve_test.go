package updatechannel

import (
	"errors"
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
)

// fakeRepo: commits are letters on one line a < b < c < d, plus x which
// branches off b.
type fakeRepo struct {
	head, branch string
	tags         map[string]string
	tips         map[string]string
	offline      bool
	local        int // LocalCommits
}

var history = map[string][]string{
	"a": {"a"}, "b": {"a", "b"}, "c": {"a", "b", "c"}, "d": {"a", "b", "c", "d"},
	"x": {"a", "b", "x"},
}

func (f fakeRepo) Head() (string, error) { return f.head, nil }
func (f fakeRepo) Branch() string        { return f.branch }
func (f fakeRepo) RemoteTags() (map[string]string, error) {
	if f.offline {
		return nil, errors.New("could not resolve host\nmore")
	}
	return f.tags, nil
}
func (f fakeRepo) RemoteBranch(name string) (string, error) {
	if f.offline {
		return "", errors.New("could not resolve host")
	}
	tip, ok := f.tips[name]
	if !ok {
		return "", fmt.Errorf("no branch %s: %w", name, ErrNoBranch)
	}
	return tip, nil
}
func (f fakeRepo) LocalCommits([]string) int { return f.local }
func (f fakeRepo) IsAncestor(a, b string) bool {
	for _, c := range history[b] {
		if c == a {
			return true
		}
	}
	return false
}

func TestResolveTagChannels(t *testing.T) {
	tags := map[string]string{"0.4.0": "a", "0.4.1": "b", "0.4.2-beta.1": "c"}
	cases := []struct {
		name, channel, head, branch, installed string
		tags                                   map[string]string
		state                                  State
		target                                 string
	}{
		{"main ahead of the newest stable tag stays", Stable, "d", "main", "0.4.1", tags, UpToDate, "0.4.1"},
		{"on the newest tag", Stable, "b", "", "0.4.1", tags, UpToDate, "0.4.1"},
		{"older tag moves forward", Stable, "a", "", "0.4.0", tags, Available, "0.4.1"},
		{"beta moves past stable", Beta, "b", "", "0.4.1", tags, Available, "0.4.2-beta.1"},
		{"beta at the newest beta", Beta, "c", "", "0.4.2-beta.1", tags, UpToDate, "0.4.2-beta.1"},
		{"beta follows a newer stable", Beta, "c", "", "0.4.2-beta.1",
			map[string]string{"0.4.2-beta.1": "c", "0.4.2": "d"}, Available, "0.4.2"},
		{"diverged checkout, newer release", Stable, "x", "", "0.4.1",
			map[string]string{"0.4.2": "c"}, Available, "0.4.2"},
		{"diverged checkout, older release is a downgrade", Stable, "x", "", "0.4.2",
			map[string]string{"0.4.1": "c"}, Downgrade, "0.4.1"},
		{"tag not fetched yet, newer version", Stable, "d", "main", "0.4.1",
			map[string]string{"0.4.2": "zzz"}, Available, "0.4.2"},
		{"tag not fetched, no installed version", Stable, "d", "main", "",
			map[string]string{"0.4.2": "zzz"}, Available, "0.4.2"},
		{"beta on stable channel ignored", Stable, "b", "", "0.4.1",
			map[string]string{"0.4.2-beta.1": "c"}, NoTarget, ""},
	}
	for _, c := range cases {
		st := Resolve(fakeRepo{head: c.head, branch: c.branch, tags: c.tags}, c.channel, c.installed)
		assert.Equal(t, c.state, st.State, c.name)
		assert.Equal(t, c.target, st.Target, c.name)
		if c.target != "" {
			assert.Equal(t, c.tags[c.target], st.TargetCommit, c.name)
		}
	}
}

func TestResolvePreChannelReleases(t *testing.T) {
	// Every tag that predates update channels: no target, nothing moves,
	// --allow-downgrade included (it only ever moves to a target).
	tags := map[string]string{"0.1.1": "a", "v0.1.2": "a", "0.2.0": "b", "0.3.0": "b", "0.3.1": "c"}
	for _, ch := range []string{Stable, Beta} {
		st := Resolve(fakeRepo{head: "d", branch: "main", tags: tags}, ch, "0.3.1")
		assert.Equal(t, NoTarget, st.State, ch)
		assert.Equal(t, "", st.Target, ch)
	}
	// A first release with channels is the target, the older ones never.
	tags["0.3.2-beta.1"] = "d"
	st := Resolve(fakeRepo{head: "a", tags: tags}, Beta, "0.1.1")
	assert.Equal(t, "0.3.2-beta.1", st.Target)
	assert.Equal(t, NoTarget, Resolve(fakeRepo{head: "a", tags: tags}, Stable, "0.1.1").State)
}

func TestResolveLocalCommits(t *testing.T) {
	// Main with commits made here (x, off b) and a newer release on c:
	// moving to it would stop building them.
	tags := map[string]string{"0.4.2": "c"}
	st := Resolve(fakeRepo{head: "x", branch: "main", tags: tags, local: 2}, Stable, "0.4.1")
	assert.Equal(t, LocalCommits, st.State)
	assert.Equal(t, 2, st.Local)
	assert.Equal(t, "0.4.2", st.Target)
	// Without local commits (x is on the remote) the release is an update.
	st = Resolve(fakeRepo{head: "x", branch: "main", tags: tags}, Stable, "0.4.1")
	assert.Equal(t, Available, st.State)
	// A target ahead of HEAD keeps every commit: no question.
	st = Resolve(fakeRepo{head: "b", branch: "main", tags: tags, local: 1}, Stable, "0.4.1")
	assert.Equal(t, Available, st.State)
}

func TestResolveUnfetchedTarget(t *testing.T) {
	// The target's commit is not here yet: never "ahead of this release".
	tags := map[string]string{"0.4.2": "zzz"}
	st := Resolve(fakeRepo{head: "d", branch: "main", tags: tags}, Stable, "0.4.2")
	assert.Equal(t, Available, st.State, "same version, commit not fetched")
	st = Resolve(fakeRepo{head: "d", branch: "main", tags: tags}, Stable, "0.5.0")
	assert.Equal(t, Unknown, st.State, "older version, commit not fetched")
	assert.Contains(t, st.Note, "not fetched")
	// A fetched target on another line, same version: a downgrade, as before.
	st = Resolve(fakeRepo{head: "x", branch: "main", tags: map[string]string{"0.4.2": "c"}}, Stable, "0.4.2")
	assert.Equal(t, Downgrade, st.State)
}

func TestResolveGitChannel(t *testing.T) {
	tips := map[string]string{"main": "d", "dev": "x"}
	st := Resolve(fakeRepo{head: "d", branch: "main", tips: tips}, Git, "0.4.1")
	assert.Equal(t, UpToDate, st.State)
	assert.Equal(t, "main", st.Target)

	st = Resolve(fakeRepo{head: "b", branch: "main", tips: tips}, Git, "0.4.1")
	assert.Equal(t, Available, st.State)
	assert.Equal(t, "d", st.TargetCommit)

	// Local commits ahead of the remote tip: nothing to pull.
	st = Resolve(fakeRepo{head: "d", branch: "main", tips: map[string]string{"main": "c"}}, Git, "")
	assert.Equal(t, UpToDate, st.State)

	// Another branch is followed as it is (install.sh --branch).
	st = Resolve(fakeRepo{head: "b", branch: "dev", tips: tips}, Git, "")
	assert.Equal(t, "dev", st.Target)
	assert.Equal(t, Available, st.State)

	// A branch the remote does not have is built as it is.
	st = Resolve(fakeRepo{head: "x", branch: "mine", tips: tips}, Git, "")
	assert.Equal(t, LocalBranch, st.State)
	assert.Equal(t, "mine", st.Target)
	assert.Equal(t, "x", st.TargetCommit)
	assert.Contains(t, st.Note, "built as it is")
	// Detached with no main on the remote: unknown, not a local branch.
	st = Resolve(fakeRepo{head: "x", tips: map[string]string{}}, Git, "")
	assert.Equal(t, Unknown, st.State)

	// A detached release checkout goes back to main even at the same commit.
	st = Resolve(fakeRepo{head: "d", tips: tips}, Git, "0.4.1")
	assert.Equal(t, "main", st.Target)
	assert.Equal(t, Available, st.State)
	assert.Contains(t, st.Note, "main")
}

func TestResolveOffline(t *testing.T) {
	st := Resolve(fakeRepo{head: "d", branch: "main", offline: true}, Stable, "0.4.1")
	assert.Equal(t, Unknown, st.State)
	assert.Equal(t, "cannot reach the remote (could not resolve host)", st.Note)
	st = Resolve(fakeRepo{head: "d", branch: "main", offline: true}, Git, "0.4.1")
	assert.Equal(t, Unknown, st.State)
	assert.Equal(t, "d", st.Head)
}

func TestShort(t *testing.T) {
	assert.Equal(t, "0123456", Short("0123456789abcdef"))
	assert.Equal(t, "abc", Short("abc"))
}
