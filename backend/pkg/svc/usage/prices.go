package usage

import (
	"encoding/json"
	"os"
	"strings"
)

// Price is USD per 1M tokens. Cached is the price of cached input tokens
// (0: cached tokens are billed as input).
type Price struct {
	Input  float64 `json:"input"`
	Output float64 `json:"output"`
	Cached float64 `json:"cached,omitempty"`
}

// PriceTable is assets/ai/prices.json, optionally merged with the user's
// override file (same shape).
type PriceTable struct {
	Updated string `json:"updated,omitempty"`
	// Aliases map provider ids to the table that prices them
	// (codex -> openai, claude -> anthropic, google -> gemini).
	Aliases map[string]string `json:"aliases,omitempty"`
	// Free lists providers that cost nothing (local models).
	Free []string `json:"free,omitempty"`
	// Passthrough lists routers whose model ids are "<vendor>/<model>"
	// (OpenRouter): the vendor's table prices them, unknown ones get no
	// estimate.
	Passthrough []string `json:"passthrough,omitempty"`
	// Providers maps provider -> model-id prefix -> price.
	Providers map[string]map[string]Price `json:"providers"`
}

// LoadPrices reads the bundled table and merges the override on top.
// Missing or broken files yield an empty table: costs are then reported
// only when the provider sends them.
func LoadPrices(bundled, override string) *PriceTable {
	t := &PriceTable{}
	var b PriceTable
	if readPrices(bundled, &b) {
		t.Merge(&b) // lower-cases every key
	}
	if override != "" {
		var o PriceTable
		if readPrices(override, &o) {
			t.Merge(&o)
		}
	}
	return t
}

func readPrices(path string, into *PriceTable) bool {
	data, err := os.ReadFile(path)
	if err != nil {
		return false
	}
	return json.Unmarshal(data, into) == nil
}

// Merge overlays o: its models replace or extend t's, its aliases and
// provider lists are added.
func (t *PriceTable) Merge(o *PriceTable) {
	if o.Updated != "" {
		t.Updated = o.Updated
	}
	if t.Providers == nil {
		t.Providers = map[string]map[string]Price{}
	}
	for prov, models := range o.Providers {
		prov = strings.ToLower(prov)
		if t.Providers[prov] == nil {
			t.Providers[prov] = map[string]Price{}
		}
		for id, p := range models {
			t.Providers[prov][strings.ToLower(id)] = p
		}
	}
	if len(o.Aliases) > 0 && t.Aliases == nil {
		t.Aliases = map[string]string{}
	}
	for k, v := range o.Aliases {
		t.Aliases[strings.ToLower(k)] = strings.ToLower(v)
	}
	t.Free = append(t.Free, o.Free...)
	t.Passthrough = append(t.Passthrough, o.Passthrough...)
}

func contains(list []string, s string) bool {
	for _, v := range list {
		if strings.EqualFold(v, s) {
			return true
		}
	}
	return false
}

// Lookup finds the price of model at provider. The longest table key that
// equals the model id or prefixes it at a boundary ("-", ":", "@") wins, so
// "gpt-4o" prices "gpt-4o-2024-08-06" but not "gpt-4o-mini" (its own key)
// nor "gpt-5.5" through "gpt-5".
func (t *PriceTable) Lookup(provider, model string) (Price, bool) {
	if t == nil {
		return Price{}, false
	}
	provider = strings.ToLower(provider)
	model = strings.ToLower(strings.TrimSpace(model))
	if contains(t.Free, provider) {
		return Price{}, true
	}
	if contains(t.Passthrough, provider) {
		vendor, rest, ok := strings.Cut(model, "/")
		if !ok {
			return Price{}, false
		}
		provider, model = vendor, rest
	}
	return t.match(provider, model)
}

func (t *PriceTable) match(provider, model string) (Price, bool) {
	if a, ok := t.Aliases[provider]; ok {
		provider = a
	}
	models := t.Providers[provider]
	best, bestLen := Price{}, -1
	for key, p := range models {
		if len(key) <= bestLen || !prefixAtBoundary(model, key) {
			continue
		}
		best, bestLen = p, len(key)
	}
	return best, bestLen >= 0
}

func prefixAtBoundary(model, key string) bool {
	if !strings.HasPrefix(model, key) {
		return false
	}
	if len(model) == len(key) {
		return true
	}
	switch model[len(key)] {
	case '-', ':', '@':
		return true
	}
	return false
}

// Estimate prices a record's tokens. Cached tokens are part of the input
// count (OpenAI/Anthropic-normalised); they are billed at the cached price
// when the table has one.
func (p Price) Estimate(input, output, cached int64) float64 {
	if cached > input {
		cached = input
	}
	cachedPrice := p.Cached
	if cachedPrice == 0 {
		cachedPrice = p.Input
	}
	usd := float64(input-cached)*p.Input + float64(cached)*cachedPrice + float64(output)*p.Output
	return usd / 1e6
}
