package apphooks

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"yozakura/backend/pkg/apphooks"
)

type stubHook struct {
	id      string
	state   apphooks.State
	applied int
	reverts int
}

func (h *stubHook) ID() string { return h.id }
func (h *stubHook) Status(apphooks.Env) apphooks.Status {
	return apphooks.Status{ID: h.id, State: h.state}
}
func (h *stubHook) Apply(apphooks.Env) (apphooks.Status, error) {
	h.applied++
	h.state = apphooks.StateConnected
	return h.Status(apphooks.Env{}), nil
}
func (h *stubHook) Revert(apphooks.Env) (apphooks.Status, error) {
	h.reverts++
	h.state = apphooks.StateDisconnected
	return h.Status(apphooks.Env{}), nil
}

func TestEnsureOnlyAppliesDisconnected(t *testing.T) {
	hs := map[apphooks.State]*stubHook{}
	var ids []string
	for _, st := range []apphooks.State{apphooks.StateDisconnected, apphooks.StateAbsent, apphooks.StateManaged, apphooks.StateError, apphooks.StateConnected} {
		h := &stubHook{id: "svc-test-" + string(st), state: st}
		apphooks.Register(h)
		hs[st] = h
		ids = append(ids, h.id)
	}
	s := newService(apphooks.Env{})
	raw, _ := json.Marshal(map[string]any{"ids": append(ids, "svc-test-unknown")})
	res, err := s.ensure(raw)
	if err != nil {
		t.Fatal(err)
	}
	out := res.(map[string]apphooks.Status)
	if hs[apphooks.StateDisconnected].applied != 1 || out["svc-test-disconnected"].State != apphooks.StateConnected {
		t.Fatalf("disconnected not applied: %v", out)
	}
	for _, st := range []apphooks.State{apphooks.StateAbsent, apphooks.StateManaged, apphooks.StateError, apphooks.StateConnected} {
		if hs[st].applied != 0 {
			t.Fatalf("%s was touched", st)
		}
	}
	if len(out) != 5 {
		t.Fatalf("unknown id should be skipped: %v", out)
	}
}

func TestRevertAndApplyByID(t *testing.T) {
	h := &stubHook{id: "svc-test-one", state: apphooks.StateConnected}
	apphooks.Register(h)
	s := newService(apphooks.Env{})
	if _, err := s.revert(json.RawMessage(`{"id":"svc-test-one"}`)); err != nil || h.reverts != 1 {
		t.Fatalf("revert %v %d", err, h.reverts)
	}
	if _, err := s.apply(json.RawMessage(`{"id":"svc-test-one"}`)); err != nil || h.applied != 1 {
		t.Fatalf("apply %v %d", err, h.applied)
	}
	if _, err := s.apply(json.RawMessage(`{"id":"nope"}`)); err == nil {
		t.Fatal("unknown id must error")
	}
	if _, err := s.apply(json.RawMessage(`{}`)); err == nil {
		t.Fatal("missing id must error")
	}
}

type themedHook struct{ stubHook }

func (h *themedHook) Status(apphooks.Env) apphooks.Status {
	st := apphooks.Status{ID: h.id, State: h.state}
	if h.state == apphooks.StateDisconnected {
		st.Reason = apphooks.ReasonUserTheme
	}
	return st
}

// ensure (automatic) never connects an app with a theme of its own; an
// explicit apply does.
func TestEnsureSkipsUserTheme(t *testing.T) {
	h := &themedHook{stubHook{id: "svc-test-themed", state: apphooks.StateDisconnected}}
	apphooks.Register(h)
	s := newService(apphooks.Env{})
	if _, err := s.ensure([]byte(`{"ids":["svc-test-themed"]}`)); err != nil || h.applied != 0 {
		t.Fatalf("auto-connected: %d %v", h.applied, err)
	}
	if _, err := s.apply([]byte(`{"id":"svc-test-themed"}`)); err != nil || h.applied != 1 {
		t.Fatalf("explicit apply: %d %v", h.applied, err)
	}
}

// An installed app is connected only when its theming toggle is on.
func TestPostInstallHonoursToggle(t *testing.T) {
	h := &stubHook{id: "svc-test-post", state: apphooks.StateDisconnected}
	apphooks.Register(h)
	apps := filepath.Join(t.TempDir(), "apps.json")
	s := newService(apphooks.Env{})
	s.appsFile = apps
	if err := os.WriteFile(apps, []byte(`{"theming":{"svc-test-post":false}}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := s.PostInstall("svc-test-post"); err != nil || h.applied != 0 {
		t.Fatalf("toggle off: applied %d %v", h.applied, err)
	}
	if err := os.WriteFile(apps, []byte(`{"theming":{}}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := s.PostInstall("svc-test-post"); err != nil || h.applied != 1 {
		t.Fatalf("toggle on (default): applied %d %v", h.applied, err)
	}
	if err := s.PostInstall("nope"); err == nil {
		t.Fatal("unknown hook must error")
	}
}

// Until the consent migration ran nothing is connected automatically.
func TestNoAutoConnectWithoutConsent(t *testing.T) {
	h := &stubHook{id: "svc-test-consent", state: apphooks.StateDisconnected}
	apphooks.Register(h)
	s := newService(apphooks.Env{})
	s.consented = func() bool { return false }
	if _, err := s.ensure([]byte(`{"ids":["svc-test-consent"]}`)); err != nil || h.applied != 0 {
		t.Fatalf("ensure applied %d %v", h.applied, err)
	}
	if err := s.PostInstall("svc-test-consent"); err != nil || h.applied != 0 {
		t.Fatalf("post applied %d %v", h.applied, err)
	}
	if _, err := s.apply([]byte(`{"id":"svc-test-consent"}`)); err != nil || h.applied != 1 {
		t.Fatalf("explicit Connect still works: %d %v", h.applied, err)
	}
}
