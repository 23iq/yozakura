package extras

import (
	"errors"
	"reflect"
	"testing"
)

const self = "/usr/bin/yozakura"

var archNvidia = Platform{Distro: "arch", GPU: "nvidia", HasFlatpak: true, HasPkexec: true, Multilib: true}

func plan(t *testing.T, c *Catalog, p Platform, st map[string]Status, opts PlanOptions, ids ...string) []Job {
	t.Helper()
	if opts.Home == "" {
		opts.Home = "/home/u"
	}
	jobs, err := Plan(c, p, st, ids, self, opts)
	if err != nil {
		t.Fatalf("Plan(%v): %v", ids, err)
	}
	return jobs
}

func kinds(jobs []Job) []JobKind {
	var out []JobKind
	for _, j := range jobs {
		out = append(out, j.Kind)
	}
	return out
}

func TestPlanRequiresOrdered(t *testing.T) {
	jobs := plan(t, loadReal(t), archNvidia, nil, PlanOptions{}, "codex")
	if !reflect.DeepEqual(kinds(jobs), []JobKind{KindSystem, KindNpm}) {
		t.Fatalf("kinds = %v", kinds(jobs))
	}
	if want := []string{"pkexec", self, "sys", "install", "nodejs"}; !reflect.DeepEqual(jobs[0].Argv, want) {
		t.Errorf("system argv = %v", jobs[0].Argv)
	}
	if want := []string{"npm", "install", "-g", "--prefix", "/home/u/.local", "@openai/codex"}; !reflect.DeepEqual(jobs[1].Argv, want) {
		t.Errorf("npm argv = %v", jobs[1].Argv)
	}
	if !reflect.DeepEqual(jobs[1].Deps, []string{jobs[0].ID}) || !jobs[0].NeedsRoot || jobs[1].NeedsRoot {
		t.Errorf("deps/root wrong: %+v", jobs)
	}
}

func TestPlanInstalledRequiresSkipped(t *testing.T) {
	st := map[string]Status{"nodejs": {ID: "nodejs", State: StateInstalled}}
	jobs := plan(t, loadReal(t), archNvidia, st, PlanOptions{}, "codex", "gemini-cli")
	if len(jobs) != 1 || jobs[0].Kind != KindNpm || len(jobs[0].Deps) != 0 {
		t.Fatalf("jobs = %+v", jobs)
	}
	if !reflect.DeepEqual(jobs[0].Entries, []string{"codex", "gemini-cli"}) {
		t.Errorf("entries = %v", jobs[0].Entries)
	}
	st["codex"] = Status{State: StateInstalled}
	st["gemini-cli"] = Status{State: StateInstalled}
	if jobs := plan(t, loadReal(t), archNvidia, st, PlanOptions{}, "codex"); len(jobs) != 0 {
		t.Errorf("installed entry planned: %+v", jobs)
	}
}

func TestPlanSystemBatchMerged(t *testing.T) {
	jobs := plan(t, loadReal(t), archNvidia, nil, PlanOptions{}, "firefox", "telegram", "ollama")
	if len(jobs) != 1 {
		t.Fatalf("jobs = %+v", jobs)
	}
	want := []string{"pkexec", self, "sys", "install", "firefox", "telegram", "ollama"}
	if !reflect.DeepEqual(jobs[0].Argv, want) {
		t.Errorf("argv = %v", jobs[0].Argv)
	}
	if !reflect.DeepEqual(jobs[0].Names, []string{"Firefox", "Telegram", "Ollama"}) {
		t.Errorf("names = %v", jobs[0].Names)
	}
}

func TestPlanAURFallbacks(t *testing.T) {
	c := loadReal(t)
	jobs := plan(t, c, archNvidia, nil, PlanOptions{}, "zen-browser")
	if len(jobs) != 1 || jobs[0].Kind != KindFlatpak {
		t.Fatalf("no helper: %+v", jobs)
	}
	if want := []string{"flatpak", "install", "--user", "-y", "--noninteractive", "flathub", "app.zen_browser.zen"}; !reflect.DeepEqual(jobs[0].Argv, want) {
		t.Errorf("flatpak argv = %v", jobs[0].Argv)
	}
	if len(jobs[0].Pre) != 1 || jobs[0].Pre[0][1] != "remote-add" {
		t.Errorf("flatpak pre = %v", jobs[0].Pre)
	}

	p := archNvidia
	p.HasYay = true
	jobs = plan(t, c, p, nil, PlanOptions{}, "zen-browser")
	if want := []string{"yay", "-S", "--needed", "--noconfirm", "--sudo", "pkexec", "zen-browser-bin"}; len(jobs) != 1 || !reflect.DeepEqual(jobs[0].Argv, want) {
		t.Errorf("yay: %+v", jobs)
	}

	p = archNvidia
	p.HasFlatpak = false
	_, err := Plan(c, p, nil, []string{"zen-browser", "spicetify"}, self, PlanOptions{})
	var ue *UnavailableError
	if !errors.As(err, &ue) || ue.Reasons["zen-browser"] != "needs_aur_helper" || ue.Reasons["spicetify"] != "needs_aur_helper" {
		t.Errorf("err = %v", err)
	}
}

func TestPlanFlatpakOnlyHosts(t *testing.T) {
	c := loadReal(t)
	other := Platform{Distro: "other", HasFlatpak: true}
	jobs := plan(t, c, other, nil, PlanOptions{}, "firefox")
	if len(jobs) != 1 || jobs[0].Kind != KindFlatpak {
		t.Errorf("other: %+v", jobs)
	}
	other.HasFlatpak = false
	_, err := Plan(c, other, nil, []string{"firefox", "ghostty", "nope"}, self, PlanOptions{})
	var ue *UnavailableError
	if !errors.As(err, &ue) || ue.Reasons["nope"] != "unknown" {
		t.Fatalf("unknown: %v", err)
	}
	_, err = Plan(c, other, nil, []string{"firefox", "ghostty"}, self, PlanOptions{})
	if !errors.As(err, &ue) || ue.Reasons["firefox"] != "needs_flatpak" || ue.Reasons["ghostty"] != "only_distro" {
		t.Errorf("err = %v", err)
	}
	fedora := Platform{Distro: "fedora", HasFlatpak: true}
	if jobs := plan(t, c, fedora, nil, PlanOptions{}, "firefox"); jobs[0].Kind != KindSystem {
		t.Errorf("fedora: %+v", jobs)
	}
}

func TestPlanMultilibConfirm(t *testing.T) {
	c := loadReal(t)
	p := archNvidia
	p.Multilib = false
	_, err := Plan(c, p, nil, []string{"steam", "firefox"}, self, PlanOptions{})
	var nc *ErrNeedsConfirm
	if !errors.As(err, &nc) || nc.Kind != "multilib" || !reflect.DeepEqual(nc.Entries, []string{"steam"}) {
		t.Fatalf("err = %v", err)
	}
	jobs := plan(t, c, p, nil, PlanOptions{ConfirmMultilib: true}, "steam", "firefox")
	if !reflect.DeepEqual(kinds(jobs), []JobKind{KindMultilib, KindSystem}) {
		t.Fatalf("kinds = %v", kinds(jobs))
	}
	if want := []string{"pkexec", self, "sys", "enable-multilib"}; !reflect.DeepEqual(jobs[0].Argv, want) {
		t.Errorf("multilib argv = %v", jobs[0].Argv)
	}
	if !reflect.DeepEqual(jobs[1].Deps, []string{jobs[0].ID}) {
		t.Errorf("system deps = %v", jobs[1].Deps)
	}
}

func TestPlanCrossKindOrderAndScripts(t *testing.T) {
	c := &Catalog{
		Categories: []Category{{ID: "x"}},
		Entries: []Entry{
			{ID: "app", Category: "x", Name: "App", Install: Install{Flatpak: "org.app.App"}},
			{ID: "plug", Category: "x", Name: "Plug", Install: Install{Arch: &Method{AUR: []string{"plug-bin"}}}, Requires: []string{"app"}},
			{ID: "cli", Category: "x", Name: "Cli", Install: Install{Script: &ScriptSpec{URL: "https://ohmyposh.dev/install.sh", Args: []string{"-d", "~/.local/bin"}}}},
			{ID: "sh", Category: "x", Name: "Sh", Install: Install{Shell: "voice_setup.sh"}},
		},
	}
	if err := c.Validate(); err != nil {
		t.Fatal(err)
	}
	p := Platform{Distro: "arch", HasParu: true, HasFlatpak: true}
	jobs := plan(t, c, p, nil, PlanOptions{ScriptsDir: "/repo/scripts"}, "sh", "plug", "cli")
	if !reflect.DeepEqual(kinds(jobs), []JobKind{KindFlatpak, KindAUR, KindScript, KindShell}) {
		t.Fatalf("kinds = %v", kinds(jobs))
	}
	if jobs[1].Argv[0] != "paru" || !reflect.DeepEqual(jobs[1].Deps, []string{jobs[0].ID}) {
		t.Errorf("aur job = %+v", jobs[1])
	}
	if want := []string{"bash", ScriptFile, "-d", "/home/u/.local/bin"}; !reflect.DeepEqual(jobs[2].Argv, want) || jobs[2].ScriptURL == "" {
		t.Errorf("script job = %+v", jobs[2])
	}
	if want := []string{"bash", "/repo/scripts/voice_setup.sh"}; !reflect.DeepEqual(jobs[3].Argv, want) {
		t.Errorf("shell job = %+v", jobs[3])
	}
}
