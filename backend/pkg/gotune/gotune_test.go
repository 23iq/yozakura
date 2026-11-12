package gotune

import (
	"runtime"
	"runtime/debug"
	"testing"
)

func env(vars map[string]string) func(string) string {
	return func(k string) string { return vars[k] }
}

func TestPlanDefaults(t *testing.T) {
	got := Plan(Daemon, env(nil), 16)
	want := Settings{MemLimit: 512 << 20, GCPercent: 50}
	if got != want {
		t.Fatalf("Plan = %+v, want %+v", got, want)
	}
}

// The shell daemon encodes screenshots with one PNG band per P: capping
// GOMAXPROCS would make captures slower on machines with more CPUs.
func TestDaemonKeepsEveryCPU(t *testing.T) {
	for _, procs := range []int{1, 4, 8, 64} {
		if got := Plan(Daemon, env(nil), procs); got.MaxProcs != 0 {
			t.Fatalf("procs %d: MaxProcs = %d, want untouched", procs, got.MaxProcs)
		}
	}
	if got := Plan(CompositorDaemon, env(nil), 16); got.MaxProcs != 2 {
		t.Fatalf("compositor daemon on 16 CPUs: MaxProcs = %d, want 2", got.MaxProcs)
	}
}

func TestPlanYieldsToEnvironment(t *testing.T) {
	got := Plan(Daemon, env(map[string]string{"GOMEMLIMIT": "1GiB", "GOGC": "200", "GOMAXPROCS": "8"}), 16)
	if got != (Settings{}) {
		t.Fatalf("Plan with every variable set = %+v, want nothing", got)
	}
	got = Plan(CompositorDaemon, env(map[string]string{"GOGC": "off"}), 16)
	if got.GCPercent != 0 || got.MemLimit == 0 || got.MaxProcs == 0 {
		t.Fatalf("Plan with GOGC set = %+v", got)
	}
}

func TestPlanNeverRaisesProcs(t *testing.T) {
	for _, procs := range []int{1, 2, 4} {
		if got := Plan(Daemon, env(nil), procs); got.MaxProcs != 0 {
			t.Fatalf("procs %d: MaxProcs = %d, want untouched", procs, got.MaxProcs)
		}
	}
	if got := Plan(CompositorDaemon, env(nil), 3); got.MaxProcs != 2 {
		t.Fatalf("compositor daemon on 3 CPUs: MaxProcs = %d, want 2", got.MaxProcs)
	}
}

// The limits must leave the daemons room for their large transient
// payloads; a tighter value needs a reason, not a quiet edit.
func TestPoliciesStayLoose(t *testing.T) {
	for name, p := range map[string]Policy{"daemon": Daemon, "compositor": CompositorDaemon} {
		if p.MemLimit < 256<<20 || p.GCPercent < 50 || (p.MaxProcs != 0 && p.MaxProcs < 2) {
			t.Fatalf("%s policy too tight: %+v", name, p)
		}
	}
}

func TestApplySetsRuntime(t *testing.T) {
	prevLimit := debug.SetMemoryLimit(-1)
	prevGC := debug.SetGCPercent(100)
	prevProcs := runtime.GOMAXPROCS(0)
	t.Cleanup(func() {
		debug.SetMemoryLimit(prevLimit)
		debug.SetGCPercent(prevGC)
		runtime.GOMAXPROCS(prevProcs)
	})
	s := Apply(Policy{MemLimit: 300 << 20, GCPercent: 60, MaxProcs: 1}, env(nil))
	if got := debug.SetMemoryLimit(-1); got != 300<<20 {
		t.Fatalf("memory limit = %d", got)
	}
	if got := debug.SetGCPercent(60); got != 60 {
		t.Fatalf("GC percent = %d", got)
	}
	if prevProcs > 1 && (runtime.GOMAXPROCS(0) != 1 || s.MaxProcs != 1) {
		t.Fatalf("GOMAXPROCS = %d, settings %+v", runtime.GOMAXPROCS(0), s)
	}
}
