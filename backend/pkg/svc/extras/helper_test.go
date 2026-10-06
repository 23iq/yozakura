package extras

import (
	"errors"
	"io/fs"
	"syscall"
	"testing"
)

func TestHelperPath(t *testing.T) {
	root := &syscall.Stat_t{Uid: 0}
	user := &syscall.Stat_t{Uid: 1000}
	cases := []struct {
		name string
		info fs.FileInfo
		err  error
		want string
	}{
		{"root-owned 0755", fakeInfo{0o755, root}, nil, "/opt/helper"},
		{"missing", nil, errors.New("enoent"), "/run/self"},
		{"user-owned", fakeInfo{0o755, user}, nil, "/run/self"},
		{"group-writable", fakeInfo{0o775, root}, nil, "/run/self"},
		{"world-writable", fakeInfo{0o757, root}, nil, "/run/self"},
		{"symlink", fakeInfo{0o755 | fs.ModeSymlink, root}, nil, "/run/self"},
		{"directory", fakeInfo{0o755 | fs.ModeDir, root}, nil, "/run/self"},
		{"no stat info", fakeInfo{0o755, nil}, nil, "/run/self"},
	}
	for _, c := range cases {
		got := helperPath("/opt/helper", "/run/self", func(string) (fs.FileInfo, error) { return c.info, c.err })
		if got != c.want {
			t.Errorf("%s: %q, want %q", c.name, got, c.want)
		}
	}
}
