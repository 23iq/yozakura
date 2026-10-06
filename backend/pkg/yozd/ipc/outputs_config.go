package ipc

import "log"

// ValidOutputs returns the entries of monitors that pass Validate, in order.
// Invalid entries are skipped with a log line so they are never written to a
// compositor config.
func ValidOutputs(monitors []OutputConfig) []OutputConfig {
	var out []OutputConfig
	for _, m := range monitors {
		if err := m.Validate(); err != nil {
			log.Printf("yozd: skipping invalid monitor config: %v", err)
			continue
		}
		out = append(out, m)
	}
	return out
}

// ValidKeyboard validates and normalizes k for rendering. It returns nil when
// k is nil, invalid (logged) or has no usable layout, in which case the
// generators emit nothing.
func ValidKeyboard(k *KeyboardSettings) *KeyboardSettings {
	if k == nil {
		return nil
	}
	if err := k.Validate(); err != nil {
		log.Printf("yozd: skipping invalid keyboard config: %v", err)
		return nil
	}
	n := k.Normalize()
	if len(n.Layouts) == 0 {
		return nil
	}
	return &n
}
