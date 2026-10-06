package providers

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
)

// ModelsFile is the bundled capability table, relative to the shell source.
var ModelsFile = filepath.Join("assets", "ai", "models.json")

// Budget is the thinking-token range of a budget-style model.
type Budget struct {
	Min int `json:"min"`
	Max int `json:"max,omitempty"`
}

// ModelEntry is one row of assets/ai/models.json, matched by id prefix.
// Zero/empty fields mean "unknown", not "none".
type ModelEntry struct {
	Prefix        string            `json:"prefix"`
	ContextWindow int               `json:"contextWindow,omitempty"`
	MaxOutput     int               `json:"maxOutput,omitempty"`
	Vision        *bool             `json:"vision,omitempty"`
	Tools         *bool             `json:"tools,omitempty"`
	Reasoning     string            `json:"reasoning,omitempty"`
	Efforts       []string          `json:"efforts,omitempty"`
	EffortMap     map[string]string `json:"effortMap,omitempty"`
	Budget        *Budget           `json:"budget,omitempty"`
	Note          string            `json:"note,omitempty"`
}

// ModelTable is the parsed models.json.
type ModelTable struct {
	Updated   string                  `json:"updated"`
	Efforts   []string                `json:"efforts"`
	Vendors   map[string]string       `json:"vendors"`
	Providers map[string][]ModelEntry `json:"providers"`
}

// ModelInfo is the result of providers.models.info.
type ModelInfo struct {
	Found    bool   `json:"found"`
	Provider string `json:"provider"`
	Model    string `json:"model"`
	// Source is "table" (models.json), "ollama" (probe cache) or "".
	Source string `json:"source"`
	ModelEntry
	Capabilities []string `json:"capabilities,omitempty"`
	Family       string   `json:"family,omitempty"`
}

// Lookup finds the entry for provider/model: the longest matching prefix
// (case-insensitive) in the provider's table, then in the table of the id's
// vendor ("anthropic/claude-sonnet-4" on OpenRouter), then in the shared
// "open" table of open-weight models served by many hosts. Each table is
// tried with the full id first, then without the "vendor/" part.
func (t *ModelTable) Lookup(provider, model string) (ModelEntry, bool) {
	id := strings.ToLower(strings.TrimSpace(model))
	id = strings.TrimSuffix(id, ":free")
	ids := []string{id}
	tables := []string{provider}
	if vendor, rest, ok := strings.Cut(id, "/"); ok {
		ids = append(ids, rest)
		if target := t.Vendors[vendor]; target != "" {
			tables = append(tables, target)
		}
	}
	tables = append(tables, "open")
	for _, name := range tables {
		for _, candidate := range ids {
			if e, ok := longestPrefix(t.Providers[name], candidate); ok {
				return e, true
			}
		}
	}
	return ModelEntry{}, false
}

func longestPrefix(entries []ModelEntry, id string) (ModelEntry, bool) {
	best, found := ModelEntry{}, false
	for _, e := range entries {
		p := strings.ToLower(e.Prefix)
		if strings.HasPrefix(id, p) && (!found || len(p) > len(best.Prefix)) {
			best, found = e, true
		}
	}
	return best, found
}

// table returns the parsed models.json, reloaded when its mtime changes.
func (s *Service) table() *ModelTable {
	s.tableMu.Lock()
	defer s.tableMu.Unlock()
	path := s.modelsPath()
	st, err := os.Stat(path)
	if err != nil {
		return &ModelTable{}
	}
	if s.tableCache != nil && st.ModTime().Equal(s.tableMtime) {
		return s.tableCache
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return &ModelTable{}
	}
	var t ModelTable
	if json.Unmarshal(data, &t) != nil {
		return &ModelTable{}
	}
	s.tableCache, s.tableMtime = &t, st.ModTime()
	return &t
}

func (s *Service) modelsPath() string {
	if s.modelsFile != "" {
		return s.modelsFile
	}
	return filepath.Join(s.shellDir(), ModelsFile)
}

// ModelInfo answers providers.models.info. Ollama models come from the
// probe cache (no network); everything else from the bundled table.
func (s *Service) ModelInfo(provider, model string) ModelInfo {
	info := ModelInfo{Provider: provider, Model: model}
	if provider == "ollama" {
		if m, ok := s.cachedOllama(model); ok && m.Detailed {
			info.Found, info.Source = true, "ollama"
			info.ContextWindow = m.ContextLength
			info.Capabilities = m.Capabilities
			info.Family = m.Family
			info.Vision = boolPtr(contains(m.Capabilities, "vision"))
			info.Tools = boolPtr(contains(m.Capabilities, "tools"))
			info.Reasoning = "none"
			if contains(m.Capabilities, "thinking") {
				info.Reasoning = "ollama_think"
			}
			return info
		}
	}
	if e, ok := s.table().Lookup(provider, model); ok {
		info.Found, info.Source, info.ModelEntry = true, "table", e
	}
	return info
}

func boolPtr(b bool) *bool { return &b }

func contains(list []string, v string) bool {
	for _, x := range list {
		if x == v {
			return true
		}
	}
	return false
}
