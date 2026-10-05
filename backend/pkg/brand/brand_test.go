package brand

import "testing"

func TestEnvFallback(t *testing.T) {
	t.Setenv(LegacyEnvPrefix+"SHELL", "/legacy")
	if got := Env("SHELL"); got != "/legacy" {
		t.Fatalf("legacy fallback: got %q", got)
	}
	t.Setenv(EnvPrefix+"SHELL", "/new")
	if got := Env("SHELL"); got != "/new" {
		t.Fatalf("new prefix wins: got %q", got)
	}
}

func TestDaemonSocketPath(t *testing.T) {
	dir := t.TempDir()
	t.Setenv(DaemonEnv("SOCKET"), "")
	t.Setenv("XDG_RUNTIME_DIR", dir)
	if got, want := DaemonSocketPath(), dir+"/"+Daemon+".sock"; got != want {
		t.Fatalf("runtime dir: got %q want %q", got, want)
	}
	t.Setenv(DaemonEnv("SOCKET"), "/custom.sock")
	if got := DaemonSocketPath(); got != "/custom.sock" {
		t.Fatalf("override: got %q", got)
	}
}
