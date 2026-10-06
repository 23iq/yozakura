package extras

import "testing"

type fakeProbe struct {
	bins  map[string]bool
	pkgs  map[string]bool
	flat  map[string]bool
	globs map[string]bool
	fonts []string
}

func (f fakeProbe) LookPath(b string) bool         { return f.bins[b] }
func (f fakeProbe) InstalledPkgs() map[string]bool { return f.pkgs }
func (f fakeProbe) Flatpaks() map[string]bool      { return f.flat }
func (f fakeProbe) Glob(p string) bool             { return f.globs[p] }
func (f fakeProbe) FontFamilies() []string         { return f.fonts }

func TestDetect(t *testing.T) {
	c := loadReal(t)
	arch := Platform{Distro: "arch", HasFlatpak: true}
	fedora := Platform{Distro: "fedora"}

	st := Detect(c, arch, fakeProbe{flat: map[string]bool{"org.mozilla.firefox": true}, bins: map[string]bool{"claude": true}})
	if s := st["firefox"]; s.State != StateInstalled || s.Source != "flatpak" {
		t.Errorf("firefox = %+v", s)
	}
	if s := st["claude-code"]; s.State != StateInstalled || s.Source != "bin" {
		t.Errorf("claude-code = %+v", s)
	}
	// multilib missing does not change detection: steam stays missing.
	if s := st["steam"]; s.State != StateMissing {
		t.Errorf("steam = %+v", s)
	}
	if s := Detect(c, fedora, fakeProbe{})["cuda"]; s.State != StateUnavailable {
		t.Errorf("cuda on fedora = %+v", s)
	}
	if s := Detect(c, arch, fakeProbe{pkgs: map[string]bool{"cuda": true}})["cuda"]; s.State != StateInstalled || s.Source != "pkg" {
		t.Errorf("cuda pkg = %+v", s)
	}
}

func TestDetectNoMethod(t *testing.T) {
	c := &Catalog{Entries: []Entry{
		{ID: "x", Install: Install{Arch: &Method{Pkgs: []string{"x"}}}},
		{ID: "p", Detect: DetectSpec{Paths: []string{"~/.p"}}},
	}}
	st := Detect(c, Platform{Distro: "other"}, fakeProbe{globs: map[string]bool{"~/.p": true}})
	if s := st["x"]; s.State != StateUnavailable || s.Reason != "no_method" {
		t.Errorf("x = %+v", s)
	}
	if s := st["p"]; s.State != StateInstalled || s.Source != "path" {
		t.Errorf("p = %+v", s)
	}
}

func TestDetectFonts(t *testing.T) {
	c := &Catalog{Entries: []Entry{
		{ID: "nf", Detect: DetectSpec{Fonts: []string{"Nerd Font"}}, Install: Install{Arch: &Method{Pkgs: []string{"x"}}}},
	}}
	arch := Platform{Distro: "arch"}
	if s := Detect(c, arch, fakeProbe{fonts: []string{"Noto Sans", "Symbols NERD FONT Mono"}})["nf"]; s.State != StateInstalled || s.Source != "font" {
		t.Errorf("nerd font present = %+v", s)
	}
	if s := Detect(c, arch, fakeProbe{fonts: []string{"Noto Sans"}})["nf"]; s.State != StateMissing {
		t.Errorf("nerd font absent = %+v", s)
	}
	if s := Detect(c, Platform{Distro: "fedora"}, fakeProbe{})["nf"]; s.State != StateUnavailable {
		t.Errorf("no fedora method = %+v", s)
	}
}

func TestExecProbeOffline(t *testing.T) {
	t.Setenv("PATH", "")
	var p Probe = ExecProbe{}
	if len(p.InstalledPkgs()) != 0 || len(p.Flatpaks()) != 0 {
		t.Error("expected empty maps without tools")
	}
	if len(p.FontFamilies()) != 0 {
		t.Error("expected no fonts without fc-list")
	}
	if p.Glob("/nonexistent/*") {
		t.Error("glob matched")
	}
}

// Bundles are installed only when every tool is there: git alone is not
// "voice build tools", node without npm is not Node.js for npm installs.
func TestDetectAllBins(t *testing.T) {
	c := loadReal(t)
	arch := Platform{Distro: "arch", GPU: "nvidia"}
	only := func(bins ...string) fakeProbe {
		m := map[string]bool{}
		for _, b := range bins {
			m[b] = true
		}
		return fakeProbe{bins: m}
	}
	if s := Detect(c, arch, only("git", "gcc"))["voice-build-deps"]; s.State != StateMissing {
		t.Errorf("git+gcc only = %+v", s)
	}
	if s := Detect(c, arch, only("cmake", "ninja", "g++"))["voice-build-deps"]; s.State != StateInstalled {
		t.Errorf("cmake+ninja+g++ = %+v", s)
	}
	if s := Detect(c, arch, only("node"))["nodejs"]; s.State != StateMissing {
		t.Errorf("node without npm = %+v", s)
	}
	if s := Detect(c, arch, only("node", "npm"))["nodejs"]; s.State != StateInstalled || s.Source != "bin" {
		t.Errorf("node+npm = %+v", s)
	}
	// a GPU build also needs that GPU's packages (Vulkan headers, shaderc)
	amd := Platform{Distro: "arch", GPU: "amd"}
	tools := only("cmake", "ninja", "g++")
	if s := Detect(c, amd, tools)["voice-build-deps"]; s.State != StateMissing {
		t.Errorf("amd without vulkan pkgs = %+v", s)
	}
	tools.pkgs = map[string]bool{"cmake": true, "ninja": true, "gcc": true, "git": true, "vulkan-headers": true, "shaderc": true, "vulkan-icd-loader": true}
	if s := Detect(c, amd, tools)["voice-build-deps"]; s.State != StateInstalled {
		t.Errorf("amd with vulkan pkgs = %+v", s)
	}
}
