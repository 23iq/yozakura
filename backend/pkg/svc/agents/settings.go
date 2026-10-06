package agents

import "errors"

// UpdateParams are the agents.update parameters.
type UpdateParams struct {
	Model        *string `json:"model"`
	Effort       *string `json:"effort"`
	SystemPrompt *string `json:"systemPrompt"`
	Session      string  `json:"session"`
	Title        *string `json:"title"`
	Pinned       *bool   `json:"pinned"`
	Yolo         *bool   `json:"yolo"`
}

// Update edits session metadata. Turning YOLO on approves pending requests
// (not the confirm-required ones); assistant sessions cannot turn it on.
func (m *Manager) Update(p UpdateParams) (SessionMeta, error) {
	s, err := m.get(p.Session)
	if err != nil {
		return SessionMeta{}, err
	}
	s.opMu.Lock()
	defer s.opMu.Unlock()
	launch := p.Model != nil || p.Effort != nil || p.SystemPrompt != nil
	m.mu.Lock()
	if p.Yolo != nil && *p.Yolo && (s.meta.Mode == ModeAssistant || s.meta.Mode == ModeOneshot) {
		m.mu.Unlock()
		return SessionMeta{}, errors.New("YOLO is not available for assistant sessions")
	}
	if launch && (s.meta.Status != StatusIdle && s.meta.Status != StatusExited || len(s.pending) > 0) {
		m.mu.Unlock()
		return SessionMeta{}, errors.New("launch settings can only change while idle")
	}
	model, effort := s.meta.Model, s.meta.Effort
	if p.Model != nil {
		model = *p.Model
	}
	if p.Effort != nil {
		effort = *p.Effort
	}
	if p.SystemPrompt != nil {
		if err := validateLaunch(Lookup(s.meta.Agent), s.meta.Mode, *p.SystemPrompt); err != nil {
			m.mu.Unlock()
			return SessionMeta{}, err
		}
	}

	if launch && s.conn != nil && s.meta.AgentSessionID == "" {
		m.mu.Unlock()
		return SessionMeta{}, errors.New("native session identity is not yet available")
	}
	agent, cwd := s.meta.Agent, s.meta.Cwd
	m.mu.Unlock()
	if launch {
		if err := m.validateSettings(agent, cwd, model, effort); err != nil {
			return SessionMeta{}, err
		}
	}
	m.mu.Lock()
	var old Conn
	if launch {
		old = s.conn
		s.conn = nil
		s.gen++
		s.meta.Model = model
		s.meta.Effort = effort
		if p.SystemPrompt != nil {
			s.meta.SystemPrompt = *p.SystemPrompt
		}
	}
	if p.Title != nil {
		s.meta.Title = *p.Title
	}
	if p.Pinned != nil {
		s.meta.Pinned = *p.Pinned
	}
	var approve []string
	if p.Yolo != nil {
		s.meta.Yolo = *p.Yolo
		if s.meta.Yolo {
			for rid, pp := range s.pending {
				if !pp.req.Confirm {
					approve = append(approve, rid)
				}
			}
		}
	}
	s.meta.Updated = m.now().UnixMilli()
	meta := s.meta
	m.saveLocked()
	m.broadcastSessionsLocked()
	m.mu.Unlock()
	if old != nil {
		_ = old.Close()
	}
	for _, rid := range approve {
		_ = s.respond(rid, DecisionAllow)
	}
	return meta, nil
}
