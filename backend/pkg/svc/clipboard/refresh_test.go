package clipboard

import (
	"encoding/json"
	"testing"
)

type fakeSender struct{ events []string }

func (f *fakeSender) Send(service string, _ any) { f.events = append(f.events, service) }

// Every mutation emits clipboard.refresh so the UI does not re-list itself.
func TestMutationsEmitRefresh(t *testing.T) {
	t.Setenv("PATH", "") // clear() runs wl-copy; keep it off the real clipboard
	svc := NewService(testPaths(t))
	defer svc.Close()
	fs := &fakeSender{}
	svc.setSender(fs)
	st, err := svc.getStore()
	if err != nil {
		t.Fatal(err)
	}
	if ok, _ := st.insertUnpinned("text/plain", []byte("a"), false, 1); !ok {
		t.Fatal("insert failed")
	}
	call := func(m func(json.RawMessage) (any, error), params string) {
		t.Helper()
		if _, err := m(json.RawMessage(params)); err != nil {
			t.Fatal(err)
		}
	}
	call(svc.setAlias, `{"id":"u:1","alias":"x"}`)
	call(svc.togglePin, `{"id":"u:1"}`)
	call(svc.reorder, `{"id":"p:1","new_index":0}`)
	call(svc.delete, `{"id":"p:1"}`)
	call(svc.clear, `{}`)
	if len(fs.events) != 5 {
		t.Fatalf("expected 5 refresh events, got %v", fs.events)
	}
	for _, e := range fs.events {
		if e != "clipboard.refresh" {
			t.Fatalf("unexpected event %q", e)
		}
	}
}
