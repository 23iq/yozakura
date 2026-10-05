package migrate

import (
	"encoding/json"
	"os"
	"path/filepath"

	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/paths"
)

// OnboardingKey is the general.json key that hides the first-run wizard
// (general.onboardingDone).
const OnboardingKey = "onboardingDone"

// MarkOnboardingDone sets general.onboardingDone to true in the general.json
// at path, keeping the rest of the file and its key order. A missing file is
// created only with create; an existing value is replaced only with
// overwrite (otherwise only a missing key is added). It reports whether the
// file was written.
func MarkOnboardingDone(path string, create, overwrite bool) (bool, error) {
	doc := catalog.NewObject()
	data, err := os.ReadFile(path)
	switch {
	case os.IsNotExist(err):
		if !create {
			return false, nil
		}
	case err != nil:
		return false, err
	default:
		v, err := catalog.DecodeOrdered(data)
		if err != nil {
			return false, err
		}
		o, ok := v.(*catalog.Object)
		if !ok {
			return false, nil
		}
		doc = o
	}
	if cur, ok := doc.Get(OnboardingKey); ok && (!overwrite || cur == true) {
		return false, nil
	}
	doc.Set(OnboardingKey, true)
	out, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return false, err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return false, err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, out, 0o644); err != nil {
		return false, err
	}
	return true, os.Rename(tmp, path)
}

// EnsureOnboardingFlag runs on every start before the shell: an install
// whose general.json predates the wizard (the file exists without the key)
// is an existing setup, so the wizard is marked done and never auto-shows.
// A fresh install (no general.json yet) is left alone.
func EnsureOnboardingFlag(p paths.Paths) (bool, error) {
	if p.ConfigDir == "" {
		return false, nil
	}
	return MarkOnboardingDone(p.Config("general"), false, false)
}
