package usage

import "path/filepath"

// DefaultDir is the ledger directory under the app data dir.
func DefaultDir(dataDir string) string { return filepath.Join(dataDir, "usage") }

// BundledPricesPath is the shipped price table in the shell source.
func BundledPricesPath(shellSource string) string {
	if shellSource == "" {
		return ""
	}
	return filepath.Join(shellSource, "assets", "ai", "prices.json")
}

// OverridePricesPath is the user's price overrides (same shape as the
// bundled table, merged on top).
func OverridePricesPath(configDir string) string { return filepath.Join(configDir, "ai-prices.json") }
