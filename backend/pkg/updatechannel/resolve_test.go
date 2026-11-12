package updatechannel

import (
	"errors"
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
		return "", errors.New("no branch")
	}
	return tip, nil
}
func (f fakeRepo) IsAncestor(a, b string) bool {
	for _, c := range history[b] {
		if c == a {
			return true
		}
	}
	return false
}

func TestResolveTagChannels(t *testing.T) {
	tags := map[string]string{"0.3.0": "a", "0.3.1": "b", "0.3.2-beta.1": "c"}
	cases := []struct {
		name, channel, head, branch, installed string
		tags                                   map[string]string
		state                                  State
		target                                 string
	}{
		{"main ahead of the newest stable tag stays", Stable, "d", "main", "0.3.1", tags, UpToDate, "0.3.1"},
		{"on the newest tag", Stable, "b", "", "0.3.1", tags, UpToDate, "0.3.1"},
		{"older tag moves forward", Stable, "a", "", "0.3.0", tags, Available, "0.3.1"},
		{"beta moves past stable", Beta, "b", "", "0.3.1", tags, Available, "0.3.2-beta.1"},
		{"beta at the newest beta", Beta, "c", "", "0.3.2-beta.1", tags, UpToDate, "0.3.2-beta.1"},
		{"beta follows a newer stable", Beta, "c", "", "0.3.2-beta.1",
			map[string]string{"0.3.2-beta.1": "c", "0.3.2": "d"}, Available, "0.3.2"},
		{"diverged checkout, newer release", Stable, "x", "", "0.3.1",
			map[string]string{"0.3.2": "c"}, Available, "0.3.2"},
		{"diverged checkout, older release is a downgrade", Stable, "x", "", "0.3.2",
			map[string]string{"0.3.1": "c"}, Downgrade, "0.3.1"},
		{"tag not fetched yet, newer version", Stable, "d", "main", "0.3.1",
			map[string]string{"0.3.2": "zzz"}, Available, "0.3.2"},
		{"tag not fetched, no installed version", Stable, "d", "main", "",
			map[string]string{"0.3.2": "zzz"}, Available, "0.3.2"},
		{"beta on stable channel ignored", Stable, "b", "", "0.3.1",
			map[string]string{"0.3.2-beta.1": "c"}, NoTarget, ""},
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

func TestResolveGitChannel(t *testing.T) {
	tips := map[string]string{"main": "d", "dev": "x"}
	st := Resolve(fakeRepo{head: "d", branch: "main", tips: tips}, Git, "0.3.1")
	assert.Equal(t, UpToDate, st.State)
	assert.Equal(t, "main", st.Target)

	st = Resolve(fakeRepo{head: "b", branch: "main", tips: tips}, Git, "0.3.1")
	assert.Equal(t, Available, st.State)
	assert.Equal(t, "d", st.TargetCommit)

	// Local commits ahead of the remote tip: nothing to pull.
	st = Resolve(fakeRepo{head: "d", branch: "main", tips: map[string]string{"main": "c"}}, Git, "")
	assert.Equal(t, UpToDate, st.State)

	// Another branch is followed as it is (install.sh --branch).
	st = Resolve(fakeRepo{head: "b", branch: "dev", tips: tips}, Git, "")
	assert.Equal(t, "dev", st.Target)
	assert.Equal(t, Available, st.State)

	// A detached release checkout goes back to main even at the same commit.
	st = Resolve(fakeRepo{head: "d", tips: tips}, Git, "0.3.1")
	assert.Equal(t, "main", st.Target)
	assert.Equal(t, Available, st.State)
	assert.Contains(t, st.Note, "main")
}

func TestResolveOffline(t *testing.T) {
	st := Resolve(fakeRepo{head: "d", branch: "main", offline: true}, Stable, "0.3.1")
	assert.Equal(t, Unknown, st.State)
	assert.Equal(t, "cannot reach the remote (could not resolve host)", st.Note)
	st = Resolve(fakeRepo{head: "d", branch: "main", offline: true}, Git, "0.3.1")
	assert.Equal(t, Unknown, st.State)
	assert.Equal(t, "d", st.Head)
}

func TestShort(t *testing.T) {
	assert.Equal(t, "0123456", Short("0123456789abcdef"))
	assert.Equal(t, "abc", Short("abc"))
}
