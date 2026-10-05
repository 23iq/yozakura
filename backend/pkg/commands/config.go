package commands

import (
	"fmt"
	"strings"

	"yozakura/backend/pkg/catalog"
)

// ConfigSetter writes config plans through the catalog store, the same
// validation path as `<app> config set`: a string argument is parsed
// against the key's catalog type, a mapped value is used as is.
func ConfigSetter(store *catalog.Store) func(key string, value any) (string, error) {
	return func(key string, value any) (string, error) {
		ref, err := store.Cat.Lookup(key)
		if err != nil {
			return "", err
		}
		if s, ok := value.(string); ok {
			value, err = catalog.ParseValue(ref.Entry, s, false)
			if err != nil {
				return "", err
			}
		}
		changes, err := store.Set(key, value, false)
		if err != nil {
			return "", err
		}
		if len(changes) == 0 {
			return fmt.Sprintf("%s: unchanged (%s)", catalog.NormalizeKey(key), catalog.Compact(value)), nil
		}
		lines := make([]string, 0, len(changes))
		for _, ch := range changes {
			lines = append(lines, fmt.Sprintf("%s: %s -> %s", ch.Key, catalog.Compact(ch.Old), catalog.Compact(ch.New)))
		}
		return strings.Join(lines, "\n"), nil
	}
}
