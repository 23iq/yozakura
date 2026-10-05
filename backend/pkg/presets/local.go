package presets

import (
	"encoding/json"
	"fmt"
	"os"

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
	locals := m.Cat.LocalEntries(domain)
	if len(locals) == 0 {
		return data, nil
	}
	doc, err := decodeObject(data)
	if err != nil || doc == nil {
		return data, err
	}
	changed := false
	for _, e := range locals {
		if catalog.DeleteOrdered(doc, e.Path) {
			changed = true
		}
	}
	if !changed {
		return data, nil
	}
	return marshalDoc(doc)
}

// keepLocal copies the machine-local values of the live file of a domain
// into a document about to be written over it.
func (m *Manager) keepLocal(domain string, data []byte) ([]byte, error) {
	if !m.Cat.HasDomain(domain) {
		return data, nil
	}
	locals := m.Cat.LocalEntries(domain)
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
		v, ok := catalog.GetOrdered(live, e.Path)
		if !ok {
			continue
		}
		if doc == nil {
			if doc, err = decodeObject(data); err != nil || doc == nil {
				return data, err
			}
		}
		catalog.SetOrdered(doc, e.Path, v)
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
