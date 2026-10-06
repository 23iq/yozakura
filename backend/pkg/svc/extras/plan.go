package extras

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync/atomic"
	"time"
)

// JobKind is the installer a job runs.
type JobKind string

// Job kinds.
const (
	KindSystem   JobKind = "system"
	KindAUR      JobKind = "aur"
	KindFlatpak  JobKind = "flatpak"
	KindNpm      JobKind = "npm"
	KindScript   JobKind = "script"
	KindShell    JobKind = "shell"
	KindMultilib JobKind = "multilib"
	KindUpgrade  JobKind = "upgrade"
)

// ScriptFile is the Argv placeholder the queue replaces with the path of the
// downloaded installer script (Job.ScriptURL).
const ScriptFile = "@script"

const flathubRepo = "https://dl.flathub.org/repo/flathub.flatpakrepo"

// kindOrder breaks ties between independent jobs.
var kindOrder = map[JobKind]int{KindMultilib: 0, KindUpgrade: 0, KindSystem: 1, KindAUR: 2,
	KindFlatpak: 3, KindNpm: 4, KindScript: 5, KindShell: 6}

// Job is one serial unit of work: one command (after optional Pre commands)
// installing one or more catalog entries.
type Job struct {
	ID        string     `json:"id"`
	Kind      JobKind    `json:"kind"`
	Entries   []string   `json:"entries"`
	Names     []string   `json:"names"`
	Argv      []string   `json:"argv"`
	Pre       [][]string `json:"pre,omitempty"`
	ScriptURL string     `json:"scriptUrl,omitempty"`
	NeedsRoot bool       `json:"needsRoot"`
	Deps      []string   `json:"deps,omitempty"` // job ids that must succeed first
}

// PlanOptions tune Plan.
type PlanOptions struct {
	ConfirmMultilib bool   // the user agreed to enable [multilib]
	Home            string // default: os.UserHomeDir
	ScriptsDir      string // repo scripts/ dir for shell entries
}

// ErrNeedsConfirm asks the UI to confirm a system change before planning.
type ErrNeedsConfirm struct {
	Kind    string   // "multilib"
	Entries []string // entries that need it
}

func (e *ErrNeedsConfirm) Error() string {
	return fmt.Sprintf("needs confirmation: %s (%s)", e.Kind, strings.Join(e.Entries, ", "))
}

// UnavailableError lists entries that cannot be installed on this host, by
// reason: unknown, only_distro, no_method, needs_flatpak, needs_npm,
// needs_aur_helper.
type UnavailableError struct {
	Reasons map[string]string
}

func (e *UnavailableError) Error() string {
	ids := make([]string, 0, len(e.Reasons))
	for id := range e.Reasons {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	parts := make([]string, len(ids))
	for i, id := range ids {
		parts[i] = id + ": " + strings.ReplaceAll(e.Reasons[id], "_", " ")
	}
	return "cannot install " + strings.Join(parts, "; ")
}

var jobSeq atomic.Int64

func init() { jobSeq.Store(time.Now().UnixMilli()) }

func newJobID(k JobKind) string { return fmt.Sprintf("%s-%d", k, jobSeq.Add(1)) }

// UpgradeJob is the "Update system and retry" job.
func UpgradeJob(self string) Job {
	return Job{ID: newJobID(KindUpgrade), Kind: KindUpgrade, NeedsRoot: true,
		Argv: []string{"pkexec", self, "sys", "upgrade"}}
}

// Plan expands requirements of ids (skipping installed entries), picks one
// install method per entry and merges entries into jobs ordered so every
// job runs after the jobs it depends on. self is the yozakura binary used
// for the privileged `sys` helper.
func Plan(c *Catalog, p Platform, st map[string]Status, ids []string, self string, opts PlanOptions) ([]Job, error) {
	order, err := expand(c, st, ids)
	if err != nil {
		return nil, err
	}
	if opts.Home == "" {
		opts.Home, _ = os.UserHomeDir()
	}
	// provided: entries installed or installed by this plan (an npm entry
	// requiring nodejs gets npm from it).
	provided := map[string]bool{}
	for id, s := range st {
		provided[id] = s.State == StateInstalled
	}
	for _, e := range order {
		provided[e.ID] = true
	}
	kinds := map[string]JobKind{}
	bad := map[string]string{}
	var multilib []string
	for _, e := range order {
		k, reason := chooseMethod(e, p, provided)
		if reason != "" {
			bad[e.ID] = reason
			continue
		}
		kinds[e.ID] = k
		if k == KindSystem && p.Distro == "arch" && e.Multilib && !p.Multilib {
			multilib = append(multilib, e.ID)
		}
	}
	if len(bad) > 0 {
		return nil, &UnavailableError{Reasons: bad}
	}
	if len(multilib) > 0 && !opts.ConfirmMultilib {
		return nil, &ErrNeedsConfirm{Kind: "multilib", Entries: multilib}
	}
	b := builder{p: p, self: self, opts: opts, byKind: map[JobKind]*Job{}, jobOf: map[string]*Job{}}
	if len(multilib) > 0 {
		b.add(&Job{ID: newJobID(KindMultilib), Kind: KindMultilib, NeedsRoot: true,
			Argv: []string{"pkexec", self, "sys", "enable-multilib"}})
	}
	for _, e := range order {
		b.place(e, kinds[e.ID])
	}
	return b.sorted(c, multilib)
}

// expand returns the requested entries plus their missing requirements in
// dependency order.
func expand(c *Catalog, st map[string]Status, ids []string) ([]Entry, error) {
	var out []Entry
	seen := map[string]bool{}
	var visit func(id string) error
	visit = func(id string) error {
		if seen[id] {
			return nil
		}
		seen[id] = true
		e, ok := c.Get(id)
		if !ok {
			return &UnavailableError{Reasons: map[string]string{id: "unknown"}}
		}
		if st[id].State == StateInstalled {
			return nil
		}
		for _, r := range e.Requires {
			if err := visit(r); err != nil {
				return err
			}
		}
		out = append(out, e)
		return nil
	}
	for _, id := range ids {
		if err := visit(id); err != nil {
			return nil, err
		}
	}
	return out, nil
}

// chooseMethod picks the installer for e: the distro's repo packages first,
// then the AUR (with paru/yay), then flatpak, npm, script and repo shell
// script. It returns a reason when nothing is usable here.
func chooseMethod(e Entry, p Platform, provided map[string]bool) (JobKind, string) {
	if len(e.Only) > 0 && !contains(e.Only, p.Distro) {
		return "", "only_distro"
	}
	in := e.Install
	reason := "no_method"
	switch p.Distro {
	case "arch":
		if in.Arch != nil && (len(in.Arch.Pkgs) > 0 || len(in.Arch.GPU[p.GPU]) > 0) {
			return KindSystem, ""
		}
		if in.Arch != nil && len(in.Arch.AUR) > 0 {
			if p.HasParu || p.HasYay {
				return KindAUR, ""
			}
			reason = "needs_aur_helper"
		}
	case "fedora":
		if in.Fedora != nil && (len(in.Fedora.Pkgs) > 0 || len(in.Fedora.GPU[p.GPU]) > 0) {
			return KindSystem, ""
		}
	}
	if in.Flatpak != "" {
		if p.HasFlatpak {
			return KindFlatpak, ""
		}
		if reason == "no_method" {
			reason = "needs_flatpak"
		}
	}
	if in.Npm != "" {
		if p.HasNpm || anyProvided(e.Requires, provided) {
			return KindNpm, ""
		}
		if reason == "no_method" {
			reason = "needs_npm"
		}
	}
	if in.Script != nil {
		return KindScript, ""
	}
	if in.Shell != "" {
		return KindShell, ""
	}
	return "", reason
}

func anyProvided(ids []string, provided map[string]bool) bool {
	for _, id := range ids {
		if provided[id] {
			return true
		}
	}
	return false
}

type builder struct {
	p      Platform
	self   string
	opts   PlanOptions
	jobs   []*Job
	byKind map[JobKind]*Job // mergeable kinds
	jobOf  map[string]*Job  // entry id -> job
}

func (b *builder) add(j *Job) { b.jobs = append(b.jobs, j) }

// place appends e to the job of kind k, merging system/aur/flatpak/npm
// entries of the batch into one job each.
func (b *builder) place(e Entry, k JobKind) {
	j := b.byKind[k]
	if j == nil || k == KindScript || k == KindShell {
		j = &Job{ID: newJobID(k), Kind: k}
		b.init(j, e)
		b.add(j)
		if k != KindScript && k != KindShell {
			b.byKind[k] = j
		}
	}
	j.Entries = append(j.Entries, e.ID)
	j.Names = append(j.Names, e.Name)
	switch k {
	case KindSystem:
		j.Argv = append(j.Argv, e.ID)
	case KindAUR:
		j.Argv = append(j.Argv, e.Install.Arch.AUR...)
	case KindFlatpak:
		j.Argv = append(j.Argv, e.Install.Flatpak)
	case KindNpm:
		j.Argv = append(j.Argv, e.Install.Npm)
	}
	b.jobOf[e.ID] = j
}

func (b *builder) init(j *Job, e Entry) {
	switch j.Kind {
	case KindSystem:
		j.NeedsRoot = true
		j.Argv = []string{"pkexec", b.self, "sys", "install"}
	case KindAUR:
		helper := "paru"
		if !b.p.HasParu {
			helper = "yay"
		}
		j.Argv = []string{helper, "-S", "--needed", "--noconfirm", "--sudo", "pkexec"}
	case KindFlatpak:
		j.Pre = [][]string{{"flatpak", "remote-add", "--user", "--if-not-exists", "flathub", flathubRepo}}
		j.Argv = []string{"flatpak", "install", "--user", "-y", "--noninteractive", "flathub"}
	case KindNpm:
		j.Argv = []string{"npm", "install", "-g", "--prefix", filepath.Join(b.opts.Home, ".local")}
	case KindScript:
		j.ScriptURL = e.Install.Script.URL
		j.Argv = []string{"bash", ScriptFile}
		for _, a := range e.Install.Script.Args {
			if strings.HasPrefix(a, "~/") {
				a = filepath.Join(b.opts.Home, a[2:])
			}
			j.Argv = append(j.Argv, a)
		}
	case KindShell:
		j.Argv = []string{"bash", filepath.Join(b.opts.ScriptsDir, e.Install.Shell)}
	}
}

// sorted fills Deps from Requires and orders jobs topologically (ties by
// kind, then creation order).
func (b *builder) sorted(c *Catalog, multilib []string) ([]Job, error) {
	deps := map[*Job]map[*Job]bool{}
	for _, j := range b.jobs {
		deps[j] = map[*Job]bool{}
	}
	link := func(j, d *Job) {
		if d != nil && d != j {
			deps[j][d] = true
		}
	}
	for id, j := range b.jobOf {
		e, _ := c.Get(id)
		for _, r := range e.Requires {
			link(j, b.jobOf[r])
		}
	}
	if len(multilib) > 0 {
		link(b.jobOf[multilib[0]], b.jobs[0])
	}
	var out []Job
	done := map[*Job]bool{}
	for len(out) < len(b.jobs) {
		var next *Job
		for _, j := range b.jobs {
			if done[j] || !allDone(deps[j], done) {
				continue
			}
			if next == nil || kindOrder[j.Kind] < kindOrder[next.Kind] {
				next = j
			}
		}
		if next == nil {
			return nil, fmt.Errorf("extras: install methods of the selection depend on each other in a cycle")
		}
		done[next] = true
		for _, j := range b.jobs {
			if deps[next][j] {
				next.Deps = append(next.Deps, j.ID)
			}
		}
		out = append(out, *next)
	}
	return out, nil
}

func allDone(set map[*Job]bool, done map[*Job]bool) bool {
	for d := range set {
		if !done[d] {
			return false
		}
	}
	return true
}
