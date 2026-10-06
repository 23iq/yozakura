package migrate

import (
	"encoding/json"
	"os"

	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/fsutil"
	"yozakura/backend/pkg/paths"
)

// EnsureNotchStyle moves the legacy notch.theme ("default" | "island") to
// notch.style ("attached" | "island" | "pill") once. A style the user
// already chose wins; only the old default "attached" is replaced by an
// island theme. The theme key is removed afterwards. A missing or
// unreadable file is left alone.
func EnsureNotchStyle(p paths.Paths) (bool, error) {
	if p.ConfigDir == "" {
		return false, nil
	}
	path := p.Config("notch")
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, err
	}
	v, err := catalog.DecodeOrdered(data)
	if err != nil {
		return false, nil // malformed: the shell backs it up
	}
	doc, ok := v.(*catalog.Object)
	if !ok {
		return false, nil
	}
	theme, has := doc.Get("theme")
	if !has {
		return false, nil
	}
	style, _ := doc.Get("style")
	if s, _ := style.(string); s == "" || s == "attached" {
		if theme == "island" {
			doc.Set("style", "island")
		} else {
			doc.Set("style", "attached")
		}
	}
	doc.Delete("theme")
	out, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return false, err
	}
	return true, fsutil.WriteFile(path, out, 0o644)
}
