package server

import (
	"yozakura/backend/pkg/instancelock"
	"yozakura/backend/pkg/yozd/ipc"
)

// StateDump is the state sent with State.Dump and with every event.
type StateDump struct {
	Windows        []ipc.Window           `json:"windows"`
	Workspaces     []ipc.Workspace        `json:"workspaces"`
	Monitors       []ipc.Monitor          `json:"monitors"`
	OverviewOpen   *bool                  `json:"overview_open,omitempty"`
	KeyboardLayout map[string]interface{} `json:"keyboard_layout,omitempty"` // keyboard_layout.go
}

// stateDump is the cached state; overview adds the overview flag (events).
func (s *Server) stateDump(overview bool) *StateDump {
	d := &StateDump{
		Windows:        s.cache.GetWindows(),
		Workspaces:     s.cache.GetWorkspaces(),
		Monitors:       s.cache.GetMonitors(),
		KeyboardLayout: s.getKeyboardLayout(),
	}
	if overview {
		d.OverviewOpen = s.getOverviewOpen()
	}
	return d
}

// RemoveSocket unlinks the socket Start bound, only if it is still ours (a
// successor may have replaced it). Call it on shutdown.
func (s *Server) RemoveSocket() bool {
	s.sockMu.Lock()
	defer s.sockMu.Unlock()
	return instancelock.RemoveIfOwned(s.socketPath, s.sockID)
}
