package daemon

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// The registry of every JSON-RPC method the daemon serves lives in
// assets/schema/ipc-methods.json; the ipc-methods audit checks the QML calls
// against it. `make schema` regenerates it (YOZ_UPDATE_IPC_METHODS=1); the
// test fails when the committed file is stale.
func TestIPCMethodRegistryFresh(t *testing.T) {
	for _, k := range []string{"HOME", "XDG_RUNTIME_DIR", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME"} {
		t.Setenv(k, t.TempDir())
	}
	d, err := New()
	if err != nil {
		t.Fatal(err)
	}
	data, err := json.MarshalIndent(d.Server().Describe(), "", " ")
	if err != nil {
		t.Fatal(err)
	}
	data = append(data, '\n')
	path := filepath.Join("..", "..", "..", "assets", "schema", "ipc-methods.json")
	if os.Getenv("YOZ_UPDATE_IPC_METHODS") != "" {
		if err := os.WriteFile(path, data, 0o644); err != nil {
			t.Fatal(err)
		}
		return
	}
	have, err := os.ReadFile(path)
	if err != nil || !bytes.Equal(have, data) {
		t.Fatalf("assets/schema/ipc-methods.json is stale: run `make schema`")
	}
}
