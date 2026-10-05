package agents

import (
	"strings"
	"testing"
)

func TestCodexResumeFailureStartsNewThread(t *testing.T) {
	sink := &recSink{}
	c, f := startFake(t, "codex", "codex_resume_fallback.jsonl", StartOptions{ResumeID: "old"}, sink)
	_ = c.Send("hi", nil)
	waitFor(t, "done", func() bool { return sink.count(KindDone) == 1 })
	if _, _, id := sink.snapshot(); id != "new-thread" {
		t.Errorf("thread = %q", id)
	}
	if e := sink.find(KindError, nil); e == nil || !strings.Contains(e.Message, "no rollout found") {
		t.Errorf("resume failure not reported: %+v", e)
	}
	if in := f.stdin(); !strings.Contains(in, `"method":"thread/start"`) || !strings.Contains(in, `"threadId":"new-thread"`) {
		t.Errorf("stdin = %s", in)
	}
}

func TestCodexStartFailureEndsTheTurn(t *testing.T) {
	sink := &recSink{}
	c, _ := startFake(t, "codex", "codex_start_fail.jsonl", StartOptions{}, sink)
	_ = c.Send("hi", nil)
	waitFor(t, "done", func() bool { return sink.count(KindDone) >= 1 })
	if e := sink.find(KindError, nil); e == nil || !strings.Contains(e.Message, "not logged in") {
		t.Errorf("error = %+v", e)
	}
	waitFor(t, "exit", func() bool { sink.mu.Lock(); defer sink.mu.Unlock(); return sink.exited })
}

func TestACPLoadFailureCreatesNewSession(t *testing.T) {
	sink := &recSink{}
	c, f := startFake(t, "opencode", "acp_load_fallback.jsonl", StartOptions{ResumeID: "ses_old"}, sink)
	_ = c.Send("hi", nil)
	waitFor(t, "done", func() bool { return sink.count(KindDone) == 1 })
	if _, _, id := sink.snapshot(); id != "ses_new" {
		t.Errorf("session = %q", id)
	}
	if in := f.stdin(); !strings.Contains(in, `"method":"session/new"`) || !strings.Contains(in, `"sessionId":"ses_new"`) {
		t.Errorf("stdin = %s", in)
	}
}

func TestACPInitFailureEndsTheTurn(t *testing.T) {
	sink := &recSink{}
	c, _ := startFake(t, "opencode", "acp_init_fail.jsonl", StartOptions{}, sink)
	_ = c.Send("hi", nil)
	waitFor(t, "done", func() bool { return sink.count(KindDone) >= 1 })
	if e := sink.find(KindError, nil); e == nil || !strings.Contains(e.Message, "auth required") {
		t.Errorf("error = %+v", e)
	}
	waitFor(t, "exit", func() bool { sink.mu.Lock(); defer sink.mu.Unlock(); return sink.exited })
}
