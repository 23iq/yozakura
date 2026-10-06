// Package providers owns what the AI center needs to know about chat
// providers without chatting: probing a local Ollama daemon (installed
// models and their real capabilities, cached per digest), connection tests
// that list a provider's models with a key, and the bundled model
// capability table (assets/ai/models.json). It never sends a prompt and
// never loads a model. See docs/superpowers/plans/2026-10-06-C1-providers-backend.md.
package providers

import (
	"context"
	"encoding/json"
	"net/http"
	"sync"
	"time"

	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/paths"
)

// Service is the "providers" IPC service.
type Service struct {
	client   *http.Client
	cacheDir string

	// modelsFile overrides the models.json path (tests).
	modelsFile string
	shellDir   func() string

	ollamaMu sync.Mutex

	credentials func() []Credential // stored keys (SetCredentials)
	configFile  string              // live ai config (local endpoints)

	tableMu    sync.Mutex
	tableCache *ModelTable
	tableMtime time.Time
}

// NewService uses p.CacheDir for the Ollama capability cache.
func NewService(p *paths.Paths) *Service {
	return &Service{
		client:     &http.Client{Timeout: 20 * time.Second},
		cacheDir:   p.CacheDir,
		shellDir:   paths.FindShellSource,
		configFile: p.Config("ai"),
	}
}

// Register exposes providers.ollama.probe, providers.test,
// providers.models.info and providers.list (connected providers).
func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "providers",
		Methods: map[string]ipc.HandlerFunc{
			"ollama.probe": s.handleProbe,
			"test":         s.handleTest,
			"models.info":  s.handleInfo,
			"list":         s.handleList,
		},
		Async: map[string]bool{"ollama.probe": true, "test": true, "list": true},
	})
}

func (s *Service) handleProbe(params json.RawMessage) (any, error) {
	var p struct {
		Endpoint string `json:"endpoint"`
	}
	_ = json.Unmarshal(params, &p)
	if p.Endpoint == "" {
		p.Endpoint = s.localEndpoints()["ollama"] // the user's setting
	}
	ctx, cancel := probeContext(context.Background(), 30*time.Second)
	defer cancel()
	return s.ProbeOllama(ctx, p.Endpoint), nil
}

func (s *Service) handleTest(params json.RawMessage) (any, error) {
	var p struct {
		Provider string            `json:"provider"`
		BaseURL  string            `json:"baseUrl"`
		Key      string            `json:"key"`
		Headers  map[string]string `json:"headers"`
	}
	_ = json.Unmarshal(params, &p)
	ctx, cancel := probeContext(context.Background(), 20*time.Second)
	defer cancel()
	return s.TestConnectionWithHeaders(ctx, p.Provider, p.BaseURL, p.Key, p.Headers), nil
}

func (s *Service) handleInfo(params json.RawMessage) (any, error) {
	var p struct {
		Provider string `json:"provider"`
		Model    string `json:"model"`
	}
	_ = json.Unmarshal(params, &p)
	return s.ModelInfo(p.Provider, p.Model), nil
}
