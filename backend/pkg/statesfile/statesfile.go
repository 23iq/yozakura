// Package statesfile is the shared read-modify-write of states.json, the
// small per-key toggle store (caffeine, gameMode, nightlight, ...). One
// process-wide mutex serialises every writer so two services toggling at
// once cannot drop each other's key; errors are returned, never swallowed.
package statesfile

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"sync"

	"yozakura/backend/pkg/fsutil"
)

var mu sync.Mutex

// readDoc loads the document; a missing file is an empty document, an
// unparsable one is an error.
func readDoc(path string) (map[string]json.RawMessage, error) {
	doc := map[string]json.RawMessage{}
	data, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return doc, nil
		}
		return nil, err
	}
	if err := json.Unmarshal(data, &doc); err != nil {
		return nil, fmt.Errorf("parse %s: %w", path, err)
	}
	return doc, nil
}

// Get decodes the value stored under key into a T. found is false when the
// file or the key is absent.
func Get[T any](path, key string) (val T, found bool, err error) {
	mu.Lock()
	defer mu.Unlock()
	doc, err := readDoc(path)
	if err != nil {
		return val, false, err
	}
	raw, ok := doc[key]
	if !ok {
		return val, false, nil
	}
	if err := json.Unmarshal(raw, &val); err != nil {
		return val, false, fmt.Errorf("%s: key %q: %w", path, key, err)
	}
	return val, true, nil
}

// Set stores v under key, keeping every other key. An unparsable existing
// file is replaced (as the services always did) so a corrupt states.json
// cannot block toggles forever; the other keys in it are lost.
func Set(path, key string, v any) error {
	mu.Lock()
	defer mu.Unlock()
	doc, err := readDoc(path)
	if err != nil {
		doc = map[string]json.RawMessage{}
	}
	raw, err := json.Marshal(v)
	if err != nil {
		return err
	}
	doc[key] = raw
	return fsutil.WriteJSON(path, doc, 0o644)
}
