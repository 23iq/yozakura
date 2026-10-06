package usage

import (
	"os"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/stretchr/testify/assert"
)

func bundledPrices(t *testing.T) *PriceTable {
	_, file, _, _ := runtime.Caller(0)
	root := filepath.Join(filepath.Dir(file), "..", "..", "..", "..")
	path := BundledPricesPath(root)
	_, err := os.Stat(path)
	require.NoError(t, err, "bundled price table")
	return LoadPrices(path, "")
}

func TestBundledPriceTable(t *testing.T) {
	p := bundledPrices(t)
	assert.NotEmpty(t, p.Updated)
	for _, prov := range []string{"openai", "anthropic", "gemini", "mistral", "groq", "deepseek", "minimax"} {
		assert.NotEmpty(t, p.Providers[prov], prov)
		for id, price := range p.Providers[prov] {
			assert.Greater(t, price.Input, 0.0, id)
			assert.Greater(t, price.Output, 0.0, id)
		}
	}
}

func TestPriceLookup(t *testing.T) {
	p := bundledPrices(t)
	cases := []struct {
		provider, model string
		ok              bool
		input           float64
	}{
		{"openai", "gpt-4o", true, 2.5},
		{"openai", "gpt-4o-2024-08-06", true, 2.5}, // dated snapshot
		{"openai", "gpt-4o-mini", true, 0.15},      // longer key wins
		{"openai", "GPT-4o-Mini-2024-07-18", true, 0.15},
		{"openai", "gpt-5.5", false, 0}, // "gpt-5" must not price a new generation
		{"openai", "gpt-4", false, 0},
		{"codex", "gpt-5-codex", true, 1.25}, // alias + prefix
		{"anthropic", "claude-opus-5-5", true, 4},
		{"claude", "claude-sonnet-4-5-20250929", true, 3},
		{"anthropic", "claude-opus-5", true, 5},
		{"gemini", "gemini-2.5-flash-lite", true, 0.1},
		{"minimax", "MiniMax-M2", true, 0.3},
		{"groq", "openai/gpt-oss-120b", true, 0.15},
		{"openrouter", "openai/gpt-4o", true, 2.5}, // passthrough to the vendor table
		{"openrouter", "google/gemini-2.5-pro", true, 1.25},
		{"openrouter", "meta-llama/llama-4", false, 0},
		{"openrouter", "gpt-4o", false, 0},
		{"custom", "gpt-4o", false, 0},
		{"ollama", "llama3.2", true, 0}, // local: free
		{"lmstudio", "anything", true, 0},
	}
	for _, c := range cases {
		got, ok := p.Lookup(c.provider, c.model)
		assert.Equal(t, c.ok, ok, "%s/%s", c.provider, c.model)
		assert.Equal(t, c.input, got.Input, "%s/%s", c.provider, c.model)
	}
	var nilTable *PriceTable
	_, ok := nilTable.Lookup("openai", "gpt-4o")
	assert.False(t, ok)
}

func TestPriceEstimate(t *testing.T) {
	p := Price{Input: 2, Output: 10, Cached: 0.5}
	// 1M input of which 400k cached, 100k output.
	assert.InDelta(t, 0.6*2+0.4*0.5+0.1*10, p.Estimate(1_000_000, 100_000, 400_000), 1e-9)
	// No cached price: cached tokens cost full input.
	assert.InDelta(t, 2.0, Price{Input: 2}.Estimate(1_000_000, 0, 500_000), 1e-9)
	// Cached never exceeds input.
	assert.InDelta(t, 0.5, p.Estimate(1_000_000, 0, 2_000_000), 1e-9)
}

func TestPriceOverrideMerge(t *testing.T) {
	dir := t.TempDir()
	bundled := filepath.Join(dir, "prices.json")
	override := filepath.Join(dir, "ai-prices.json")
	require.NoError(t, os.WriteFile(bundled, []byte(`{"updated":"2026-10-06","providers":{"openai":{"gpt-4o":{"input":2.5,"output":10}}}}`), 0o600))
	require.NoError(t, os.WriteFile(override, []byte(`{"aliases":{"work":"openai"},"free":["myllm"],"providers":{"OpenAI":{"GPT-4o":{"input":1,"output":2}},"acme":{"rocket":{"input":3,"output":4}}}}`), 0o600))
	p := LoadPrices(bundled, override)
	got, ok := p.Lookup("openai", "gpt-4o")
	require.True(t, ok)
	assert.Equal(t, 1.0, got.Input)
	got, ok = p.Lookup("work", "gpt-4o")
	require.True(t, ok)
	assert.Equal(t, 2.0, got.Output)
	_, ok = p.Lookup("acme", "rocket-2")
	assert.True(t, ok)
	got, ok = p.Lookup("myllm", "x")
	assert.True(t, ok)
	assert.Equal(t, 0.0, got.Input)

	// Missing or broken files: empty table, no panic.
	require.NoError(t, os.WriteFile(override, []byte(`{broken`), 0o600))
	p = LoadPrices(filepath.Join(dir, "missing.json"), override)
	_, ok = p.Lookup("openai", "gpt-4o")
	assert.False(t, ok)
}
