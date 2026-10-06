package tasks

import (
	"encoding/json"
	"strings"
	"testing"

	"yozakura/backend/pkg/svc/agents"
)

func TestServiceHandlers(t *testing.T) {
	e := newEnv(t, func(f *fakeAgents, s agents.SessionMeta, text string, turn int) {
		if turn == 0 {
			f.reply(s.ID, "1. Look\n2. Write")
			return
		}
		writer(f, s, text, turn)
	})
	s := NewService(e.m)
	raw := func(v any) json.RawMessage { b, _ := json.Marshal(v); return b }

	res, err := s.create(raw(map[string]any{"dir": e.repo, "prompt": "Hello", "agent": "claude", "mode": "plan"}))
	if err != nil {
		t.Fatal(err)
	}
	id := res.(Task).ID
	waitTask(t, e.m, id, "plan", statusIs(StatusAwaitingPlan))
	if res, err = s.planUpdate(raw(map[string]any{"id": id, "steps": []string{"Write hello"}})); err != nil || len(res.(Task).Plan) != 1 {
		t.Fatalf("plan.update: %v %v", res, err)
	}
	if _, err = s.run(raw(map[string]any{"id": id})); err != nil {
		t.Fatal(err)
	}
	waitTask(t, e.m, id, "review", statusIs(StatusReview))
	if res, err = s.list(nil); err != nil || len(res.([]Task)) != 1 {
		t.Fatalf("list: %v %v", res, err)
	}
	if res, err = s.diff(raw(map[string]any{"id": id})); err != nil || !strings.Contains(res.(map[string]any)["diff"].(string), "hello.txt") {
		t.Fatalf("diff: %v %v", res, err)
	}
	if res, err = s.debug(raw(map[string]any{"id": id})); err != nil || res.(DebugInfo).Session == "" {
		t.Fatalf("debug: %+v %v", res, err)
	}
	if res, err = s.git(raw(map[string]any{"dir": e.repo})); err != nil || res.(GitSummary).Branch != "main" {
		t.Fatalf("git: %+v %v", res, err)
	}
	if res, err = s.templatesList(raw(map[string]any{"dir": e.repo})); err != nil || len(res.([]Template)) < 5 {
		t.Fatalf("templates: %v %v", res, err)
	}
	if res, err = s.templatesGet(raw(map[string]any{"name": "fix-check", "dir": e.repo, "render": true})); err != nil ||
		strings.Contains(res.(Template).Body, "{{") {
		t.Fatalf("template render: %+v %v", res, err)
	}
	if _, err = s.open(raw(map[string]any{"id": id})); err != nil {
		t.Fatalf("open: %v", err)
	}
	if res, err = s.accept(raw(map[string]any{"id": id, "run": 0})); err != nil || res.(Task).Status != StatusAccepted {
		t.Fatalf("accept: %v %v", res, err)
	}
	if _, err = s.delete(raw(map[string]any{"id": id})); err != nil {
		t.Fatal(err)
	}
	if _, err = s.get(raw(map[string]any{"id": id})); err == nil {
		t.Fatal("deleted task still there")
	}
	if _, err = s.create(nil); err == nil {
		t.Fatal("missing params accepted")
	}
}
