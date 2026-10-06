package agents

// ConfirmGate extends the always-confirm list beyond fixed tool names: a
// routine_run/routine_save whose routine runs confirm-required steps must
// ask too (routines.ConfirmSteps). It is told when the user allows such a
// request, so the routines service accepts that one run.
type ConfirmGate interface {
	// NeedsConfirm reports whether the built-in tool `tool` (bare name,
	// e.g. "routine_run") with this input must always ask.
	NeedsConfirm(tool string, input map[string]any) bool
	// Allowed is called after the user allowed such a request.
	Allowed(tool string, input map[string]any)
}

// SetConfirmGate wires the gate (nil: only the fixed confirm tools ask).
func (m *Manager) SetConfirmGate(g ConfirmGate) {
	m.mu.Lock()
	m.gate = g
	m.mu.Unlock()
}

// confirmLocked reports whether req must always ask (m.mu held).
func (m *Manager) confirmLocked(req PermissionRequest) bool {
	if req.Confirm || IsConfirmTool(req.Tool) {
		return true
	}
	name := YozakuraTool(req.Tool)
	if name == "" || m.gate == nil {
		return false
	}
	in, _ := req.Input.(map[string]any)
	return m.gate.NeedsConfirm(name, in)
}

// allowedLocked tells the gate the user allowed a confirm request (m.mu
// held; the gate must not call back into the manager).
func (m *Manager) allowedLocked(req PermissionRequest) {
	name := YozakuraTool(req.Tool)
	if !req.Confirm || name == "" || m.gate == nil {
		return
	}
	in, _ := req.Input.(map[string]any)
	m.gate.Allowed(name, in)
}
