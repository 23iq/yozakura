package providers

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"time"
)

// DefaultOllamaEndpoint is where a local Ollama daemon listens by default.
const DefaultOllamaEndpoint = "http://127.0.0.1:11434"

// OllamaModel is one installed model with the capabilities reported by
// /api/show. Nothing here requires loading the model into memory.
type OllamaModel struct {
	ID            string   `json:"id"`
	Name          string   `json:"name"`
	SizeLabel     string   `json:"sizeLabel"`
	DiskSize      int64    `json:"diskSize"`
	Family        string   `json:"family"`
	ContextLength int      `json:"contextLength"`
	Capabilities  []string `json:"capabilities"`
	Quantization  string   `json:"quantization"`
	Digest        string   `json:"digest"`
	// Detailed is false when /api/show failed: capabilities and context
	// length are then unknown (empty / 0), not "none".
	Detailed bool `json:"detailed"`
}

// OllamaProbe is the result of providers.ollama.probe.
type OllamaProbe struct {
	Endpoint  string        `json:"endpoint"`
	Reachable bool          `json:"reachable"`
	Version   string        `json:"version"`
	Error     string        `json:"error,omitempty"`
	Models    []OllamaModel `json:"models"`
}

// NormalizeOllamaEndpoint returns the API root for a configured endpoint:
// default when empty, no trailing slash, no OpenAI-compat "/v1" or "/api"
// suffix. Only http(s) URLs are accepted.
func NormalizeOllamaEndpoint(raw string) (string, error) {
	ep := strings.TrimSpace(raw)
	if ep == "" {
		return DefaultOllamaEndpoint, nil
	}
	if !strings.Contains(ep, "://") {
		ep = "http://" + ep
	}
	u, err := url.Parse(ep)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
		return "", fmt.Errorf("invalid endpoint %q", raw)
	}
	ep = strings.TrimRight(u.Scheme+"://"+u.Host+u.Path, "/")
	for _, suffix := range []string{"/v1", "/api"} {
		ep = strings.TrimSuffix(ep, suffix)
	}
	return ep, nil
}

type ollamaTag struct {
	Name    string `json:"name"`
	Model   string `json:"model"`
	Size    int64  `json:"size"`
	Digest  string `json:"digest"`
	Details struct {
		Family            string `json:"family"`
		ParameterSize     string `json:"parameter_size"`
		QuantizationLevel string `json:"quantization_level"`
	} `json:"details"`
}

type ollamaShow struct {
	Capabilities []string       `json:"capabilities"`
	ModelInfo    map[string]any `json:"model_info"`
	Details      struct {
		Family            string `json:"family"`
		ParameterSize     string `json:"parameter_size"`
		QuantizationLevel string `json:"quantization_level"`
	} `json:"details"`
}

// ProbeOllama lists the models of the daemon at endpoint. It calls
// /api/version and /api/tags, then /api/show only for models whose digest
// is not cached yet. /api/show reads metadata; it never loads a model.
func (s *Service) ProbeOllama(ctx context.Context, rawEndpoint string) OllamaProbe {
	ep, err := NormalizeOllamaEndpoint(rawEndpoint)
	if err != nil {
		return OllamaProbe{Endpoint: rawEndpoint, Error: err.Error(), Models: []OllamaModel{}}
	}
	res := OllamaProbe{Endpoint: ep, Models: []OllamaModel{}}

	var tags struct {
		Models []ollamaTag `json:"models"`
	}
	// A short timeout for the reachability check: the picker re-probes
	// when it opens and must not hang on a dead remote endpoint.
	tagsCtx, cancel := probeContext(ctx, 5*time.Second)
	defer cancel()
	if err := s.getJSON(tagsCtx, ep+"/api/tags", nil, &tags); err != nil {
		res.Error = err.Error()
		return res
	}
	res.Reachable = true
	var ver struct {
		Version string `json:"version"`
	}
	if s.getJSON(tagsCtx, ep+"/api/version", nil, &ver) == nil {
		res.Version = ver.Version
	}

	s.ollamaMu.Lock()
	defer s.ollamaMu.Unlock()
	cache := s.loadOllamaCache()
	changed := false
	keep := map[string]bool{}
	for _, t := range tags.Models {
		id := t.Name
		if id == "" {
			id = t.Model
		}
		if id == "" {
			continue
		}
		key := cacheKey(ep, id)
		keep[key] = true
		if hit, ok := cache.Entries[key]; ok && hit.Digest == t.Digest && hit.Detailed {
			hit.DiskSize = t.Size
			res.Models = append(res.Models, hit)
			continue
		}
		m := modelFromTag(id, t)
		var show ollamaShow
		body, _ := json.Marshal(map[string]string{"model": id})
		if err := s.postJSON(ctx, ep+"/api/show", body, &show); err == nil {
			applyShow(&m, show)
			cache.Entries[key] = m
			changed = true
		}
		res.Models = append(res.Models, m)
	}
	prefix := ep + "|"
	for key := range cache.Entries {
		if strings.HasPrefix(key, prefix) && !keep[key] {
			delete(cache.Entries, key)
			changed = true
		}
	}
	if changed {
		s.saveOllamaCache(cache)
	}
	sort.Slice(res.Models, func(i, j int) bool { return res.Models[i].ID < res.Models[j].ID })
	return res
}

func modelFromTag(id string, t ollamaTag) OllamaModel {
	return OllamaModel{
		ID:           id,
		Name:         id,
		SizeLabel:    t.Details.ParameterSize,
		DiskSize:     t.Size,
		Family:       t.Details.Family,
		Quantization: t.Details.QuantizationLevel,
		Digest:       t.Digest,
		Capabilities: []string{},
	}
}

// knownCaps is the canonical order of the capabilities we report.
var knownCaps = []string{"completion", "tools", "vision", "thinking", "insert", "embedding"}

func applyShow(m *OllamaModel, show ollamaShow) {
	m.Detailed = true
	for _, c := range knownCaps {
		if contains(show.Capabilities, c) {
			m.Capabilities = append(m.Capabilities, c)
		}
	}
	if show.Details.Family != "" {
		m.Family = show.Details.Family
	}
	if m.SizeLabel == "" {
		m.SizeLabel = show.Details.ParameterSize
	}
	if m.Quantization == "" {
		m.Quantization = show.Details.QuantizationLevel
	}
	m.ContextLength = contextLength(show.ModelInfo)
}

// contextLength reads "<arch>.context_length" from model_info, preferring
// the key of general.architecture when several are present.
func contextLength(info map[string]any) int {
	if arch, _ := info["general.architecture"].(string); arch != "" {
		if v, ok := info[arch+".context_length"].(float64); ok {
			return int(v)
		}
	}
	best := 0
	for k, v := range info {
		if f, ok := v.(float64); ok && strings.HasSuffix(k, ".context_length") && int(f) > best {
			best = int(f)
		}
	}
	return best
}

// cachedOllama returns the cached info for a model on any endpoint (the
// default endpoint first), without network access.
func (s *Service) cachedOllama(model string) (OllamaModel, bool) {
	s.ollamaMu.Lock()
	defer s.ollamaMu.Unlock()
	cache := s.loadOllamaCache()
	if m, ok := cache.Entries[cacheKey(DefaultOllamaEndpoint, model)]; ok {
		return m, true
	}
	keys := make([]string, 0, len(cache.Entries))
	for k := range cache.Entries {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		if strings.HasSuffix(k, "|"+model) {
			return cache.Entries[k], true
		}
	}
	return OllamaModel{}, false
}

func (s *Service) postJSON(ctx context.Context, u string, body []byte, out any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, u, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	return s.doJSON(req, out, "")
}

func (s *Service) getJSON(ctx context.Context, u string, headers map[string]string, out any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return err
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	return s.doJSON(req, out, "")
}

// doJSON performs req and decodes a 2xx JSON body into out. secret is
// scrubbed from any error text.
func (s *Service) doJSON(req *http.Request, out any, secret string) error {
	resp, err := s.client.Do(req)
	if err != nil {
		return errors.New(scrub(simplifyNetErr(err), secret))
	}
	defer resp.Body.Close()
	data, err := readLimited(resp.Body)
	if err != nil {
		return err
	}
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		return errors.New(scrub(httpError(resp.StatusCode, data), secret))
	}
	if err := json.Unmarshal(data, out); err != nil {
		return fmt.Errorf("unexpected response: %v", err)
	}
	return nil
}

func probeContext(parent context.Context, d time.Duration) (context.Context, context.CancelFunc) {
	if parent == nil {
		parent = context.Background()
	}
	return context.WithTimeout(parent, d)
}
