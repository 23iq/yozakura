// Package extrascatalog embeds a build-time copy of assets/catalog/extras.json
// for the privileged `sys` helper, which must never read a catalog from a
// user-writable location. Regenerate with `make extras-catalog` (also run
// by `make build` and `make schema`) or `go generate`; a test fails when the
// copy is stale.
package extrascatalog

import (
	_ "embed"
	"encoding/json"
	"fmt"

	"yozakura/backend/pkg/svc/extras"
)

//go:generate cp ../../../assets/catalog/extras.json extras.json

//go:embed extras.json
var embedded []byte

// Embedded returns the raw embedded catalog.
func Embedded() []byte {
	return append([]byte(nil), embedded...)
}

// Load parses and validates the embedded catalog.
func Load() (*extras.Catalog, error) {
	var c extras.Catalog
	if err := json.Unmarshal(embedded, &c); err != nil {
		return nil, fmt.Errorf("embedded extras catalog: %w", err)
	}
	if err := c.Validate(); err != nil {
		return nil, err
	}
	return &c, nil
}
