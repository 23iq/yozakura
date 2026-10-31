package fsutil

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestWriteReadJSON(t *testing.T) {
	path := filepath.Join(t.TempDir(), "sub", "a.json")
	in := map[string]any{"a": 1.0, "b": []any{"x"}}
	if !assert.NoError(t, WriteJSON(path, in, 0o600)) {
		return
	}

	raw, err := os.ReadFile(path)
	if !assert.NoError(t, err) {
		return
	}
	assert.Equal(t, "{\n  \"a\": 1,\n  \"b\": [\n    \"x\"\n  ]\n}", string(raw))
	st, err := os.Stat(path)
	if !assert.NoError(t, err) {
		return
	}
	assert.Equal(t, os.FileMode(0o600), st.Mode().Perm())

	var out map[string]any
	if !assert.NoError(t, ReadJSON(path, &out)) {
		return
	}
	assert.Equal(t, in, out)
}

func TestReadJSONErrors(t *testing.T) {
	var v map[string]any
	assert.Error(t, ReadJSON(filepath.Join(t.TempDir(), "missing.json"), &v))
	bad := filepath.Join(t.TempDir(), "bad.json")
	if !assert.NoError(t, os.WriteFile(bad, []byte("{"), 0o644)) {
		return
	}
	assert.Error(t, ReadJSON(bad, &v))
}

func TestWriteJSONMarshalError(t *testing.T) {
	path := filepath.Join(t.TempDir(), "x.json")
	assert.Error(t, WriteJSON(path, make(chan int), 0o644))
	_, err := os.Stat(path)
	assert.True(t, os.IsNotExist(err))
}
