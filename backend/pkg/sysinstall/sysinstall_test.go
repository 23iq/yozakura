package sysinstall

import (
	"errors"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"yozakura/backend/pkg/svc/extras"
)

func realCatalog(t *testing.T) *extras.Catalog {
	t.Helper()
	c, err := extras.LoadCatalog(filepath.Join("..", "..", "..", "assets", "catalog", "extras.json"))
	if err != nil {
		t.Fatalf("LoadCatalog: %v", err)
	}
	return c
}

func testCatalog() *extras.Catalog {
	return &extras.Catalog{
		Categories: []extras.Category{{ID: "x"}},
		Entries: []extras.Entry{
			{ID: "ollama", Category: "x", Install: extras.Install{
				Arch: &extras.Method{Pkgs: []string{"ollama"},
					GPU: extras.GPUVariants{"nvidia": {"ollama-cuda"}, "amd": {"ollama-rocm"}}},
				Fedora:  &extras.Method{Pkgs: []string{"ollama"}},
				Service: "ollama",
			}},
			{ID: "aur-only", Category: "x", Install: extras.Install{Arch: &extras.Method{AUR: []string{"thing-bin"}}}},
			{ID: "npm-only", Category: "x", Install: extras.Install{Npm: "foo"}},
			{ID: "arch-only", Category: "x", Only: []string{"arch"}, Install: extras.Install{Arch: &extras.Method{Pkgs: []string{"cuda"}}}},
			{ID: "steam", Category: "x", Multilib: true, Install: extras.Install{Arch: &extras.Method{Pkgs: []string{"steam"}}}},
			{ID: "dash", Category: "x", Install: extras.Install{Arch: &extras.Method{Pkgs: []string{"-foo"}}}},
			{ID: "badunit", Category: "x", Install: extras.Install{Arch: &extras.Method{Pkgs: []string{"a"}}, Service: "-x"}},
		},
	}
}

func TestResolveOllamaNvidiaArch(t *testing.T) {
	for _, c := range []*extras.Catalog{testCatalog(), realCatalog(t)} {
		pkgs, units, err := ResolveSystemPkgs(c, extras.Platform{Distro: "arch", GPU: "nvidia"}, []string{"ollama"})
		if err != nil {
			t.Fatal(err)
		}
		if !reflect.DeepEqual(pkgs, []string{"ollama-cuda"}) || !reflect.DeepEqual(units, []string{"ollama"}) {
			t.Fatalf("pkgs=%v units=%v", pkgs, units)
		}
	}
}

func TestResolveNoGPUVariantFallsBackToMethod(t *testing.T) {
	pkgs, _, err := ResolveSystemPkgs(testCatalog(), extras.Platform{Distro: "fedora", GPU: "intel"}, []string{"ollama"})
	if err != nil || !reflect.DeepEqual(pkgs, []string{"ollama"}) {
		t.Fatalf("pkgs=%v err=%v", pkgs, err)
	}
}

func TestResolveGPUVariantsArePerDistro(t *testing.T) {
	for _, c := range []*extras.Catalog{testCatalog(), realCatalog(t)} {
		pkgs, _, err := ResolveSystemPkgs(c, extras.Platform{Distro: "fedora", GPU: "nvidia"}, []string{"ollama"})
		if err != nil || !reflect.DeepEqual(pkgs, []string{"ollama"}) {
			t.Fatalf("fedora nvidia: pkgs=%v err=%v", pkgs, err)
		}
	}
}

func TestResolveDedupes(t *testing.T) {
	pkgs, units, err := ResolveSystemPkgs(testCatalog(), extras.Platform{Distro: "arch"}, []string{"ollama", "ollama", "arch-only"})
	if err != nil || !reflect.DeepEqual(pkgs, []string{"ollama", "cuda"}) || len(units) != 1 {
		t.Fatalf("pkgs=%v units=%v err=%v", pkgs, units, err)
	}
}

func TestResolveErrors(t *testing.T) {
	arch := extras.Platform{Distro: "arch", Multilib: true}
	cases := []struct {
		p    extras.Platform
		ids  []string
		want string
	}{
		{arch, []string{"nope"}, "unknown"},
		{arch, []string{"aur-only"}, "not a system package"},
		{arch, []string{"npm-only"}, "not a system package"},
		{extras.Platform{Distro: "fedora"}, []string{"arch-only"}, "not a system package"},
		{extras.Platform{Distro: "nixos"}, []string{"ollama"}, "not a system package"},
		{arch, []string{"-rf"}, "invalid"},
		{arch, []string{"Ollama"}, "invalid"},
		{arch, []string{"dash"}, "bad package"},
		{arch, []string{"badunit"}, "bad unit"},
		{arch, nil, "no ids"},
		{extras.Platform{Distro: "arch"}, []string{"steam"}, "multilib"},
	}
	for _, tc := range cases {
		_, _, err := ResolveSystemPkgs(testCatalog(), tc.p, tc.ids)
		if err == nil || !strings.Contains(err.Error(), tc.want) {
			t.Errorf("%v on %s: err=%v, want %q", tc.ids, tc.p.Distro, err, tc.want)
		}
	}
	_, _, err := ResolveSystemPkgs(testCatalog(), extras.Platform{Distro: "arch"}, []string{"steam"})
	if !errors.Is(err, ErrNeedsMultilib) {
		t.Errorf("steam without multilib: %v", err)
	}
	if _, _, err := ResolveSystemPkgs(testCatalog(), arch, []string{"steam"}); err != nil {
		t.Errorf("steam with multilib: %v", err)
	}
}

func TestRealSteamNeedsMultilib(t *testing.T) {
	e, ok := realCatalog(t).Get("steam")
	if !ok || !e.Multilib {
		t.Fatalf("steam multilib = %v", e.Multilib)
	}
}

const pacmanConf = `[options]
HoldPkg = pacman glibc

[core]
Include = /etc/pacman.d/mirrorlist

#[multilib-testing]
#Include = /etc/pacman.d/mirrorlist

#[multilib]
#Include = /etc/pacman.d/mirrorlist

# A trailing comment
`

func TestEnableMultilib(t *testing.T) {
	out, changed := EnableMultilib([]byte(pacmanConf))
	if !changed {
		t.Fatal("expected change")
	}
	s := string(out)
	if !strings.Contains(s, "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n") {
		t.Fatalf("not enabled:\n%s", s)
	}
	if !strings.Contains(s, "#[multilib-testing]\n#Include") || !strings.Contains(s, "# A trailing comment") {
		t.Fatalf("touched other lines:\n%s", s)
	}
	again, changed := EnableMultilib(out)
	if changed || string(again) != s {
		t.Fatal("already enabled must be unchanged")
	}
}

func TestEnableMultilibMissingBlockAppends(t *testing.T) {
	out, changed := EnableMultilib([]byte("[options]\n[core]\nInclude = /etc/pacman.d/mirrorlist"))
	if !changed || !strings.HasSuffix(string(out), "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n") {
		t.Fatalf("changed=%v out=%q", changed, out)
	}
}

func TestValidShell(t *testing.T) {
	shells := []byte("# /etc/shells\n/bin/sh\n/usr/bin/fish\n  /usr/bin/zsh  \n")
	for shell, want := range map[string]bool{
		"/usr/bin/fish":   true,
		"/usr/bin/zsh":    true,
		"/bin/sh":         true,
		"/usr/bin/bash":   false,
		"fish":            false,
		"# /etc/shells":   false,
		"":                false,
		"/usr/bin/fish\n": false,
	} {
		if got := ValidShell(shells, shell); got != want {
			t.Errorf("ValidShell(%q) = %v", shell, got)
		}
	}
}

func TestStreamSplitsLinesAndCarriageReturns(t *testing.T) {
	var got []string
	streamLines(strings.NewReader("a\nb\rc\r\nd"), func(l string) { got = append(got, l) })
	if !reflect.DeepEqual(got, []string{"a", "b", "c", "d"}) {
		t.Fatalf("got %q", got)
	}
}
