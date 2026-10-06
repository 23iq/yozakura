package mock

import "yozakura/backend/pkg/yozd/ipc"

// ApplyKeyboard records the call (see ApplyKeyboardCalls).
func (c *Compositor) ApplyKeyboard(s ipc.KeyboardSettings) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.ApplyKeyboardCalls = append(c.ApplyKeyboardCalls, s)
	return nil
}

// ActiveLayout returns the Keyboard field.
func (c *Compositor) ActiveLayout() (ipc.KeyboardLayoutState, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.Keyboard, nil
}

var _ ipc.KeyboardManager = (*Compositor)(nil)
