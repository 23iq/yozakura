package providers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
)

func newTestService(t *testing.T) *Service {
	t.Helper()
	s := &Service{client: http.DefaultClient, cacheDir: t.TempDir()}
	s.modelsFile = filepath.Join("..", "..", "..", "..", ModelsFile)
	return s
}

// fakeOllama serves /api/tags, /api/version and /api/show and counts the
// /api/show calls per model. Any other path fails the test (in particular
// /api/generate and /api/chat, which would load a model).
type fakeOllama struct {
	mu     sync.Mutex
	shows  map[string]int
	digest map[string]string
	t      *testing.T
}

func (f *fakeOllama) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	switch r.URL.Path {
	case "/api/version":
		_, _ = w.Write([]byte(`{"version":"0.12.3"}`))
	case "/api/tags":
		type det struct {
			Family string `json:"family"`
			PS     string `json:"parameter_size"`
			Q      string `json:"quantization_level"`
		}
		type tag struct {
			Name    string `json:"name"`
			Size    int64  `json:"size"`
			Digest  string `json:"digest"`
			Details det    `json:"details"`
		}
		out := struct {
			Models []tag `json:"models"`
		}{}
		for name, dg := range f.digest {
			out.Models = append(out.Models, tag{Name: name, Size: 42, Digest: dg, Details: det{Family: "qwen3", PS: "8.2B", Q: "Q4_K_M"}})
		}
		_ = json.NewEncoder(w).Encode(out)
	case "/api/show":
		if r.Method != http.MethodPost {
			f.t.Errorf("/api/show with %s", r.Method)
		}
		var req struct {
			Model string `json:"model"`
		}
		_ = json.NewDecoder(r.Body).Decode(&req)
		f.shows[req.Model]++
		if req.Model == "broken:latest" {
			http.Error(w, `{"error":"boom"}`, http.StatusInternalServerError)
			return
		}
		caps := `["completion","tools","thinking"]`
		if strings.HasPrefix(req.Model, "llava") {
			caps = `["completion","vision"]`
		}
		_, _ = w.Write([]byte(`{"capabilities":` + caps + `,"details":{"family":"qwen3"},"model_info":{"general.architecture":"qwen3","qwen3.context_length":40960,"other.context_length":8}}`))
	default:
		f.t.Errorf("unexpected Ollama call %s %s", r.Method, r.URL.Path)
		http.NotFound(w, r)
	}
}

func TestProbeOllamaCachesByDigest(t *testing.T) {
	fake := &fakeOllama{t: t, shows: map[string]int{}, digest: map[string]string{"qwen3:8b": "d1", "llava:7b": "d2"}}
	srv := httptest.NewServer(fake)
	defer srv.Close()
	s := newTestService(t)

	res := s.ProbeOllama(context.Background(), srv.URL+"/v1/")
	if !res.Reachable || res.Version != "0.12.3" || res.Endpoint != srv.URL {
		t.Fatalf("probe = %+v", res)
	}
	if len(res.Models) != 2 || res.Models[0].ID != "llava:7b" || res.Models[1].ID != "qwen3:8b" {
		t.Fatalf("models = %+v", res.Models)
	}
	q := res.Models[1]
	if q.ContextLength != 40960 || q.SizeLabel != "8.2B" || q.Quantization != "Q4_K_M" || q.Family != "qwen3" || !q.Detailed {
		t.Fatalf("qwen = %+v", q)
	}
	if strings.Join(q.Capabilities, ",") != "completion,tools,thinking" {
		t.Fatalf("caps = %v", q.Capabilities)
	}

	// Second probe: everything cached, no /api/show.
	s.ProbeOllama(context.Background(), srv.URL)
	if fake.shows["qwen3:8b"] != 1 || fake.shows["llava:7b"] != 1 {
		t.Fatalf("show calls = %v", fake.shows)
	}

	// New digest (model re-pulled) and a removed model.
	fake.mu.Lock()
	fake.digest = map[string]string{"qwen3:8b": "d3"}
	fake.mu.Unlock()
	res = s.ProbeOllama(context.Background(), srv.URL)
	if fake.shows["qwen3:8b"] != 2 || len(res.Models) != 1 {
		t.Fatalf("after re-pull: shows=%v models=%v", fake.shows, res.Models)
	}
	cache := s.loadOllamaCache()
	if _, ok := cache.Entries[cacheKey(srv.URL, "llava:7b")]; ok {
		t.Fatal("removed model still cached")
	}
	data, err := os.ReadFile(filepath.Join(s.cacheDir, "ollama-models.json"))
	if err != nil || !strings.Contains(string(data), `"d3"`) {
		t.Fatalf("cache file: %v %s", err, data)
	}
}

func TestProbeOllamaShowFailureNotCached(t *testing.T) {
	fake := &fakeOllama{t: t, shows: map[string]int{}, digest: map[string]string{"broken:latest": "x"}}
	srv := httptest.NewServer(fake)
	defer srv.Close()
	s := newTestService(t)
	for i := 0; i < 2; i++ {
		res := s.ProbeOllama(context.Background(), srv.URL)
		if len(res.Models) != 1 || res.Models[0].Detailed || res.Models[0].SizeLabel != "8.2B" {
			t.Fatalf("models = %+v", res.Models)
		}
	}
	if fake.shows["broken:latest"] != 2 {
		t.Fatalf("failed show should be retried, calls=%d", fake.shows["broken:latest"])
	}
}

func TestProbeOllamaUnreachable(t *testing.T) {
	srv := httptest.NewServer(http.NotFoundHandler())
	url := srv.URL
	srv.Close()
	s := newTestService(t)
	res := s.ProbeOllama(context.Background(), url)
	if res.Reachable || res.Error == "" || res.Models == nil {
		t.Fatalf("probe = %+v", res)
	}
	if bad := s.ProbeOllama(context.Background(), "ftp://x"); bad.Error == "" {
		t.Fatal("ftp endpoint accepted")
	}
}

func TestNormalizeOllamaEndpoint(t *testing.T) {
	cases := map[string]string{
		"":                           DefaultOllamaEndpoint,
		"localhost:11434":            "http://localhost:11434",
		"http://box:11434/":          "http://box:11434",
		"http://box:11434/v1":        "http://box:11434",
		"https://ai.example/ollama/": "https://ai.example/ollama",
	}
	for in, want := range cases {
		got, err := NormalizeOllamaEndpoint(in)
		if err != nil || got != want {
			t.Errorf("%q -> %q, %v (want %q)", in, got, err, want)
		}
	}
}

func TestModelInfoFromOllamaCache(t *testing.T) {
	fake := &fakeOllama{t: t, shows: map[string]int{}, digest: map[string]string{"qwen3:8b": "d1"}}
	srv := httptest.NewServer(fake)
	defer srv.Close()
	s := newTestService(t)
	s.ProbeOllama(context.Background(), srv.URL)
	info := s.ModelInfo("ollama", "qwen3:8b")
	if !info.Found || info.Source != "ollama" || info.ContextWindow != 40960 || info.Reasoning != "ollama_think" || !*info.Tools || *info.Vision {
		t.Fatalf("info = %+v", info)
	}
}
