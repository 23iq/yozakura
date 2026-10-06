package extrascatalog

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

func TestEmbeddedMatchesAssets(t *testing.T) {
	src, err := os.ReadFile(filepath.Join("..", "..", "..", "assets", "catalog", "extras.json"))
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(src, Embedded()) {
		t.Fatal("backend/pkg/extrascatalog/extras.json is stale: run `make extras-catalog`")
	}
}

func TestLoad(t *testing.T) {
	c, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := c.Get("ollama"); !ok {
		t.Fatal("ollama missing")
	}
}
