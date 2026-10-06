package extras

import (
	"errors"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

type fakeFS map[string]string

func (f fakeFS) ReadFile(p string) ([]byte, error) {
	if v, ok := f[p]; ok {
		return []byte(v), nil
	}
	return nil, errors.New("not found")
}

func (f fakeFS) Glob(pattern string) ([]string, error) {
	var out []string
	for k := range f {
		if ok, _ := filepath.Match(pattern, k); ok {
			out = append(out, k)
		}
	}
	sort.Strings(out)
	return out, nil
}

func TestDetectDistro(t *testing.T) {
	cases := map[string]string{
		"ID=arch\n":                      "arch",
		"ID=endeavouros\nID_LIKE=arch\n": "arch",
		"NAME=x\nID=\"fedora\"\n":        "fedora",
		"ID=nixos\n":                     "nixos",
		"ID=ubuntu\nID_LIKE=debian\n":    "other",
	}
	for rel, want := range cases {
		p := DetectPlatform(fakeFS{"/etc/os-release": rel}, func(string) bool { return false })
		if p.Distro != want {
			t.Errorf("%q: got %s want %s", strings.TrimSpace(rel), p.Distro, want)
		}
	}
	if p := DetectPlatform(fakeFS{}, func(string) bool { return false }); p.Distro != "other" {
		t.Errorf("no os-release: %s", p.Distro)
	}
}

func TestDetectGPU(t *testing.T) {
	drm := func(v ...string) fakeFS {
		f := fakeFS{}
		for i, s := range v {
			f["/sys/class/drm/card"+string(rune('0'+i))+"/device/vendor"] = s + "\n"
		}
		return f
	}
	no := func(string) bool { return false }
	cases := []struct {
		fs   fakeFS
		want string
	}{
		{drm("0x8086", "0x10de"), "nvidia"},
		{drm("0x8086", "0x1002"), "amd"},
		{drm("0x8086"), "intel"},
		{drm("0x1234"), "none"},
		{drm(), "none"},
	}
	for _, c := range cases {
		if got := DetectPlatform(c.fs, no).GPU; got != c.want {
			t.Errorf("got %s want %s", got, c.want)
		}
	}
}

func TestDetectMultilibAndTools(t *testing.T) {
	look := func(b string) bool { return b == "paru" || b == "flatpak" }
	p := DetectPlatform(fakeFS{"/etc/pacman.conf": "#[multilib]\n#Include = x\n"}, look)
	if p.Multilib {
		t.Error("commented multilib should be false")
	}
	if !p.HasParu || !p.HasFlatpak || p.HasYay || p.HasNpm || p.HasPkexec {
		t.Errorf("tools: %+v", p)
	}
	p = DetectPlatform(fakeFS{"/etc/pacman.conf": "[core]\n[multilib]\nInclude = x\n"}, look)
	if !p.Multilib {
		t.Error("multilib should be true")
	}
}
