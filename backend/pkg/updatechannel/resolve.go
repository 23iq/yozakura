package updatechannel

import (
	"errors"
	"fmt"
	"sort"
	"strings"
)

// Repo is what Resolve needs from a checkout and its remote. GitRepo is the
// real one; tests use a fake.
type Repo interface {
	// Head is the commit checked out.
	Head() (string, error)
	// Branch is the checked-out branch, "" on a detached HEAD.
	Branch() string
	// RemoteTags maps the remote's tag names to the commits they point at.
	RemoteTags() (map[string]string, error)
	// RemoteBranch is the commit at the tip of a remote branch; an error
	// wrapping ErrNoBranch when the remote has no such branch.
	RemoteBranch(name string) (string, error)
	// LocalCommits counts the commits of HEAD that are on no remote branch
	// and behind none of the given commits (the remote's tags): work that
	// exists only in this checkout.
	LocalCommits(exclude []string) int
	// IsAncestor reports whether commit a is an ancestor of (or equal to)
	// commit b; false when either is unknown locally.
	IsAncestor(a, b string) bool
}

// State is the outcome of a resolution.
type State string

const (
	// UpToDate: the checkout already contains the channel's target.
	UpToDate State = "up-to-date"
	// Available: moving to the target only adds commits (or the target is
	// a newer release than the installed version).
	Available State = "update-available"
	// Downgrade: the target is older than the checkout; moving needs an
	// explicit request.
	Downgrade State = "downgrade"
	// LocalCommits: the target is newer, but HEAD has commits made in this
	// checkout that the target lacks; moving would stop building them, so
	// it needs the same explicit request as a downgrade.
	LocalCommits State = "local-commits"
	// LocalBranch: the git channel on a branch the remote does not have;
	// the checkout is built as it is.
	LocalBranch State = "local-branch"
	// NoTarget: the channel has no release newer than LastWithoutChannels.
	NoTarget State = "no-target"
	// Unknown: the remote could not be read (offline).
	Unknown State = "unknown"
)

// MainBranch is the branch the git channel follows from a detached HEAD.
const MainBranch = "main"

// ErrNoBranch: the remote has no branch of that name.
var ErrNoBranch = errors.New("no such branch on the remote")

// Status describes a checkout against a channel.
type Status struct {
	Channel   string
	Installed string // the checkout's version file
	Head      string // full commit
	Branch    string // "" when detached
	// Target is a tag (stable/beta) or a branch name (git).
	Target       string
	TargetCommit string
	State        State
	// Local is the number of commits only this checkout has (LocalCommits).
	Local int
	// Note explains the state in a few words (the reason of Unknown, the
	// branch switch of git from a detached HEAD).
	Note string
}

// Short abbreviates a commit for display.
func Short(commit string) string {
	if len(commit) > 7 {
		return commit[:7]
	}
	return commit
}

// Resolve works out where channel would move the checkout. installed is the
// checkout's version file, used when the target and the checkout have
// diverged (a newer release on another line is still an update).
func Resolve(r Repo, channel, installed string) Status {
	st := Status{Channel: channel, Installed: installed, Branch: r.Branch()}
	head, err := r.Head()
	if err != nil {
		st.State, st.Note = Unknown, fmt.Sprintf("cannot read the checkout: %v", err)
		return st
	}
	st.Head = head
	if channel == Git {
		return resolveGit(r, st)
	}
	tags, err := r.RemoteTags()
	if err != nil {
		st.State, st.Note = Unknown, offlineNote(err)
		return st
	}
	names := make([]string, 0, len(tags))
	commits := make([]string, 0, len(tags))
	for name, commit := range tags {
		names = append(names, name)
		commits = append(commits, commit)
	}
	sort.Strings(names)
	sort.Strings(commits)
	st.Target = Select(names, channel)
	if st.Target == "" {
		st.State = NoTarget
		return st
	}
	st.TargetCommit = tags[st.Target]
	switch {
	case st.TargetCommit == head || r.IsAncestor(st.TargetCommit, head):
		st.State = UpToDate
		return st
	case r.IsAncestor(head, st.TargetCommit):
		st.State = Available
		return st
	}
	// Diverged, or the target is not fetched yet (IsAncestor of itself
	// fails): a newer release is an update, an older one would take commits
	// away. An unfetched commit cannot show the checkout is ahead of it.
	d, ok := Compare(st.Target, installed)
	if r.IsAncestor(st.TargetCommit, st.TargetCommit) {
		if ok && d > 0 {
			st.State = Available
		} else {
			st.State = Downgrade
		}
	} else if !ok || d >= 0 {
		st.State = Available
	} else {
		st.State, st.Note = Unknown, "release "+st.Target+" is not fetched yet; an update fetches it first"
		return st
	}
	if st.State == Available {
		// HEAD is not behind the target: commits made here would be left out.
		if n := r.LocalCommits(commits); n > 0 {
			st.State, st.Local = LocalCommits, n
		}
	}
	return st
}

func resolveGit(r Repo, st Status) Status {
	branch := st.Branch
	if branch == "" {
		branch = MainBranch
	}
	st.Target = branch
	tip, err := r.RemoteBranch(branch)
	if err != nil && st.Branch != "" && errors.Is(err, ErrNoBranch) {
		// A branch made in this checkout: built as it is, as before channels.
		st.TargetCommit = st.Head
		st.State, st.Note = LocalBranch, "no branch "+branch+" on the remote; the checkout is built as it is"
		return st
	}
	if err != nil {
		st.State, st.Note = Unknown, offlineNote(err)
		return st
	}
	st.TargetCommit = tip
	switch {
	case st.Branch == "":
		st.State, st.Note = Available, "the checkout is on a release tag; the update returns it to "+MainBranch
	case tip == st.Head || r.IsAncestor(tip, st.Head):
		st.State = UpToDate
	default:
		st.State = Available
	}
	return st
}

func offlineNote(err error) string {
	msg := strings.TrimSpace(err.Error())
	if i := strings.IndexByte(msg, '\n'); i >= 0 {
		msg = msg[:i]
	}
	return "cannot reach the remote (" + msg + ")"
}
