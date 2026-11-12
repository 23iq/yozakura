package updatechannel

import (
	"fmt"
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
	// RemoteBranch is the commit at the tip of a remote branch.
	RemoteBranch(name string) (string, error)
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
	// NoTarget: the channel has no release yet.
	NoTarget State = "no-target"
	// Unknown: the remote could not be read (offline).
	Unknown State = "unknown"
)

// MainBranch is the branch the git channel follows from a detached HEAD.
const MainBranch = "main"

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
	for name := range tags {
		names = append(names, name)
	}
	st.Target = Select(names, channel)
	if st.Target == "" {
		st.State = NoTarget
		return st
	}
	st.TargetCommit = tags[st.Target]
	switch {
	case st.TargetCommit == head || r.IsAncestor(st.TargetCommit, head):
		st.State = UpToDate
	case r.IsAncestor(head, st.TargetCommit):
		st.State = Available
	default:
		// Diverged (or the target is not fetched yet): a newer release is an
		// update, anything else would take commits away.
		// With no readable installed version, a tag whose commit is not
		// fetched yet (IsAncestor of itself fails) counts as newer.
		d, ok := Compare(st.Target, installed)
		known := r.IsAncestor(st.TargetCommit, st.TargetCommit)
		if (ok && d > 0) || (!ok && !known) {
			st.State = Available
		} else {
			st.State = Downgrade
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
