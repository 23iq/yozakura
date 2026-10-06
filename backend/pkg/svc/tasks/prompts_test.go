package tasks

import (
	"reflect"
	"strings"
	"testing"
	"time"
)

func TestParsePlan(t *testing.T) {
	cases := map[string][]string{
		"Plan:\n1. Read\n2) Write tests\n   for the parser\n3. Ship\n\nThanks": {"Read", "Write tests for the parser", "Ship"},
		"**1.** Bold step\n**2.** Next":                                        {"Bold step", "Next"},
		"- a\n- b\n* c":                                                        {"a", "b", "c"},
		"First paragraph\nstill first.\n\nSecond.":                             {"First paragraph still first.", "Second."},
	}
	for in, want := range cases {
		if got := ParsePlan(in); !reflect.DeepEqual(got, want) {
			t.Errorf("ParsePlan(%q) = %q want %q", in, got, want)
		}
	}
}

func TestParseCommit(t *testing.T) {
	s, m := parseCommit("Did things.\n\n```commit\nfix: parser\n\nbody\n```\nBye")
	if s != "Did things.\n\n\nBye" && s != "Did things.\n\nBye" {
		if !strings.HasPrefix(s, "Did things.") || !strings.HasSuffix(s, "Bye") {
			t.Fatalf("summary %q", s)
		}
	}
	if m != "fix: parser\n\nbody" {
		t.Fatalf("message %q", m)
	}
	if s, m := parseCommit("plain"); s != "plain" || m != "" {
		t.Fatalf("plain: %q %q", s, m)
	}
	tk := &Task{Title: "Add thing"}
	if msg := defaultCommitMessage(tk, &Run{Summary: "Added it"}); msg != "Add thing\n\nAdded it" {
		t.Fatalf("default %q", msg)
	}
}

func TestDetectLimit(t *testing.T) {
	now := time.Date(2026, 10, 6, 14, 0, 0, 0, time.Local)
	if hit, _ := detectLimit("syntax error", now); hit {
		t.Fatal("false positive")
	}
	if hit, at := detectLimit("Claude AI usage limit reached|1790000000", now); !hit || at.Unix() != 1790000000 {
		t.Fatalf("epoch: %v %v", hit, at)
	}
	if hit, at := detectLimit("You've hit your usage limit. Try again in 2 hours 5 minutes.", now); !hit || at != now.Add(2*time.Hour+5*time.Minute) {
		t.Fatalf("in: %v %v", hit, at)
	}
	if hit, at := detectLimit("Rate limit reached, resets at 3pm", now); !hit || at.Hour() != 15 || at.Day() != 6 {
		t.Fatalf("at pm: %v %v", hit, at)
	}
	if hit, at := detectLimit("usage limit; try again at 9:30", now); !hit || at.Hour() != 9 || at.Minute() != 30 || at.Day() != 7 {
		t.Fatalf("at tomorrow: %v %v", hit, at)
	}
	if hit, at := detectLimit("429 Too Many Requests", now); !hit || !at.IsZero() {
		t.Fatalf("unknown reset: %v %v", hit, at)
	}
}

func TestPrompts(t *testing.T) {
	p := workPrompt("Do X", []string{"a", "b"}, false)
	if !strings.Contains(p, "1. a\n2. b") || !strings.Contains(p, "worktree") || !strings.Contains(p, "`commit`") {
		t.Fatalf("work prompt %q", p)
	}
	if strings.Contains(workPrompt("Do X", nil, true), "worktree") {
		t.Fatal("in-place prompt mentions a worktree")
	}
	f := fixPrompt(CheckRun{Command: "make check", Status: CheckTimeout, OutputTail: "slow"}, 2, 2)
	if !strings.Contains(f, "timed out") || !strings.Contains(f, "2 of 2") || !strings.Contains(f, "slow") {
		t.Fatalf("fix prompt %q", f)
	}
}
