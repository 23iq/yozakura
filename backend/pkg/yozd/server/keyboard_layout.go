package server

// The last keyboard_layout event payload ({"name", "index"?}) is kept in
// the server and sent with every state dump (StateDump.KeyboardLayout), so
// subscribers that join after a switch still see the active layout.

func (s *Server) setKeyboardLayout(payload map[string]interface{}) {
	s.mu.Lock()
	s.keyboardLayout = payload
	s.mu.Unlock()
}

func (s *Server) getKeyboardLayout() map[string]interface{} {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.keyboardLayout
}
