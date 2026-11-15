package convert

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

// Every user-facing error carries a stable code and its arguments.
func TestErrorCodes(t *testing.T) {
	code := func(err error) (string, []string) { return CodeOf(err, "fallback") }
	check := func(name string, err error, wantCode string, wantArgs ...string) {
		t.Helper()
		c, a := code(err)
		if c != wantCode || (len(wantArgs) > 0 && !reflect.DeepEqual(a, wantArgs)) {
			t.Errorf("%s: %q %v (%v), want %q %v", name, c, a, err, wantCode, wantArgs)
		}
	}
	_, err := BuildPlan(Request{Src: "/a.mp3", From: "mp3", To: "pdf"}, allTools(), "/w", PlanOptions{})
	check("unsupported", err, CodeUnsupported, "MP3", "PDF")
	_, err = BuildPlan(Request{Src: "/a.flac", From: "flac", To: "mp3"}, noTools(), "/w", PlanOptions{})
	check("tool missing", err, CodeToolMissing, "MP3", "ffmpeg")

	dir := t.TempDir()
	bad := filepath.Join(dir, "bad.json")
	_ = os.WriteFile(bad, []byte("{nope"), 0o644)
	err = ConvertNative(bad, "json", filepath.Join(dir, "o.yaml"), "yaml", QualityBalanced)
	check("bad input", err, CodeBadInput)
	if err == nil || err.Error() != "not valid JSON" {
		t.Errorf("detail lost: %v", err)
	}
	err = placeInput(context.Background(), filepath.Join(dir, "missing"), filepath.Join(dir, "in"))
	check("not found", err, CodeNotFound)
	_, err = Reserve(filepath.Join(dir, "a.json"), "yaml", filepath.Join(dir, "no", "such"))
	check("no write", err, CodeNoWrite)

	check("cancelled", fmt.Errorf("step: %w", context.Canceled), CodeCancelled)
	check("deadline", context.DeadlineExceeded, CodeTimeout)
	check("plain", errors.New("x"), "fallback")
	if c, _ := CodeOf(nil, "fallback"); c != "" {
		t.Error("nil has a code")
	}
	// Wrap keeps an existing code and the message
	inner := Errorf(CodeTooLarge, nil, "big")
	if c, _ := code(Wrap(CodeBadInput, fmt.Errorf("ctx: %w", inner))); c != CodeTooLarge {
		t.Error("Wrap replaced a code")
	}
	if w := Wrap(CodeBadInput, errors.New("m")); w.Error() != "m" {
		t.Error("Wrap changed the message")
	}
	if Wrap(CodeBadInput, nil) != nil {
		t.Error("Wrap(nil)")
	}
}
