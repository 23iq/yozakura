package providers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"sort"
	"strings"
)

// Listing families: how a provider lists its models.
const (
	famOpenAI     = "openai"
	famAnthropic  = "anthropic"
	famGemini     = "gemini"
	famOllama     = "ollama"
	famOpenRouter = "openrouter"
	famNoListing  = "none"
)

// preset is the backend's view of a provider preset (the full presets with
// labels and icons live in modules/services/ai/ProviderPresets.js).
type preset struct {
	family string
	base   string
	bearer bool // anthropic family with "Authorization: Bearer"
}

var presets = map[string]preset{
	"openai":     {family: famOpenAI, base: "https://api.openai.com/v1"},
	"anthropic":  {family: famAnthropic, base: "https://api.anthropic.com/v1"},
	"gemini":     {family: famGemini, base: "https://generativelanguage.googleapis.com/v1beta"},
	"mistral":    {family: famOpenAI, base: "https://api.mistral.ai/v1"},
	"groq":       {family: famOpenAI, base: "https://api.groq.com/openai/v1"},
	"deepseek":   {family: famOpenAI, base: "https://api.deepseek.com/v1"},
	"openrouter": {family: famOpenRouter, base: "https://openrouter.ai/api/v1"},
	"lmstudio":   {family: famOpenAI, base: "http://127.0.0.1:1234/v1"},
	"ollama":     {family: famOllama, base: DefaultOllamaEndpoint},
	"custom":     {family: famOpenAI},
	// MiniMax's Anthropic-compatible API has no model listing endpoint.
	"minimax": {family: famNoListing, base: "https://api.minimax.io/anthropic/v1", bearer: true},
}

// ListedModel is one entry of a provider's model list.
type ListedModel struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

// TestResult is the result of providers.test. Verified is false when the
// provider cannot be checked without a paid request (OK is then true and
// the key is only checked on the first real chat).
type TestResult struct {
	OK       bool          `json:"ok"`
	Verified bool          `json:"verified"`
	Error    string        `json:"error"`
	Models   []ListedModel `json:"models"`
}

// TestConnection lists the models of a provider with the given key and base
// URL (both optional; the preset base is used when baseURL is empty). It
// only performs free GET listing requests; the key is never logged and is
// scrubbed from error texts.
func (s *Service) TestConnection(ctx context.Context, provider, baseURL, key string) TestResult {
	res := TestResult{Models: []ListedModel{}}
	p, known := presets[provider]
	if !known {
		p = presets["custom"]
	}
	base := strings.TrimRight(strings.TrimSpace(baseURL), "/")
	if base == "" {
		base = p.base
	}
	if base == "" {
		res.Error = "base URL required"
		return res
	}
	if u, err := url.Parse(base); err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
		res.Error = "invalid base URL"
		return res
	}
	if p.family == famNoListing {
		res.OK = key != ""
		if !res.OK {
			res.Error = "API key required"
		}
		return res
	}
	if p.family == famOllama {
		probe := s.ProbeOllama(ctx, base)
		if !probe.Reachable {
			res.Error = probe.Error
			return res
		}
		res.OK, res.Verified = true, true
		for _, m := range probe.Models {
			res.Models = append(res.Models, ListedModel{ID: m.ID, Name: m.Name})
		}
		return res
	}
	models, err := s.listModels(ctx, p, base, key)
	if err != nil {
		res.Error = scrub(err.Error(), key)
		return res
	}
	res.OK, res.Verified, res.Models = true, true, models
	return res
}

func (s *Service) listModels(ctx context.Context, p preset, base, key string) ([]ListedModel, error) {
	h := map[string]string{}
	var u string
	switch p.family {
	case famAnthropic:
		if !strings.HasSuffix(base, "/v1") {
			base += "/v1"
		}
		u = base + "/models?limit=1000"
		h["anthropic-version"] = "2023-06-01"
		if p.bearer {
			h["Authorization"] = "Bearer " + key
		} else {
			h["x-api-key"] = key
		}
	case famGemini:
		u = base + "/models?pageSize=1000"
		h["x-goog-api-key"] = key
	case famOpenRouter:
		// /models is public; /key checks the key itself (free, no tokens).
		if key == "" {
			return nil, errors.New("API key required")
		}
		var info map[string]any
		if err := s.getSecret(ctx, base+"/key", map[string]string{"Authorization": "Bearer " + key}, key, &info); err != nil {
			return nil, err
		}
		u = base + "/models"
		h["Authorization"] = "Bearer " + key
	default:
		u = base + "/models"
		if key != "" {
			h["Authorization"] = "Bearer " + key
		}
	}
	var raw json.RawMessage
	if err := s.getSecret(ctx, u, h, key, &raw); err != nil {
		return nil, err
	}
	return parseListing(p.family, raw)
}

func (s *Service) getSecret(ctx context.Context, u string, headers map[string]string, secret string, out any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return errors.New("invalid URL")
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	return s.doJSON(req, out, secret)
}

func parseListing(family string, raw json.RawMessage) ([]ListedModel, error) {
	var doc struct {
		Data []struct {
			ID          string `json:"id"`
			Name        string `json:"name"`
			DisplayName string `json:"display_name"`
		} `json:"data"`
		Models []struct {
			Name        string `json:"name"`
			DisplayName string `json:"displayName"`
		} `json:"models"`
	}
	if err := json.Unmarshal(raw, &doc); err != nil {
		return nil, fmt.Errorf("unexpected response: %v", err)
	}
	out := []ListedModel{}
	if family == famGemini {
		for _, m := range doc.Models {
			id := strings.TrimPrefix(m.Name, "models/")
			if id != "" {
				out = append(out, ListedModel{ID: id, Name: firstNonEmpty(m.DisplayName, id)})
			}
		}
	} else {
		for _, m := range doc.Data {
			if m.ID != "" {
				out = append(out, ListedModel{ID: m.ID, Name: firstNonEmpty(m.DisplayName, m.Name, m.ID)})
			}
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}

const maxBody = 8 << 20

func readLimited(r io.Reader) ([]byte, error) {
	data, err := io.ReadAll(io.LimitReader(r, maxBody+1))
	if err != nil {
		return nil, err
	}
	if len(data) > maxBody {
		return nil, errors.New("response too large")
	}
	return data, nil
}

// httpError turns an error response into a short message, preferring the
// provider's own error text.
func httpError(status int, body []byte) string {
	var doc map[string]any
	msg := ""
	if json.Unmarshal(body, &doc) == nil {
		switch e := doc["error"].(type) {
		case string:
			msg = e
		case map[string]any:
			msg, _ = e["message"].(string)
		}
		if msg == "" {
			msg, _ = doc["message"].(string)
		}
	}
	if msg == "" {
		msg = http.StatusText(status)
	}
	if len(msg) > 300 {
		msg = msg[:300] + "…"
	}
	return fmt.Sprintf("HTTP %d: %s", status, msg)
}

// simplifyNetErr drops the URL from transport errors ("connection
// refused" is what the user needs to read).
func simplifyNetErr(err error) string {
	var ue *url.Error
	if errors.As(err, &ue) {
		err = ue.Err
	}
	var op *net.OpError
	if errors.As(err, &op) && op.Err != nil {
		return op.Err.Error()
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return "timed out"
	}
	return err.Error()
}

// scrub removes secret from text (providers sometimes echo a bad key).
func scrub(text, secret string) string {
	if len(secret) < 4 {
		return text
	}
	return strings.ReplaceAll(text, secret, "***")
}
