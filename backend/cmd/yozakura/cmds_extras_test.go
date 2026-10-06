package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

type fakeExtras struct {
	results map[string]string
	errs    map[string]error
	calls   []string
	params  map[string]any
	events  [][2]string // name, JSON, delivered on Watch
}

func (f *fakeExtras) Call(method string, params any) (json.RawMessage, error) {
	f.calls = append(f.calls, method)
	if m, ok := params.(map[string]any); ok && method == "extras.install" {
		f.params = m
	}
	if err := f.errs[method]; err != nil {
		return nil, err
	}
	if r, ok := f.results[method]; ok {
		return json.RawMessage(r), nil
	}
	return nil, errors.New("down")
}

func (f *fakeExtras) Watch(fn func(string, json.RawMessage) bool) (func(), error) {
	go func() {
		for _, e := range f.events {
			if fn(e[0], json.RawMessage(e[1])) {
				return
			}
		}
	}()
	return func() {}, nil
}

const extrasCat = `{"entries":[{"id":"firefox","name":"Firefox","category":"browsers"},
 {"id":"nodejs","name":"Node.js","category":"dev","hidden":true},
 {"id":"codex","name":"Codex","category":"ai"}]}`
const extrasStat = `{"firefox":{"id":"firefox","state":"installed","source":"pkg"},
 "codex":{"id":"codex","state":"unavailable","reason":"no_method"},"nodejs":{"id":"nodejs","state":"missing"}}`

func newFakeExtras() *fakeExtras {
	return &fakeExtras{results: map[string]string{"extras.catalog": extrasCat, "extras.status": extrasStat}, errs: map[string]error{}}
}

func TestExtrasList(t *testing.T) {
	f := newFakeExtras()
	var out, errOut bytes.Buffer
	assert.Equal(t, 0, runExtras(nil, f, &out, &errOut))
	assert.Regexp(t, `firefox\s+Firefox\s+browsers\s+installed`, out.String())
	assert.Regexp(t, `codex\s+Codex\s+ai\s+unavailable \(no_method\)`, out.String())
	assert.NotContains(t, out.String(), "nodejs", "hidden entries are not listed")

	out.Reset()
	assert.Equal(t, 0, runExtras([]string{"list", "--category", "ai", "--json"}, f, &out, &errOut))
	var rows []map[string]any
	assert.NoError(t, json.Unmarshal(out.Bytes(), &rows))
	assert.Len(t, rows, 1)
	assert.Equal(t, "codex", rows[0]["id"])

	assert.Equal(t, 1, runExtras(nil, &fakeExtras{}, &out, &errOut), "shell down")
	assert.Equal(t, 2, runExtras([]string{"--category"}, f, &out, &errOut))
	assert.Equal(t, 2, runExtras([]string{"bogus"}, f, &out, &errOut))
	assert.Equal(t, 2, runExtras([]string{"install"}, f, &out, &errOut))
}

func TestExtrasStatus(t *testing.T) {
	f := newFakeExtras()
	var out, errOut bytes.Buffer
	assert.Equal(t, 0, runExtras([]string{"status", "firefox"}, f, &out, &errOut))
	assert.Contains(t, out.String(), "firefox: installed (via pkg)")
	assert.Equal(t, 1, runExtras([]string{"status", "nope"}, f, &out, &errOut))
	assert.Contains(t, errOut.String(), "unknown entry")
}

func TestExtrasInstallStreams(t *testing.T) {
	f := newFakeExtras()
	f.results["extras.install"] = `{"jobs":[{"id":"system-1","kind":"system","entries":["firefox"]}]}`
	f.events = [][2]string{
		{"extras.status", `{}`},
		{"extras.progress", `{"job":"system-1","state":"running","percent":40,"phase":"installing firefox"}`},
		{"extras.progress", `{"job":"other-9","state":"failed"}`},
		{"extras.progress", `{"job":"system-1","state":"done","percent":100}`},
	}
	var out, errOut bytes.Buffer
	assert.Equal(t, 0, runExtras([]string{"install", "firefox", "--yes-multilib"}, f, &out, &errOut))
	assert.Equal(t, map[string]any{"ids": []string{"firefox"}, "confirmMultilib": true}, f.params)
	assert.Contains(t, out.String(), "queued system-1: firefox")
	assert.Contains(t, out.String(), " 40% installing firefox")
	assert.Contains(t, out.String(), "system-1: done")
	assert.Empty(t, errOut.String())
}

func TestExtrasInstallFailureAndErrors(t *testing.T) {
	f := newFakeExtras()
	f.results["extras.install"] = `{"jobs":[{"id":"system-1","kind":"system","entries":["firefox"]}]}`
	f.events = [][2]string{{"extras.progress", `{"job":"system-1","state":"cancelled","reason":"auth_cancelled"}`}}
	var out, errOut bytes.Buffer
	assert.Equal(t, 1, runExtras([]string{"install", "firefox"}, f, &out, &errOut))
	assert.Contains(t, errOut.String(), "cancelled (auth_cancelled)")

	f.results["extras.install"] = `{"jobs":[]}`
	out.Reset()
	assert.Equal(t, 0, runExtras([]string{"install", "firefox"}, f, &out, &errOut))
	assert.Contains(t, out.String(), "Nothing to install")

	f.errs["extras.install"] = errors.New(`needs_confirm: {"entries":["steam"],"kind":"multilib"}`)
	errOut.Reset()
	assert.Equal(t, 1, runExtras([]string{"install", "steam"}, f, &out, &errOut))
	assert.Contains(t, errOut.String(), "--yes-multilib")

	f.errs["extras.install"] = errors.New(`unavailable: {"reasons":{"zen":"needs_aur_helper"}}`)
	errOut.Reset()
	assert.Equal(t, 1, runExtras([]string{"install", "zen"}, f, &out, &errOut))
	assert.Contains(t, errOut.String(), "zen: needs_aur_helper")
}

func TestExtrasCompletion(t *testing.T) {
	for _, sh := range []string{"bash", "zsh", "fish"} {
		s, err := completionScript(sh)
		assert.NoError(t, err)
		assert.Contains(t, s, "list install status help", sh)
	}
}

func TestExtrasInstallMissedEventFailedEntry(t *testing.T) {
	old := extrasQuiet
	extrasQuiet = 20 * time.Millisecond
	defer func() { extrasQuiet = old }()
	f := newFakeExtras()
	f.results["extras.install"] = `{"jobs":[{"id":"system-1","kind":"system","entries":["firefox"]}]}`
	f.results["extras.status"] = `{"firefox":{"id":"firefox","state":"failed","reason":"needs_sync"}}`
	var out, errOut bytes.Buffer
	assert.Equal(t, 1, runExtras([]string{"install", "firefox"}, f, &out, &errOut))
	assert.Contains(t, errOut.String(), "firefox: failed (needs_sync)")
}
