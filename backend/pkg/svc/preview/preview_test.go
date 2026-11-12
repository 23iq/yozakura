package preview

import (
	"encoding/json"
	"testing"
	"time"

	"yozakura/backend/pkg/ipc"

	"github.com/stretchr/testify/assert"
)

type ev struct {
	name string
	data string
}

func drain(t *testing.T, sub *ipc.Subscriber, n int) []ev {
	t.Helper()
	var out []ev
	for len(out) < n {
		select {
		case e := <-sub.Events:
			b, _ := json.Marshal(e.Data)
			out = append(out, ev{e.Service, string(b)})
		case <-time.After(2 * time.Second):
			t.Fatalf("got %d events, want %d: %v", len(out), n, out)
		}
	}
	return out
}

func noMore(t *testing.T, sub *ipc.Subscriber) {
	t.Helper()
	select {
	case e := <-sub.Events:
		t.Fatalf("unexpected event %v", e)
	case <-time.After(50 * time.Millisecond):
	}
}

func subscribed(t *testing.T, s *Service) *ipc.Subscriber {
	t.Helper()
	sub := ipc.NewSubscriber(64)
	go s.subscribe(sub)
	t.Cleanup(sub.Stop)
	must(t, assert.Eventually(t, func() bool {
		s.mu.Lock()
		defer s.mu.Unlock()
		return len(s.subs) == 1
	}, time.Second, 5*time.Millisecond))
	return sub
}

func call(t *testing.T, fn ipc.HandlerFunc, params string) any {
	t.Helper()
	res, err := fn(json.RawMessage(params))
	must(t, assert.NoError(t, err))
	return res
}

func TestSetRelaysAndReplacesPerKey(t *testing.T) {
	s := NewService()
	sub := subscribed(t, s)
	call(t, s.handleSet, `{"owner":"settings","key":"bar.position","value":"bottom"}`)
	call(t, s.handleSet, `{"owner":"settings","key":"theme.roundness","value":12}`)
	call(t, s.handleSet, `{"owner":"settings","key":"bar.position","value":"left"}`)
	got := drain(t, sub, 3)
	assert.Equal(t, "preview.set", got[0].name)
	assert.JSONEq(t, `{"owner":"settings","key":"bar.position","value":"bottom"}`, got[0].data)
	assert.JSONEq(t, `{"owner":"settings","key":"bar.position","value":"left"}`, got[2].data)
	// one entry per key, in first-set order, latest value
	st := s.Staged()
	must(t, assert.Len(t, st, 2))
	assert.Equal(t, "bar.position", st[0].Key)
	assert.JSONEq(t, `"left"`, string(st[0].Value))
	assert.Equal(t, "theme.roundness", st[1].Key)
}

func TestSetValidates(t *testing.T) {
	s := NewService()
	for _, p := range []string{`{"key":"a.b","value":1}`, `{"owner":"settings","value":1}`, `{bad`} {
		_, err := s.handleSet(json.RawMessage(p))
		assert.Error(t, err, p)
	}
	_, err := s.handleDone(s.Commit)(json.RawMessage(`{}`))
	assert.Error(t, err)
	// a missing value is a staged null, not an error
	call(t, s.handleSet, `{"owner":"settings","key":"a.b"}`)
	assert.JSONEq(t, `null`, string(s.Staged()[0].Value))
}

func TestCommitAndDiscardClearAndTellTheShell(t *testing.T) {
	s := NewService()
	sub := subscribed(t, s)
	call(t, s.handleSet, `{"owner":"settings","key":"bar.position","value":"bottom"}`)
	drain(t, sub, 1)

	res := call(t, s.handleDone(s.Commit), `{"owner":"settings"}`)
	assert.Equal(t, map[string]any{"ok": true}, res)
	got := drain(t, sub, 1)
	assert.Equal(t, ev{"preview.commit", `{"owner":"settings"}`}, got[0])
	assert.Empty(t, s.Staged())

	call(t, s.handleSet, `{"owner":"settings","key":"dock.enabled","value":false}`)
	drain(t, sub, 1)
	call(t, s.handleDone(s.Discard), `{"owner":"settings"}`)
	got = drain(t, sub, 1)
	assert.Equal(t, ev{"preview.discard", `{"owner":"settings"}`}, got[0])
	assert.Empty(t, s.Staged())

	// nothing staged: still told (the shell may hold a staging the daemon lost)
	res = call(t, s.handleDone(s.Discard), `{"owner":"settings"}`)
	assert.Equal(t, map[string]any{"ok": false}, res)
	drain(t, sub, 1)
	noMore(t, sub)
}

// One staging, as in-process: Apply or Discard by either window ends what
// both staged, in both orders.
func TestCommitOrDiscardEndsEveryOwnersStaging(t *testing.T) {
	for _, first := range []string{"commit", "discard"} {
		s := NewService()
		sub := subscribed(t, s)
		s.Set(Entry{Owner: "onboarding", Key: "theme.roundness", Value: json.RawMessage("8")})
		s.Set(Entry{Owner: "settings", Key: "bar.position", Value: json.RawMessage(`"top"`)})
		drain(t, sub, 2)
		fn, then := s.Commit, s.Discard
		if first == "discard" {
			fn, then = s.Discard, s.Commit
		}
		assert.True(t, fn("settings"), first)
		got := drain(t, sub, 1)
		assert.Equal(t, ev{"preview." + first, `{"owner":"settings"}`}, got[0])
		assert.Empty(t, s.Staged(), "%s by one owner ends the other's too", first)
		noMore(t, sub)
		// the other window's later Apply / Discard has nothing left
		assert.False(t, then("onboarding"))
		drain(t, sub, 1)
	}
}

// A window gone while the other runs: the staging stays for that one to
// apply or discard; the last window gone: discarded.
func TestOwnerGone(t *testing.T) {
	s := NewService()
	sub := subscribed(t, s)
	s.OwnerGone("settings", false)
	noMore(t, sub) // nothing staged: nothing to say
	s.Set(Entry{Owner: "onboarding", Key: "theme.roundness", Value: json.RawMessage("8")})
	s.Set(Entry{Owner: "settings", Key: "bar.position", Value: json.RawMessage(`"top"`)})
	drain(t, sub, 2)

	s.OwnerGone("settings", true)
	noMore(t, sub)
	must(t, assert.Len(t, s.Staged(), 2))

	s.OwnerGone("onboarding", false)
	assert.Equal(t, ev{"preview.discard", `{"owner":"onboarding"}`}, drain(t, sub, 1)[0])
	assert.Empty(t, s.Staged())
}

func TestSubscribeReplaysStagedValues(t *testing.T) {
	s := NewService()
	s.Set(Entry{Owner: "settings", Key: "bar.position", Value: json.RawMessage(`"bottom"`)})
	s.Set(Entry{Owner: "settings", Key: "notch.enabled", Value: json.RawMessage(`false`)})
	// a main shell that (re)starts while the window is open
	sub := subscribed(t, s)
	got := drain(t, sub, 2)
	assert.JSONEq(t, `{"owner":"settings","key":"bar.position","value":"bottom"}`, got[0].data)
	assert.JSONEq(t, `{"owner":"settings","key":"notch.enabled","value":false}`, got[1].data)
	noMore(t, sub)
}

func must(t *testing.T, ok bool) {
	t.Helper()
	if !ok {
		t.FailNow()
	}
}
