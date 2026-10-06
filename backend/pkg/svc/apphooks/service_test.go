package apphooks

import (
	"encoding/json"
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
