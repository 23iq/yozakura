package providers

import (
	"encoding/json"
	"os"
	"testing"
)

var unifiedLevels = map[string]bool{"off": true, "low": true, "medium": true, "high": true, "max": true}
var reasoningStyles = map[string]bool{"openai_effort": true, "anthropic_budget": true, "gemini_budget": true, "gemini_level": true, "none": true}

// The bundled table must parse and only use known styles and levels.
func TestModelsTableValid(t *testing.T) {
	s := newTestService(t)
	data, err := os.ReadFile(s.modelsPath())
	if err != nil {
		t.Fatal(err)
	}
	var tab ModelTable
	if err := json.Unmarshal(data, &tab); err != nil {
		t.Fatal(err)
	}
	if tab.Updated == "" || len(tab.Providers) == 0 {
		t.Fatal("missing updated/providers")
	}
	for prov, entries := range tab.Providers {
		seen := map[string]bool{}
		for _, e := range entries {
			if e.Prefix == "" || seen[e.Prefix] {
				t.Errorf("%s: empty or duplicate prefix %q", prov, e.Prefix)
			}
			seen[e.Prefix] = true
			if !reasoningStyles[e.Reasoning] {
				t.Errorf("%s/%s: reasoning %q", prov, e.Prefix, e.Reasoning)
			}
			for _, l := range e.Efforts {
				if !unifiedLevels[l] {
					t.Errorf("%s/%s: effort %q", prov, e.Prefix, l)
				}
			}
			for l := range e.EffortMap {
				if !unifiedLevels[l] {
					t.Errorf("%s/%s: effortMap level %q", prov, e.Prefix, l)
				}
			}
			if e.Reasoning != "none" && len(e.Efforts) == 0 {
				t.Errorf("%s/%s: reasoning without efforts", prov, e.Prefix)
			}
		}
	}
	for vendor, target := range tab.Vendors {
		if _, ok := tab.Providers[target]; !ok {
			t.Errorf("vendor %s -> unknown table %s", vendor, target)
		}
	}
}

func TestModelLookup(t *testing.T) {
	s := newTestService(t)
	cases := []struct {
		provider, model, prefix string
	}{
		{"openai", "gpt-5-mini", "gpt-5"},
		{"openai", "gpt-5.2-pro", "gpt-5.2"},
		{"openai", "gpt-5.1", "gpt-5."},
		{"openai", "GPT-4o-2024-08-06", "gpt-4o"},
		{"anthropic", "claude-sonnet-4-5-20250929", "claude-sonnet-4"},
		{"anthropic", "claude-opus-4-5", "claude-opus-4-5"},
		{"anthropic", "claude-future-9", "claude-"},
		{"gemini", "gemini-2.5-flash-lite", "gemini-2.5-flash-lite"},
		{"openrouter", "anthropic/claude-opus-4.1", "claude-opus-4"},
		{"openrouter", "google/gemini-2.5-pro", "gemini-2.5-pro"},
		{"openrouter", "openai/gpt-oss-120b:free", "gpt-oss"},
		{"groq", "openai/gpt-oss-20b", "gpt-oss"},
		{"groq", "qwen/qwen3-32b", "qwen/qwen3-32b"},
		{"minimax", "MiniMax-M2.5", "minimax-m2"},
		{"lmstudio", "gpt-oss-20b", "gpt-oss"},
	}
	for _, c := range cases {
		info := s.ModelInfo(c.provider, c.model)
		if !info.Found || info.Prefix != c.prefix || info.Source != "table" {
			t.Errorf("%s/%s -> %+v (want prefix %q)", c.provider, c.model, info, c.prefix)
		}
	}
	if info := s.ModelInfo("openai", "dall-e-3"); info.Found {
		t.Errorf("unexpected match %+v", info)
	}
	// Ollama models not probed yet fall back to the table.
	if info := s.ModelInfo("ollama", "gpt-oss:20b"); !info.Found || info.Prefix != "gpt-oss" {
		t.Errorf("ollama fallback %+v", info)
	}
}
