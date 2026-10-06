package providers

import (
	"encoding/json"
	"log"
	"os"
	"path/filepath"
)

// ollamaCache is ~/.cache/<app>/ollama-models.json: model details keyed by
// "<endpoint>|<model id>", each with the digest it was read for, so
// /api/show runs again only when a model is pulled or updated.
type ollamaCache struct {
	Version int                    `json:"version"`
	Entries map[string]OllamaModel `json:"entries"`
}

const ollamaCacheVersion = 1

func cacheKey(endpoint, model string) string { return endpoint + "|" + model }

func (s *Service) ollamaCachePath() string {
	return filepath.Join(s.cacheDir, "ollama-models.json")
}

// loadOllamaCache reads the cache; a missing, corrupt or old-version file
// yields an empty cache. Callers hold ollamaMu.
func (s *Service) loadOllamaCache() *ollamaCache {
	c := &ollamaCache{Version: ollamaCacheVersion, Entries: map[string]OllamaModel{}}
	data, err := os.ReadFile(s.ollamaCachePath())
	if err != nil {
		return c
	}
	var disk ollamaCache
	if json.Unmarshal(data, &disk) != nil || disk.Version != ollamaCacheVersion || disk.Entries == nil {
		return c
	}
	return &disk
}

// saveOllamaCache writes the cache atomically. Callers hold ollamaMu.
func (s *Service) saveOllamaCache(c *ollamaCache) {
	if err := os.MkdirAll(s.cacheDir, 0o755); err != nil {
		log.Printf("[providers] cache dir: %v", err)
		return
	}
	data, err := json.MarshalIndent(c, "", " ")
	if err != nil {
		return
	}
	tmp := s.ollamaCachePath() + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		log.Printf("[providers] cache write: %v", err)
		return
	}
	if err := os.Rename(tmp, s.ollamaCachePath()); err != nil {
		log.Printf("[providers] cache rename: %v", err)
	}
}
