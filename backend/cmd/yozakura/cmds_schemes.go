package main

import (
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"yozakura/backend/pkg/brand"

	"yozakura/backend/pkg/paths"
)

// schemePreviewRoles are the palette roles the settings scheme picker draws.
// Matugen's snake_case names are mapped to the shell's Colors names
// (on_x -> overX, surface_container -> surfaceContainer).
var schemePreviewRoles = []string{
	"primary", "on_primary", "primary_container", "on_primary_container",
	"secondary", "secondary_container", "tertiary", "tertiary_container",
	"background", "on_background", "surface", "surface_dim", "surface_bright",
	"surface_container_low", "surface_container", "surface_container_high",
	"surface_container_highest", "on_surface", "on_surface_variant",
	"outline", "outline_variant", "error",
}

// schemeCacheVersion invalidates cached previews when the format changes.
const schemeCacheVersion = "1"

// matugenPalette runs matugen without side effects and returns its JSON.
// A variable so tests can replace it.
var matugenPalette = func(image, scheme string) ([]byte, error) {
	return exec.Command("matugen", "image", image, "--dry-run", "-q", "-j", "hex",
		"--source-color-index", "0", "-t", scheme).Output()
}

// shellRoleName maps a matugen role to the shell's Colors property name.
func shellRoleName(role string) string {
	if strings.HasPrefix(role, "on_") {
		role = "over_" + role[3:]
	}
	parts := strings.Split(role, "_")
	for i := 1; i < len(parts); i++ {
		if parts[i] != "" {
			parts[i] = strings.ToUpper(parts[i][:1]) + parts[i][1:]
		}
	}
	return strings.Join(parts, "")
}

// parseSchemePalette extracts {dark: {role: hex}, light: {role: hex}} from
// `matugen -j hex` output.
func parseSchemePalette(raw []byte) (map[string]map[string]string, error) {
	var doc struct {
		Colors map[string]map[string]struct {
			Color string `json:"color"`
		} `json:"colors"`
	}
	if err := json.Unmarshal(raw, &doc); err != nil {
		return nil, fmt.Errorf("invalid matugen output: %w", err)
	}
	if len(doc.Colors) == 0 {
		return nil, fmt.Errorf("matugen output has no colors")
	}
	out := map[string]map[string]string{"dark": {}, "light": {}}
	for _, role := range schemePreviewRoles {
		modes, ok := doc.Colors[role]
		if !ok {
			continue
		}
		for _, mode := range []string{"dark", "light"} {
			if c := modes[mode].Color; c != "" {
				out[mode][shellRoleName(role)] = c
			}
		}
	}
	return out, nil
}

// schemeCacheKey identifies an image version: path, size and mtime.
func schemeCacheKey(image string) (string, error) {
	st, err := os.Stat(image)
	if err != nil {
		return "", err
	}
	if st.IsDir() {
		return "", fmt.Errorf("%s is a directory", image)
	}
	sum := sha1.Sum([]byte(fmt.Sprintf("%s|%s|%d|%d", schemeCacheVersion, image, st.Size(), st.ModTime().UnixNano())))
	return hex.EncodeToString(sum[:]), nil
}

// computeSchemePreviews runs every scheme in parallel. Schemes that fail
// are left out; it only errors when none succeeded.
func computeSchemePreviews(image string) (map[string]any, error) {
	type result struct {
		scheme  string
		palette map[string]map[string]string
		err     error
	}
	results := make(chan result, len(validMatugenSchemes))
	var wg sync.WaitGroup
	for _, scheme := range validMatugenSchemes {
		wg.Add(1)
		go func(scheme string) {
			defer wg.Done()
			raw, err := matugenPalette(image, scheme)
			if err != nil {
				results <- result{scheme: scheme, err: err}
				return
			}
			palette, err := parseSchemePalette(raw)
			results <- result{scheme: scheme, palette: palette, err: err}
		}(scheme)
	}
	wg.Wait()
	close(results)

	schemes := map[string]any{}
	var firstErr error
	for r := range results {
		if r.err != nil {
			if firstErr == nil {
				firstErr = fmt.Errorf("%s: %w", r.scheme, r.err)
			}
			continue
		}
		schemes[r.scheme] = r.palette
	}
	if len(schemes) == 0 {
		return nil, firstErr
	}
	return map[string]any{"source": image, "schemes": schemes}, nil
}

// runSchemes implements `yozakura schemes <image>`: the palette every matugen
// scheme would produce for an image (both modes), as JSON on stdout. Used by
// the settings scheme picker; cached per image version in
// $XDG_CACHE_HOME/yozakura/schemes.
func runSchemes(args []string, cacheDir string) int {
	if len(args) < 1 || args[0] == "" {
		fmt.Fprintln(os.Stderr, "Usage: "+brand.AppID+" schemes <image>")
		return 2
	}
	image, err := filepath.Abs(expandTilde(args[0]))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: invalid path: %v\n", err)
		return 1
	}
	key, err := schemeCacheKey(image)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		return 1
	}
	cacheFile := filepath.Join(cacheDir, key+".json")
	if data, err := os.ReadFile(cacheFile); err == nil && json.Valid(data) {
		os.Stdout.Write(data)
		fmt.Println()
		return 0
	}
	previews, err := computeSchemePreviews(image)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: matugen failed: %v\n", err)
		return 1
	}
	data, err := json.Marshal(previews)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		return 1
	}
	if err := os.MkdirAll(cacheDir, 0o755); err == nil {
		tmp := cacheFile + ".tmp"
		if os.WriteFile(tmp, data, 0o644) == nil {
			os.Rename(tmp, cacheFile)
		}
	}
	os.Stdout.Write(data)
	fmt.Println()
	return 0
}

func schemesCacheDir() string {
	return filepath.Join(paths.New().CacheDir, "schemes")
}
