package presets

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/catalog"
)

// BundleFormat identifies a single-file preset export.
var BundleFormat = brand.AppID + "-preset"

// Bundle is a preset in one JSON file (export/import, sharing).
type Bundle struct {
	Format      string         `json:"format"`
	Version     int            `json:"version"`
	Name        string         `json:"name"`
	Author      string         `json:"author,omitempty"`
	AuthorURL   string         `json:"authorUrl,omitempty"`
	Description string         `json:"description,omitempty"`
	Domains     map[string]any `json:"domains"`
	raw         map[string]json.RawMessage
}

// ReadBundle loads and checks a bundle file.
func ReadBundle(path string) (*Bundle, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var head struct {
		Format      string                     `json:"format"`
		Version     int                        `json:"version"`
		Name        string                     `json:"name"`
		Author      string                     `json:"author"`
		AuthorURL   string                     `json:"authorUrl"`
		Description string                     `json:"description"`
		Domains     map[string]json.RawMessage `json:"domains"`
	}
	if err := json.Unmarshal(data, &head); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	if head.Format != BundleFormat {
		return nil, fmt.Errorf("%s is not a preset bundle (format %q, want %q)", path, head.Format, BundleFormat)
	}
	if head.Version != 1 {
		return nil, fmt.Errorf("%s: unsupported bundle version %d", path, head.Version)
	}
	b := &Bundle{Format: head.Format, Version: head.Version, Name: head.Name, Author: head.Author,
		AuthorURL: head.AuthorURL, Description: head.Description, Domains: map[string]any{}, raw: head.Domains}
	for d, raw := range head.Domains {
		var v any
		if err := json.Unmarshal(raw, &v); err != nil {
			return nil, fmt.Errorf("%s: domain %s: %w", path, d, err)
		}
		b.Domains[d] = v
	}
	return b, nil
}

// Export writes a preset (or "current") as a bundle file.
func (m *Manager) Export(ref, file string) (*Bundle, error) {
	b := &Bundle{Format: BundleFormat, Version: 1, Name: ref}
	if ref != Current {
		p, err := m.Find(ref)
		if err != nil {
			return nil, err
		}
		b.Name, b.Author, b.AuthorURL, b.Description = p.Name, p.Author, p.AuthorURL, p.Description
		ref = p.Path
	}
	raw, err := m.rawDocuments(ref)
	if err != nil {
		return nil, err
	}
	b.raw = map[string]json.RawMessage{}
	for d, data := range raw {
		var buf bytes.Buffer
		if err := json.Compact(&buf, data); err != nil {
			return nil, fmt.Errorf("%s.json: %w", d, err)
		}
		b.raw[d] = buf.Bytes()
	}
	out, err := json.MarshalIndent(struct {
		Format      string                     `json:"format"`
		Version     int                        `json:"version"`
		Name        string                     `json:"name"`
		Author      string                     `json:"author,omitempty"`
		AuthorURL   string                     `json:"authorUrl,omitempty"`
		Description string                     `json:"description,omitempty"`
		Domains     map[string]json.RawMessage `json:"domains"`
	}{b.Format, b.Version, b.Name, b.Author, b.AuthorURL, b.Description, b.raw}, "", "  ")
	if err != nil {
		return nil, err
	}
	if err := writeAtomic(file, append(out, '\n')); err != nil {
		return nil, err
	}
	return b, nil
}

// Import creates a user preset from a bundle file; name overrides the
// bundle's name. Unknown domains are rejected, invalid values reported.
func (m *Manager) Import(file, name string, force bool) (Preset, []catalog.Problem, error) {
	unlock, lerr := m.lock()
	if lerr != nil {
		return Preset{}, nil, lerr
	}
	defer unlock()
	b, err := ReadBundle(file)
	if err != nil {
		return Preset{}, nil, err
	}
	if name == "" {
		name = b.Name
	}
	if name == "" {
		name = strings.TrimSuffix(filepath.Base(file), filepath.Ext(file))
	}
	for _, p := range m.List() {
		if p.Official && strings.EqualFold(p.Name, name) {
			return Preset{}, nil, fmt.Errorf("%q is a built-in preset name; pass --name to import under another name", p.Name)
		}
	}
	names := make([]string, 0, len(b.raw))
	for d := range b.raw {
		names = append(names, d)
	}
	sort.Strings(names)
	files := map[string][]byte{}
	var problems []catalog.Problem
	for _, d := range names {
		if Excluded[d] {
			problems = append(problems, catalog.Problem{Key: d, Message: "excluded from presets; skipped"})
			continue
		}
		if !m.knownDomain(d) {
			return Preset{}, nil, fmt.Errorf("bundle has unknown config domain %q", d)
		}
		problems = append(problems, m.validate(d, b.Domains[d])...)
		var buf bytes.Buffer
		if err := json.Indent(&buf, b.raw[d], "", "  "); err != nil {
			return Preset{}, nil, err
		}
		if files[d], err = m.stripLocal(d, buf.Bytes()); err != nil {
			return Preset{}, nil, fmt.Errorf("bundle domain %s: %w", d, err)
		}
	}
	author := b.Author
	if author == "" {
		author = "Unknown"
	}
	p, err := m.write(name, files, info{Author: author, AuthorURL: b.AuthorURL, Description: b.Description}, force)
	return p, problems, err
}

// CheckBundle validates a bundle file against the catalog without
// installing it: unknown domains are an error, invalid values problems
// (excluded domains, which an import skips, are not reported).
func (m *Manager) CheckBundle(file string) ([]catalog.Problem, error) {
	b, err := ReadBundle(file)
	if err != nil {
		return nil, err
	}
	var problems []catalog.Problem
	for _, d := range b.DomainNames() {
		if Excluded[d] {
			continue
		}
		if !m.knownDomain(d) {
			return nil, fmt.Errorf("bundle has unknown config domain %q", d)
		}
		problems = append(problems, m.validate(d, b.Domains[d])...)
	}
	return problems, nil
}

// DomainNames lists the domains in the bundle (sorted).
func (b *Bundle) DomainNames() []string {
	out := make([]string, 0, len(b.raw))
	for d := range b.raw {
		out = append(out, d)
	}
	sort.Strings(out)
	return out
}
