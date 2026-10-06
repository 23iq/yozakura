package main

import (
	"bytes"
	"encoding/json"
	"strings"
	"testing"
)

type taskCall struct {
	method string
	params map[string]any
}

func fakeTaskCaller(results map[string]string, calls *[]taskCall) taskCaller {
	return func(method string, params any) (json.RawMessage, error) {
		var p map[string]any
		data, _ := json.Marshal(params)
		_ = json.Unmarshal(data, &p)
		*calls = append(*calls, taskCall{method, p})
		if r, ok := results[method]; ok {
			return json.RawMessage(r), nil
		}
		return json.RawMessage(`{}`), nil
	}
}

const sampleTask = `{"id":"k1","title":"Add hello","status":"review","plan":["a"],"runs":[{"index":0,"agent":"claude",
"status":"review","branch":"yoz/k1","checks":[{"command":"make check","status":"pass"}],
"changes":{"files":1,"insertions":2,"deletions":0}}]}`

func TestTaskCLI(t *testing.T) {
	var calls []taskCall
	call := fakeTaskCaller(map[string]string{"create": sampleTask, "get": sampleTask, "list": "[" + sampleTask + "]",
		"accept": sampleTask, "project.set": `{"dir":"/p","checkCommand":"make check","effectiveCheck":"make check","maxAttempts":3,"mergeMode":"squash"}`,
		"templates.list": `[{"id":"review","source":"bundled","description":"Review"}]`}, &calls)
	var out, errOut bytes.Buffer

	if code := runTaskWith(call, []string{"new", "Add", "hello", "--agent", "claude,codex", "--plan", "--dir", "/p"}, &out, &errOut); code != 0 {
		t.Fatalf("new: %d %s", code, errOut.String())
	}
	p := calls[0].params
	if calls[0].method != "create" || p["prompt"] != "Add hello" || p["mode"] != "plan" || p["dir"] != "/p" ||
		len(p["agents"].([]any)) != 2 {
		t.Fatalf("create params: %+v", calls[0])
	}
	if !strings.Contains(out.String(), "k1  review  Add hello") || !strings.Contains(out.String(), `check "make check": pass`) {
		t.Fatalf("output: %s", out.String())
	}

	out.Reset()
	runTaskWith(call, []string{"list"}, &out, &errOut)
	if !strings.Contains(out.String(), "k1") || !strings.Contains(out.String(), "claude") {
		t.Fatalf("list: %s", out.String())
	}

	runTaskWith(call, []string{"accept", "k1", "--run", "1", "-m", "feat: hi"}, &out, &errOut)
	last := calls[len(calls)-1]
	if last.method != "accept" || last.params["run"] != float64(1) || last.params["message"] != "feat: hi" {
		t.Fatalf("accept: %+v", last)
	}

	runTaskWith(call, []string{"followup", "k1", "please", "rename", "it"}, &out, &errOut)
	if last = calls[len(calls)-1]; last.params["text"] != "please rename it" {
		t.Fatalf("followup: %+v", last)
	}

	runTaskWith(call, []string{"discard", "k1"}, &out, &errOut)
	if last = calls[len(calls)-1]; last.method != "discard" || last.params["run"] != nil {
		t.Fatalf("discard all: %+v", last)
	}

	out.Reset()
	runTaskWith(call, []string{"project", "/p", "--check", "make check", "--max-attempts", "3"}, &out, &errOut)
	if last = calls[len(calls)-1]; last.method != "project.set" || last.params["checkCommand"] != "make check" ||
		last.params["maxAttempts"] != float64(3) {
		t.Fatalf("project: %+v", last)
	}
	if !strings.Contains(out.String(), "max attempts  3") {
		t.Fatalf("project output: %s", out.String())
	}

	out.Reset()
	runTaskWith(call, []string{"templates"}, &out, &errOut)
	if !strings.Contains(out.String(), "/review") {
		t.Fatalf("templates: %s", out.String())
	}

	if code := runTaskWith(call, []string{"bogus"}, &out, &errOut); code != 2 {
		t.Fatalf("unknown sub: %d", code)
	}
	if code := runTaskWith(call, nil, &out, &errOut); code != 2 {
		t.Fatalf("help: %d", code)
	}
}
