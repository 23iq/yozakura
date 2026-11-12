// Package updatechannel decides what an update moves a source install to.
//
// Three channels exist: "stable" follows the X.Y.Z release tags, "beta"
// follows X.Y.Z-beta.N pre-release tags plus any newer stable release, and
// "git" follows the tip of the branch (main). The version rules here are the
// reference; modules/services/UpdateVersions.js (the shell's update notice)
// and install.sh (pick_tag) implement the same rules and are tested against
// the same cases, tests/fixtures/update-channels.json.
package updatechannel

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

// The channels, in order from the most to the least stable.
const (
	Stable = "stable"
	Beta   = "beta"
	Git    = "git"
)

// Default is the channel of an install that never chose one.
const Default = Stable

// Channels lists every channel name.
var Channels = []string{Stable, Beta, Git}

// Valid reports whether name is a channel.
func Valid(name string) bool {
	for _, c := range Channels {
		if c == name {
			return true
		}
	}
	return false
}

// Version is a release (Beta < 0) or a beta pre-release (Beta >= 0).
type Version struct {
	Major, Minor, Patch int
	Beta                int
}

var versionRe = regexp.MustCompile(`^v?(\d+)\.(\d+)\.(\d+)(?:-beta\.(\d+))?$`)

// Parse reads a tag: X.Y.Z or X.Y.Z-beta.N with an optional leading "v".
// Anything else (rc tags, two-part versions, build metadata) is not a
// version of any channel.
func Parse(tag string) (Version, bool) {
	m := versionRe.FindStringSubmatch(strings.TrimSpace(tag))
	if m == nil {
		return Version{}, false
	}
	n := make([]int, 4)
	for i, s := range m[1:] {
		if s == "" {
			n[i] = -1
			continue
		}
		v, err := strconv.Atoi(s)
		if err != nil {
			return Version{}, false
		}
		n[i] = v
	}
	return Version{Major: n[0], Minor: n[1], Patch: n[2], Beta: n[3]}, true
}

// IsBeta reports whether v is a pre-release.
func (v Version) IsBeta() bool { return v.Beta >= 0 }

func (v Version) String() string {
	s := fmt.Sprintf("%d.%d.%d", v.Major, v.Minor, v.Patch)
	if v.IsBeta() {
		s += fmt.Sprintf("-beta.%d", v.Beta)
	}
	return s
}

func cmpInt(a, b int) int {
	switch {
	case a < b:
		return -1
	case a > b:
		return 1
	}
	return 0
}

// Compare orders by semver precedence: numbers numerically, a release above
// its own betas, beta.N numerically (beta.10 > beta.9).
func (v Version) Compare(o Version) int {
	for _, d := range []int{cmpInt(v.Major, o.Major), cmpInt(v.Minor, o.Minor), cmpInt(v.Patch, o.Patch)} {
		if d != 0 {
			return d
		}
	}
	switch {
	case v.IsBeta() == o.IsBeta():
		return cmpInt(v.Beta, o.Beta)
	case v.IsBeta():
		return -1
	}
	return 1
}

// Compare compares two tags; ok is false when either is not a version.
func Compare(a, b string) (int, bool) {
	x, okA := Parse(a)
	y, okB := Parse(b)
	if !okA || !okB {
		return 0, false
	}
	return x.Compare(y), true
}

// Select returns the tag a channel moves to: the highest stable tag for
// stable, the highest stable or beta tag for beta (so a newer stable
// release always wins over older betas), "" for git, an unknown channel or
// no matching tag. Of two spellings of one version the one without "v" wins.
func Select(tags []string, channel string) string {
	if channel != Stable && channel != Beta {
		return ""
	}
	best, bestTag := Version{}, ""
	for _, t := range tags {
		v, ok := Parse(t)
		if !ok || (v.IsBeta() && channel != Beta) {
			continue
		}
		if bestTag == "" {
			best, bestTag = v, t
			continue
		}
		d := v.Compare(best)
		if d > 0 || (d == 0 && strings.HasPrefix(bestTag, "v") && !strings.HasPrefix(t, "v")) {
			best, bestTag = v, t
		}
	}
	return bestTag
}
