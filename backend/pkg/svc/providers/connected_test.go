package providers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestListConnectedNeverReturnsKeys(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer "+secretKey {
			http.Error(w, "nope", http.StatusUnauthorized)
			return
		}
		_, _ = w.Write([]byte(`{"data":[{"id":"gpt-5"}]}`))
	}))
	defer srv.Close()
	s := newTestService(t)
	// Local servers on a closed port: unreachable, never the real ones.
	s.configFile = filepath.Join(t.TempDir(), "ai.json")
	if err := os.WriteFile(s.configFile, []byte(`{"ollama":{"endpoint":"http://127.0.0.1:1"},"lmstudio":{"endpoint":"http://127.0.0.1:1/v1"}}`), 0o644); err != nil {
		t.Fatal(err)
	}
	s.SetCredentials(func() []Credential {
		return []Credential{{Provider: "openai", Key: secretKey, Endpoint: srv.URL + "/v1"}}
	})
	list := s.ListConnected(context.Background(), "")
	if len(list) != 3 || list[0].Provider != "lmstudio" || list[1].Provider != "ollama" || list[2].Provider != "openai" {
		t.Fatalf("list = %+v", list)
	}
	oa := list[2]
	if !oa.OK || !oa.Stored || oa.Local || len(oa.Models) != 1 || oa.Models[0].ID != "gpt-5" {
		t.Fatalf("openai = %+v", oa)
	}
	if !list[0].Local || list[0].OK || list[0].Endpoint != "http://127.0.0.1:1/v1" || list[1].OK {
		t.Fatalf("local = %+v %+v", list[0], list[1])
	}
	raw, _ := s.handleList(json.RawMessage(`{"provider":"openai"}`))
	data, _ := json.Marshal(raw)
	if strings.Contains(string(data), secretKey) || !strings.Contains(string(data), `"gpt-5"`) || strings.Contains(string(data), "ollama") {
		t.Fatalf("handleList = %s", data)
	}
}
