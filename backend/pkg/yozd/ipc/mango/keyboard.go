package mango

import (
	"fmt"

	"yozakura/backend/pkg/yozd/ipc"
)

// ApplyKeyboard applies layouts, variants and options through setoption.
// Model and key repeat are left to the generated config.
func (m *Mango) ApplyKeyboard(s ipc.KeyboardSettings) error {
	if err := s.Validate(); err != nil {
		return err
	}
	s = s.Normalize()
	if len(s.Layouts) == 0 {
		return fmt.Errorf("no keyboard layouts")
	}
	conn, err := m.acquire()
	if err != nil {
		return err
	}
	layouts, variants, options := s.Joined()
	for _, cmd := range []string{
		"setoption xkb_rules_variant " + variants + " ",
		"setoption xkb_rules_options " + options + " ",
		"setoption xkb_rules_layout " + layouts,
	} {
		if err := conn.Dispatch(cmd); err != nil {
			return err
		}
	}
	return nil
}

// ActiveLayout: mango exposes no active layout query.
func (m *Mango) ActiveLayout() (ipc.KeyboardLayoutState, error) {
	return ipc.KeyboardLayoutState{}, ipc.ErrNotSupported
}
