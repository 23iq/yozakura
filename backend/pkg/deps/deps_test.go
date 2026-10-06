package deps

import (
	"errors"
	"strings"
	"testing"
)

func TestTableParses(t *testing.T) {
	all := All()
	if len(all) < 40 {
		t.Fatalf("only %d deps", len(all))
	}
	seen := map[string]bool{}
	for _, d := range all {
		if seen[d.ID] {
			t.Errorf("duplicate id %s", d.ID)
		}
		seen[d.ID] = true
		switch d.Need {
		case NeedRequired, Standard, Build, "hyprland", "niri", "mango", "voice", "depth", "sddm":
		default:
			t.Errorf("%s: unknown need %q", d.ID, d.Need)
		}
		if len(d.Arch) == 0 && d.ID != "phosphor-icons" && d.ID != "yozd" {
			t.Errorf("%s: no Arch package", d.ID)
		}
	}
	for _, id := range []string{"hyprland", "yozd", "quickshell", "matugen", "portal-hyprland", "polkit-agent", "pipewire", "networkmanager", "bluez"} {
		if !seen[id] {
			t.Errorf("missing %s", id)
		}
	}
}

func TestParseRejectsShortRows(t *testing.T) {
	if _, err := Parse("a\tb\tc\n"); err == nil {
		t.Fatal("want an error for a 3-column row")
	}
}

func fakeChecker(cmds, files []string, fonts string) *Checker {
	has := func(set []string, v string) bool {
		for _, s := range set {
			if s == v {
				return true
			}
		}
		return false
	}
	return &Checker{
		LookPath: func(n string) (string, error) {
			if has(cmds, n) {
				return "/usr/bin/" + n, nil
			}
			return "", errors.New("not found")
		},
		Glob: func(p string) ([]string, error) {
			if has(files, p) {
				return []string{p}, nil
			}
			return nil, nil
		},
		Fonts:  func() string { return strings.ToLower(fonts) },
		Distro: "arch",
		HasPkg: func(_, p string) bool { return p == "present" },
	}
}

func TestPresentAlternatives(t *testing.T) {
	c := fakeChecker([]string{"kdialog"}, []string{"/usr/share/x"}, "Phosphor-Bold\n")
	cases := []struct {
		dep  Dep
		want bool
	}{
		{Dep{Checks: []string{"zenity", "kdialog"}}, true},
		{Dep{Checks: []string{"zenity"}}, false},
		{Dep{Checks: []string{"/usr/share/x"}}, true},
		{Dep{Checks: []string{"font:Phosphor"}}, true},
		{Dep{Checks: []string{"font:Noto"}}, false},
		{Dep{Arch: []string{"present"}}, true},
		{Dep{Arch: []string{"present", "absent"}}, false},
	}
	for i, tc := range cases {
		if got := c.Present(tc.dep); got != tc.want {
			t.Errorf("case %d: got %v want %v", i, got, tc.want)
		}
	}
}

func TestDistroFromOSRelease(t *testing.T) {
	for text, want := range map[string]string{
		"ID=arch\n":                       "arch",
		"ID=endeavouros\nID_LIKE=arch\n":  "arch",
		"ID=fedora\n":                     "fedora",
		"ID=nobara\nID_LIKE=\"fedora\"\n": "fedora",
		"ID=nixos\n":                      "nixos",
		"ID=ubuntu\nID_LIKE=debian\n":     "other",
	} {
		if got := distroFromOSRelease(text); got != want {
			t.Errorf("%q: got %s want %s", text, got, want)
		}
	}
}

func TestInstallHint(t *testing.T) {
	h := InstallHint("arch", []string{"cava", "aur:ttf-phosphor-icons"})
	if !strings.Contains(h, "pacman -S --needed cava") || !strings.Contains(h, "paru -S ttf-phosphor-icons") {
		t.Fatalf("unexpected hint %q", h)
	}
	if InstallHint("other", []string{"x"}) != "" {
		t.Fatal("no hint expected for unknown distros")
	}
}

func ids(ds []Dep) map[string]bool {
	m := map[string]bool{}
	for _, d := range ds {
		m[d.ID] = true
	}
	return m
}

// required is what the shell cannot start without under a compositor:
// every "required" row plus that compositor's rows ("" = the default).
func required(compositor string) []Dep {
	if compositor == "" {
		compositor = DefaultCompositor
	}
	var out []Dep
	for _, d := range All() {
		if d.Need == NeedRequired || d.Need == compositor {
			out = append(out, d)
		}
	}
	return out
}

func TestRequiredIsCompositorScoped(t *testing.T) {
	niri, hypr, mango := ids(required("niri")), ids(required("hyprland")), ids(required("mango"))
	if !niri["quickshell"] || !hypr["quickshell"] || !mango["quickshell"] {
		t.Fatal("plain required rows belong to every compositor")
	}
	if !niri["niri"] || !niri["xwayland-satellite"] || !niri["portal-gnome"] {
		t.Errorf("niri rows missing: %v", niri)
	}
	if niri["hyprland"] || niri["portal-hyprland"] || niri["mango"] {
		t.Errorf("niri must not need other compositors' rows: %v", niri)
	}
	if !hypr["hyprland"] || hypr["niri"] {
		t.Errorf("hyprland rows wrong: %v", hypr)
	}
	if !mango["mango"] || mango["hyprland"] || mango["niri"] {
		t.Errorf("mango rows wrong: %v", mango)
	}
	if def := ids(required("")); !def["hyprland"] || def["niri"] {
		t.Error("empty compositor means hyprland")
	}
}

func TestCompositorRowsAreNotOptional(t *testing.T) {
	for _, d := range All() {
		if d.CompositorScoped() && d.Optional() {
			t.Errorf("%s: compositor row reported optional", d.ID)
		}
	}
}

func TestParseCompositorNeed(t *testing.T) {
	ds, err := Parse("niri\tniri\tniri\tniri\tniri\tx\n")
	if err != nil || len(ds) != 1 || !ds[0].CompositorScoped() {
		t.Fatalf("got %v %v", ds, err)
	}
}

func TestInstallHintFedoraNiriCopr(t *testing.T) {
	if h := InstallHint("fedora", []string{"niri"}); !strings.Contains(h, "yalter/niri") {
		t.Errorf("no niri COPR hint: %q", h)
	}
	if h := InstallHint("fedora", []string{"cava"}); strings.Contains(h, "yalter/niri") {
		t.Errorf("unexpected niri hint: %q", h)
	}
}
