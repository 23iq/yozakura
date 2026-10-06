package mock

import "yozakura/backend/pkg/yozd/ipc"

// ListOutputs returns the Outputs field.
func (c *Compositor) ListOutputs() ([]ipc.Output, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return append([]ipc.Output(nil), c.Outputs...), nil
}

// ApplyOutput records the call (see ApplyOutputCalls).
func (c *Compositor) ApplyOutput(cfg ipc.OutputConfig) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.ApplyOutputCalls = append(c.ApplyOutputCalls, cfg)
	return nil
}

var _ ipc.OutputManager = (*Compositor)(nil)
