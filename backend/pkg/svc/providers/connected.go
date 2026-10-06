package providers

import (
	"context"
	"encoding/json"
	"os"
	"sort"
	"strings"
	"sync"
	"time"
)

// Credential is one provider with a stored key or endpoint (the keystore).
type Credential struct {
	Provider string
	Key      string
	Endpoint string
}

// Connected is one entry of providers.list: a provider with a stored
// credential, or a local server (Ollama, LM Studio). It never carries the
// key.
type Connected struct {
	Provider string        `json:"provider"`
	Local    bool          `json:"local"`  // no key needed (local server)
	Stored   bool          `json:"stored"` // a key or endpoint is saved
	Endpoint string        `json:"endpoint,omitempty"`
	OK       bool          `json:"ok"`
	Verified bool          `json:"verified"`
	Error    string        `json:"error,omitempty"`
	Models   []ListedModel `json:"models"`
}

var localProviders = []string{"ollama", "lmstudio"}

// SetCredentials gives the service read access to the stored credentials
// (the daemon wires the keystore here).
func (s *Service) SetCredentials(f func() []Credential) { s.credentials = f }

// ListConnected tests every provider with a stored credential plus the
// local servers, concurrently, with free model-listing requests only.
// only != "" limits it to that provider (tested even without a credential).
func (s *Service) ListConnected(ctx context.Context, only string) []Connected {
	creds := map[string]Credential{}
	if s.credentials != nil {
		for _, c := range s.credentials() {
			if c.Provider != "" {
				creds[c.Provider] = c
			}
		}
	}
	names := map[string]bool{}
	for p := range creds {
		names[p] = true
	}
	for _, p := range localProviders {
		names[p] = true
	}
	if only != "" {
		names = map[string]bool{only: true}
	}
	out := make([]Connected, 0, len(names))
	var mu sync.Mutex
	var wg sync.WaitGroup
	local := s.localEndpoints()
	for p := range names {
		wg.Add(1)
		go func(p string) {
			defer wg.Done()
			c, stored := creds[p]
			if c.Endpoint == "" {
				c.Endpoint = local[p]
			}
			r := s.TestConnection(ctx, p, c.Endpoint, c.Key)
			e := Connected{Provider: p, Stored: stored, Endpoint: c.Endpoint, OK: r.OK, Verified: r.Verified,
				Error: r.Error, Models: r.Models}
			for _, l := range localProviders {
				e.Local = e.Local || l == p
			}
			mu.Lock()
			out = append(out, e)
			mu.Unlock()
		}(p)
	}
	wg.Wait()
	sort.Slice(out, func(i, j int) bool { return out[i].Provider < out[j].Provider })
	return out
}

// localEndpoints reads ai.ollama.endpoint / ai.lmstudio.endpoint from the
// live ai config ("" = the preset default).
func (s *Service) localEndpoints() map[string]string {
	out := map[string]string{}
	if s.configFile == "" {
		return out
	}
	data, err := os.ReadFile(s.configFile)
	if err != nil {
		return out
	}
	var cfg map[string]json.RawMessage
	if json.Unmarshal(data, &cfg) != nil {
		return out
	}
	for _, p := range localProviders {
		var v struct {
			Endpoint string `json:"endpoint"`
		}
		if json.Unmarshal(cfg[p], &v) == nil && strings.TrimSpace(v.Endpoint) != "" {
			out[p] = strings.TrimSpace(v.Endpoint)
		}
	}
	return out
}

func (s *Service) handleList(params json.RawMessage) (any, error) {
	var p struct {
		Provider string `json:"provider"`
	}
	_ = json.Unmarshal(params, &p)
	ctx, cancel := probeContext(context.Background(), 25*time.Second)
	defer cancel()
	return map[string]any{"providers": s.ListConnected(ctx, p.Provider)}, nil
}
