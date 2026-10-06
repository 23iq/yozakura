package server

import (
	"encoding/json"
	"fmt"

	"yozakura/backend/pkg/yozd/ipc"
)

// dispatchOutputs handles the Monitor.Outputs/Apply and Keyboard.Apply/Active
// methods. handled is false for any other method.
func (s *Server) dispatchOutputs(req Request) (res interface{}, handled bool, err error) {
	switch req.Method {
	case "Monitor.Outputs":
		res, err = listOutputs(s.compositor)
	case "Monitor.Apply":
		var cfg ipc.OutputConfig
		if err = json.Unmarshal(req.Params, &cfg); err != nil {
			return nil, true, fmt.Errorf("invalid params: %v", err)
		}
		err = applyOutput(s.compositor, cfg)
	case "Keyboard.Apply":
		var k ipc.KeyboardSettings
		if err = json.Unmarshal(req.Params, &k); err != nil {
			return nil, true, fmt.Errorf("invalid params: %v", err)
		}
		err = applyKeyboard(s.compositor, k)
	case "Keyboard.Active":
		res, err = activeLayout(s.compositor)
	default:
		return nil, false, nil
	}
	return res, true, err
}

// listOutputs returns the outputs, never nil.
func listOutputs(c ipc.Compositor) ([]ipc.Output, error) {
	m, ok := c.(ipc.OutputManager)
	if !ok {
		return nil, ipc.ErrNotSupported
	}
	outs, err := m.ListOutputs()
	if err != nil {
		return nil, err
	}
	if outs == nil {
		outs = []ipc.Output{}
	}
	for i := range outs {
		if outs[i].Modes == nil {
			outs[i].Modes = []ipc.Mode{}
		}
	}
	return outs, nil
}

// applyOutput validates cfg before handing it to the compositor.
func applyOutput(c ipc.Compositor, cfg ipc.OutputConfig) error {
	m, ok := c.(ipc.OutputManager)
	if !ok {
		return ipc.ErrNotSupported
	}
	if err := cfg.Validate(); err != nil {
		return err
	}
	return m.ApplyOutput(cfg)
}

// applyKeyboard validates, normalizes and applies XKB settings.
func applyKeyboard(c ipc.Compositor, k ipc.KeyboardSettings) error {
	m, ok := c.(ipc.KeyboardManager)
	if !ok {
		return ipc.ErrNotSupported
	}
	if err := k.Validate(); err != nil {
		return err
	}
	return m.ApplyKeyboard(k.Normalize())
}

// activeLayout reports the active layout; Names is [] rather than null.
func activeLayout(c ipc.Compositor) (ipc.KeyboardLayoutState, error) {
	m, ok := c.(ipc.KeyboardManager)
	if !ok {
		return ipc.KeyboardLayoutState{}, ipc.ErrNotSupported
	}
	st, err := m.ActiveLayout()
	if err != nil {
		return ipc.KeyboardLayoutState{}, err
	}
	if st.Names == nil {
		st.Names = []string{}
	}
	return st, nil
}
