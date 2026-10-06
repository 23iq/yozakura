package agents

import (
	"bufio"
	"encoding/json"
	"log"
	"os"
	"path/filepath"
)

// On-disk layout (dir = ~/.local/share/yozakura/agents):
//   sessions.json   [SessionMeta...]
//   <id>.jsonl      append-only normalized events

func (m *Manager) logPath(id string) string { return filepath.Join(m.dir, id+".jsonl") }

func (m *Manager) load() {
	data, err := os.ReadFile(filepath.Join(m.dir, "sessions.json"))
	if err != nil {
		return
	}
	var metas []SessionMeta
	if err := json.Unmarshal(data, &metas); err != nil {
		log.Printf("[agents] sessions.json: %v", err)
		return
	}
	for _, meta := range metas {
		if meta.ID == "" {
			continue
		}
		// No process survives a daemon restart; the session is resumable.
		meta.Status = StatusExited
		meta.Pending = 0
		meta.Mode = normalizeMode(meta.Mode)
		m.sessions[meta.ID] = newSession(m, meta)
	}
}

func (m *Manager) saveLocked() {
	if err := os.MkdirAll(m.dir, 0o700); err != nil {
		return
	}
	data, err := json.MarshalIndent(m.sessionsLocked(), "", "  ")
	if err != nil {
		return
	}
	path := filepath.Join(m.dir, "sessions.json")
	tmp := path + ".tmp"
	if os.WriteFile(tmp, data, 0o600) == nil {
		_ = os.Rename(tmp, path)
	}
}

func (m *Manager) appendLogLocked(id string, ev Event) {
	if err := os.MkdirAll(m.dir, 0o700); err != nil {
		return
	}
	data, err := json.Marshal(ev)
	if err != nil {
		return
	}
	f, err := os.OpenFile(m.logPath(id), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
	if err != nil {
		return
	}
	_, _ = f.Write(append(data, '\n'))
	_ = f.Close()
}

// Events returns the logged events with seq > since.
func (m *Manager) Events(id string, since int64) ([]Event, int64, error) {
	s, err := m.get(id)
	if err != nil {
		return nil, 0, err
	}
	m.mu.Lock()
	s.flushLocked()
	last := s.meta.LastSeq
	m.mu.Unlock()
	out := []Event{}
	f, err := os.Open(m.logPath(id))
	if err != nil {
		if os.IsNotExist(err) {
			return out, last, nil
		}
		return nil, 0, err
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 256<<10), 64<<20)
	for sc.Scan() {
		var ev Event
		if json.Unmarshal(sc.Bytes(), &ev) == nil && ev.Seq > since {
			out = append(out, ev)
		}
	}
	return out, last, sc.Err()
}
