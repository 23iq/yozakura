package mods

import (
	"os"
	"path/filepath"
	"testing"
)

func writeCompatPackage(t *testing.T, file, compat string) string {
	t.Helper()
	root := t.TempDir()
	manifest := `{"manifestVersion": 1, "id": "example.compat", "name": "Compat", "version": "1.0.0",
"description": "d", "compatibility": {"api": 1, ` + compat + `}, "operations": [{"type": "patch", "source": "p.patch"}]}`
	if err := os.WriteFile(filepath.Join(root, "p.patch"), []byte("--- a\n+++ b\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, file), []byte(manifest), 0o644); err != nil {
		t.Fatal(err)
	}
	return root
}

func TestLegacyManifestStillLoads(t *testing.T) {
	base := t.TempDir()
	os.WriteFile(filepath.Join(base, "version"), []byte("0.1.0\n"), 0o644)

	legacy := writeCompatPackage(t, LegacyManifestFile, `"ambxst": ">=1.2.0"`)
	m, err := LoadManifest(legacy)
	if err != nil {
		t.Fatalf("legacy manifest: %v", err)
	}
	if m.Compatibility.Legacy != ">=1.2.0" || len(m.UnknownFields) != 0 {
		t.Fatalf("legacy key: %+v", m.Compatibility)
	}
	if err := checkCompatibility(m, base); err != nil {
		t.Fatalf("legacy range is checked against the legacy base version: %v", err)
	}
	if root, err := locatePackageRoot(legacy); err != nil || root != legacy {
		t.Fatalf("legacy package root: %q %v", root, err)
	}
	m.Compatibility.Legacy = ">=2.0.0"
	if err := checkCompatibility(m, base); err == nil {
		t.Fatal("legacy range above the legacy base must fail")
	}

	current := writeCompatPackage(t, ManifestFile, `"yozakura": ">=0.1.0"`)
	m, err = LoadManifest(current)
	if err != nil {
		t.Fatalf("current manifest: %v", err)
	}
	if err := checkCompatibility(m, base); err != nil {
		t.Fatalf("current range: %v", err)
	}
}
