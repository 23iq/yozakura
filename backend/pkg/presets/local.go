package presets

import (
	"encoding/json"
	"fmt"
	"os"
	"slices"

	"yozakura/backend/pkg/catalog"
)

// Machine-local keys (catalog.MachineLocal: secrets, commands, endpoints,
// personal paths) are never part of a preset: every document read from a
// preset, a bundle or the live config goes through stripLocal, so save,
// export, mix, diff and show never carry or reveal them, and applyFiles
// puts the live values back (keepLocal), so applying or reverting a
// preset never resets them.

// masked replaces a secret value in reports.
const masked = "••••••"

// stripLocal removes the machine-local keys from a domain file. Files
// without any are returned unchanged (byte for byte).
func (m *Manager) stripLocal(domain string, data []byte) ([]byte, error) {
	if !m.Cat.HasDomain(domain) {
		return data, nil
	}
	locals := m.localPaths(domain)
	if len(locals) == 0 {
		return data, nil
	}
	doc, err := decodeObject(data)
	if err != nil || doc == nil {
		return data, err
	}
	changed := false
	for _, e := range locals {
		if catalog.DeleteOrdered(doc, e) {
			changed = true
		}
	}
	if !changed {
		return data, nil
	}
	return marshalDoc(doc)
}

// retiredMoves are the config/meta/KeyAliases.js moves of whole key trees
// between domains (old domain -> {old prefix, new domain, new prefix}). A
// machine-local key under the new prefix is also recognized under the old
// one, so the paths come from the catalog and cannot go stale on their own;
// TestRetiredMovesMatchKeyAliases keeps this table equal to the JS aliases.
var retiredMoves = map[string][]retiredMove{
	"bar": {{Old: []string{"activities"}, NewDomain: "notch", New: []string{"liveActivities"}}},
}

type retiredMove struct {
	Old       []string
	NewDomain string
	New       []string
}

// localPaths lists the machine-local paths of a domain, plus the retired
// ones: CLI save/export can run before the shell migrates the live config,
// and old preset directories remain readable.
func (m *Manager) localPaths(domain string) [][]string {
	var paths [][]string
	for _, e := range m.Cat.LocalEntries(domain) {
		paths = append(paths, e.Path)
	}
	for _, mv := range retiredMoves[domain] {
		for _, e := range m.Cat.LocalEntries(mv.NewDomain) {
			if len(e.Path) >= len(mv.New) && slices.Equal(e.Path[:len(mv.New)], mv.New) {
				paths = append(paths, append(slices.Clone(mv.Old), e.Path[len(mv.New):]...))
			}
		}
	}
	return paths
}

// keepLocal copies the machine-local values of the live file of a domain
// into a document about to be written over it.
func (m *Manager) keepLocal(domain string, data []byte) ([]byte, error) {
	if !m.Cat.HasDomain(domain) {
		return data, nil
	}
	locals := m.localPaths(domain)
	if len(locals) == 0 {
		return data, nil
	}
	liveData, err := os.ReadFile(m.Store.File(domain))
	if err != nil {
		return data, nil // no live file: nothing to keep
	}
	live, err := decodeObject(liveData)
	if err != nil || live == nil {
		return data, nil // a broken live file has nothing to keep
	}
	var doc *catalog.Object
	for _, e := range locals {
		v, ok := catalog.GetOrdered(live, e)
		if !ok {
			continue
		}
		if doc == nil {
			if doc, err = decodeObject(data); err != nil || doc == nil {
				return data, err
			}
		}
		catalog.SetOrdered(doc, e, v)
	}
	if doc == nil {
		return data, nil
	}
	return marshalDoc(doc)
}

// maskSecret hides a secret value in a report.
func (m *Manager) maskSecret(key string, v any) any {
	if s, ok := v.(string); ok && s != "" && m.Cat.Secret(key) {
		return masked
	}
	return v
}

func decodeObject(data []byte) (*catalog.Object, error) {
	v, err := catalog.DecodeOrdered(data)
	if err != nil {
		return nil, err
	}
	o, _ := v.(*catalog.Object)
	return o, nil
}

func marshalDoc(doc *catalog.Object) ([]byte, error) {
	out, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return nil, fmt.Errorf("encoding: %w", err)
	}
	return append(out, '\n'), nil
}
