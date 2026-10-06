package providers

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

const secretKey = "sk-test-SECRET-1234"

func TestTestConnectionOpenAICompatible(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/models" || r.Header.Get("Authorization") != "Bearer "+secretKey {
			http.Error(w, `{"error":{"message":"Incorrect API key provided: `+r.Header.Get("Authorization")+`"}}`, http.StatusUnauthorized)
			return
		}
		_, _ = w.Write([]byte(`{"data":[{"id":"gpt-5"},{"id":"gpt-4o","display_name":"GPT-4o"}]}`))
	}))
	defer srv.Close()
	s := newTestService(t)

	res := s.TestConnection(context.Background(), "openai", srv.URL+"/v1/", secretKey)
	if !res.OK || !res.Verified || len(res.Models) != 2 || res.Models[0].Name != "GPT-4o" || res.Models[1].ID != "gpt-5" {
		t.Fatalf("res = %+v", res)
	}

	bad := s.TestConnection(context.Background(), "custom", srv.URL+"/v1", "sk-wrong-key-999")
	if bad.OK || !strings.Contains(bad.Error, "HTTP 401") || strings.Contains(bad.Error, "sk-wrong-key-999") {
		t.Fatalf("bad = %+v", bad)
	}
}

func TestTestConnectionAnthropic(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/models" || r.Header.Get("x-api-key") != secretKey || r.Header.Get("anthropic-version") == "" {
			http.Error(w, `{"type":"error","error":{"message":"invalid x-api-key"}}`, http.StatusUnauthorized)
			return
		}
		_, _ = w.Write([]byte(`{"data":[{"id":"claude-sonnet-4-5","display_name":"Claude Sonnet 4.5"}]}`))
	}))
	defer srv.Close()
	s := newTestService(t)
	// Base without /v1: it is added for the Anthropic family.
	res := s.TestConnection(context.Background(), "anthropic", srv.URL, secretKey)
	if !res.OK || len(res.Models) != 1 || res.Models[0].Name != "Claude Sonnet 4.5" {
		t.Fatalf("res = %+v", res)
	}
}

func TestTestConnectionGemini(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1beta/models" || r.Header.Get("x-goog-api-key") != secretKey || r.URL.Query().Get("key") != "" {
			http.Error(w, `{"error":{"message":"API key not valid"}}`, http.StatusBadRequest)
			return
		}
		_, _ = w.Write([]byte(`{"models":[{"name":"models/gemini-2.5-pro","displayName":"Gemini 2.5 Pro"}]}`))
	}))
	defer srv.Close()
	s := newTestService(t)
	res := s.TestConnection(context.Background(), "gemini", srv.URL+"/v1beta", secretKey)
	if !res.OK || len(res.Models) != 1 || res.Models[0].ID != "gemini-2.5-pro" {
		t.Fatalf("res = %+v", res)
	}
	bad := s.TestConnection(context.Background(), "gemini", srv.URL+"/v1beta", "nope-nope")
	if bad.OK || !strings.Contains(bad.Error, "API key not valid") {
		t.Fatalf("bad = %+v", bad)
	}
}

func TestTestConnectionOpenRouterChecksKey(t *testing.T) {
	keyCalls := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/v1/key":
			keyCalls++
			if r.Header.Get("Authorization") != "Bearer "+secretKey {
				http.Error(w, `{"error":{"message":"No auth credentials found"}}`, http.StatusUnauthorized)
				return
			}
			_, _ = w.Write([]byte(`{"data":{"label":"x"}}`))
		case "/api/v1/models":
			_, _ = w.Write([]byte(`{"data":[{"id":"anthropic/claude-sonnet-4","name":"Anthropic: Claude Sonnet 4"}]}`))
		default:
			http.NotFound(w, r)
		}
	}))
	defer srv.Close()
	s := newTestService(t)
	res := s.TestConnection(context.Background(), "openrouter", srv.URL+"/api/v1", secretKey)
	if !res.OK || len(res.Models) != 1 || res.Models[0].Name != "Anthropic: Claude Sonnet 4" {
		t.Fatalf("res = %+v", res)
	}
	bad := s.TestConnection(context.Background(), "openrouter", srv.URL+"/api/v1", "wrong-key")
	if bad.OK || keyCalls != 2 {
		t.Fatalf("bad = %+v calls=%d", bad, keyCalls)
	}
	if none := s.TestConnection(context.Background(), "openrouter", srv.URL+"/api/v1", ""); none.OK {
		t.Fatal("empty OpenRouter key accepted")
	}
}

func TestTestConnectionLocalAndUnlisted(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "" {
			t.Error("keyless provider sent an Authorization header")
		}
		_, _ = w.Write([]byte(`{"data":[{"id":"qwen2.5-7b-instruct"}]}`))
	}))
	defer srv.Close()
	s := newTestService(t)
	if res := s.TestConnection(context.Background(), "lmstudio", srv.URL+"/v1", ""); !res.OK || len(res.Models) != 1 {
		t.Fatalf("lmstudio = %+v", res)
	}
	mm := s.TestConnection(context.Background(), "minimax", "", "k-123456")
	if !mm.OK || mm.Verified {
		t.Fatalf("minimax = %+v", mm)
	}
	if res := s.TestConnection(context.Background(), "custom", "", "x"); res.OK || res.Error == "" {
		t.Fatalf("custom without base = %+v", res)
	}
	if res := s.TestConnection(context.Background(), "custom", "file:///etc", "x"); res.OK {
		t.Fatalf("file URL accepted: %+v", res)
	}
	down := httptest.NewServer(http.NotFoundHandler())
	u := down.URL
	down.Close()
	if res := s.TestConnection(context.Background(), "lmstudio", u+"/v1", ""); res.OK || !strings.Contains(res.Error, "refused") {
		t.Fatalf("down = %+v", res)
	}
}
