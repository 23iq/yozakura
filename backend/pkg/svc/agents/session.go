package agents

import (
	"context"
	"strings"
	"sync"
	"time"
)

// session is one conversation with an agent. Lock order: opMu, then m.mu.
type session struct {
	m       *Manager
	meta    SessionMeta // guarded by m.mu
	opMu    sync.Mutex  // serializes start/send/close
	conn    Conn        // guarded by m.mu
	gen     int         // incremented per process; stale sinks are ignored
	closing bool
	pending map[string]pendingPerm
	rules   map[string]bool
	buf     *Event
	timer   *time.Timer
	block   string // text of the current assistant block (for LastText)
	lastK   string
}

type pendingPerm struct {
	req   PermissionRequest
	reply func(string)
}

func newSession(m *Manager, meta SessionMeta) *session {
	return &session{m: m, meta: meta, pending: map[string]pendingPerm{}, rules: map[string]bool{}}
}

func (s *session) send(text string, images []string) error {
	s.opMu.Lock()
	defer s.opMu.Unlock()
	m := s.m
	m.mu.Lock()
	conn := s.conn
	if s.meta.Title == "" {
		s.meta.Title = oneLine(text, 60)
	}
	ev := Event{Kind: KindUser, Text: text}
	if len(images) > 0 {
		ev.Input = map[string]any{"images": images}
	}
	s.emitLocked(ev)
	if conn == nil {
		opts, err := m.startOptionsLocked(s)
		if err != nil {
			s.emitLocked(Event{Kind: KindError, Message: err.Error()})
			m.mu.Unlock()
			return err
		}
		s.gen++
		s.closing = false
		sink := &sessionSink{s: s, gen: s.gen}
		s.setStatusLocked(StatusStarting)
		m.mu.Unlock()
		c, err := Lookup(s.meta.Agent).Start(context.Background(), opts, sink)
		m.mu.Lock()
		if err != nil {
			s.emitLocked(Event{Kind: KindError, Message: "failed to start " + s.meta.Agent + ": " + err.Error()})
			s.setStatusLocked(StatusExited)
			m.mu.Unlock()
			return err
		}
		s.conn = c
		conn = c
	}
	s.setStatusLocked(StatusRunning)
	m.mu.Unlock()
	return conn.Send(text, images)
}

func (s *session) respond(request, decision string) error {
	m := s.m
	m.mu.Lock()
	p, ok := s.pending[request]
	if !ok {
		m.mu.Unlock()
		return nil // already answered (or session restarted)
	}
	if decision == DecisionAllowSession && p.req.RuleKey == "" {
		decision = DecisionAllow // no session rule was offered for this request
	}
	var replies []func(string)
	resolve := func(rid string, pp pendingPerm) {
		delete(s.pending, rid)
		s.emitLocked(Event{Kind: KindPermissionResolved, ID: rid, Tool: pp.req.Tool, Title: pp.req.Title,
			Category: pp.req.Category, Decision: decision})
		replies = append(replies, pp.reply)
	}
	// Shell commands are remembered here by their exact text; the agent is
	// told "allow once" so its own (prefix) rules cannot widen the grant.
	agentDecision := decision
	if in, _ := p.req.Input.(map[string]any); in["command"] != nil && decision == DecisionAllowSession {
		agentDecision = DecisionAllow
	}
	resolve(request, p)
	if decision == DecisionAllowSession && p.req.RuleKey != "" {
		s.rules[p.req.RuleKey] = true
		// The same rule answers the other waiting requests too.
		for rid, other := range s.pending {
			if other.req.RuleKey == p.req.RuleKey {
				resolve(rid, other)
			}
		}
	}
	s.meta.Pending = len(s.pending)
	if s.conn != nil && s.meta.Status == StatusWaiting && len(s.pending) == 0 {
		s.setStatusLocked(StatusRunning)
	}
	m.saveLocked()
	m.mu.Unlock()
	for _, r := range replies {
		r(agentDecision)
	}
	return nil
}

// denyAllLocked answers every pending request with deny; returns the replies.
func (s *session) denyAllLocked() []func(string) {
	var replies []func(string)
	for rid, p := range s.pending {
		s.emitLocked(Event{Kind: KindPermissionResolved, ID: rid, Tool: p.req.Tool, Title: p.req.Title,
			Category: p.req.Category, Decision: DecisionDeny})
		replies = append(replies, p.reply)
	}
	s.pending = map[string]pendingPerm{}
	s.meta.Pending = 0
	return replies
}

func (s *session) cancel() error {
	m := s.m
	m.mu.Lock()
	conn := s.conn
	replies := s.denyAllLocked()
	m.mu.Unlock()
	for _, r := range replies {
		r(DecisionDeny)
	}
	if conn == nil {
		return nil
	}
	return conn.Interrupt()
}

func (s *session) close() {
	s.opMu.Lock()
	defer s.opMu.Unlock()
	m := s.m
	m.mu.Lock()
	conn := s.conn
	s.closing = true
	replies := s.denyAllLocked()
	m.mu.Unlock()
	for _, r := range replies {
		r(DecisionDeny)
	}
	if conn != nil {
		_ = conn.Close()
	}
}

// setStatusLocked records and broadcasts a status change.
func (s *session) setStatusLocked(st string) {
	if s.meta.Status == st {
		return
	}
	s.meta.Status = st
	s.emitLocked(Event{Kind: KindStatus, Status: st})
	s.m.saveLocked()
	s.m.broadcastSessionsLocked()
}

// emitLocked coalesces text/thinking deltas and commits everything else.
func (s *session) emitLocked(ev Event) {
	if ev.Delta && (ev.Kind == KindText || ev.Kind == KindThinking) {
		if s.buf != nil && s.buf.Kind == ev.Kind {
			s.buf.Text += ev.Text
			return
		}
		s.flushLocked()
		cp := ev
		s.buf = &cp
		gen := s.gen
		s.timer = time.AfterFunc(s.m.coalesce, func() {
			s.m.mu.Lock()
			if s.gen == gen {
				s.flushLocked()
			}
			s.m.mu.Unlock()
		})
		return
	}
	s.flushLocked()
	s.commitLocked(ev)
}

func (s *session) flushLocked() {
	if s.timer != nil {
		s.timer.Stop()
		s.timer = nil
	}
	if s.buf != nil {
		ev := *s.buf
		s.buf = nil
		s.commitLocked(ev)
	}
}

func (s *session) commitLocked(ev Event) {
	m := s.m
	s.meta.LastSeq++
	ev.Seq = s.meta.LastSeq
	ev.Session = s.meta.ID
	ev.TS = m.now().UnixMilli()
	switch ev.Kind {
	case KindText:
		if s.lastK != KindText {
			s.block = ""
		}
		s.block += ev.Text
		if t := strings.TrimSpace(s.block); t != "" {
			s.meta.LastText = lastRunes(t, 200)
		}
	case KindUser:
		s.meta.Updated = ev.TS
	}
	if ev.Kind != KindStatus {
		s.lastK = ev.Kind
	}
	m.appendLogLocked(s.meta.ID, ev)
	m.broadcast("agents.event", ev)
}

func lastRunes(s string, n int) string {
	r := []rune(s)
	if len(r) > n {
		return "…" + string(r[len(r)-n:])
	}
	return s
}

// sessionSink adapts adapter callbacks to a session; events from a process
// generation that was replaced are dropped.
type sessionSink struct {
	s   *session
	gen int
}

func (k *sessionSink) live() bool { return k.s.gen == k.gen }

func (k *sessionSink) Emit(ev Event) {
	m := k.s.m
	m.mu.Lock()
	defer m.mu.Unlock()
	if !k.live() {
		return
	}
	k.s.emitLocked(ev)
	if ev.Kind == KindDone {
		k.s.flushLocked()
		k.s.meta.Updated = m.now().UnixMilli()
		if len(k.s.pending) > 0 {
			k.s.setStatusLocked(StatusWaiting)
		} else {
			k.s.setStatusLocked(StatusIdle)
		}
		m.saveLocked()
		m.broadcastSessionsLocked()
	}
}

func (k *sessionSink) SetAgentSessionID(id string) {
	m := k.s.m
	m.mu.Lock()
	defer m.mu.Unlock()
	if !k.live() || id == "" || k.s.meta.AgentSessionID == id {
		return
	}
	k.s.meta.AgentSessionID = id
	m.saveLocked()
}

func (k *sessionSink) Permission(req PermissionRequest, reply func(string)) {
	s := k.s
	m := s.m
	m.mu.Lock()
	if !k.live() {
		m.mu.Unlock()
		reply(DecisionDeny)
		return
	}
	if d := m.policy().Decide(req, s.meta.Yolo, s.rules); d != "" {
		// Every automatic decision is reported, reads included, so the
		// timeline shows what ran without asking.
		s.emitLocked(Event{Kind: KindPermissionResolved, ID: req.ID, Tool: req.Tool, Title: req.Title,
			Category: req.Category, Decision: DecisionAuto})
		m.mu.Unlock()
		reply(d)
		return
	}
	s.pending[req.ID] = pendingPerm{req: req, reply: reply}
	s.meta.Pending = len(s.pending)
	options := []string{DecisionAllow, DecisionAllowSession, DecisionDeny}
	if req.RuleKey == "" {
		options = []string{DecisionAllow, DecisionDeny}
	}
	s.emitLocked(Event{Kind: KindPermissionRequest, ID: req.ID, Tool: req.Tool, Title: req.Title, Category: req.Category,
		Input: req.Input, Path: req.Path, Diff: req.Diff, Options: options})
	s.setStatusLocked(StatusWaiting)
	m.saveLocked()
	m.broadcastSessionsLocked()
	m.mu.Unlock()
}

func (k *sessionSink) Exited(err error, stderrTail string) {
	s := k.s
	m := s.m
	m.mu.Lock()
	if !k.live() {
		m.mu.Unlock()
		return
	}
	s.conn = nil
	replies := s.denyAllLocked()
	s.flushLocked()
	if !s.closing && err != nil {
		msg := strings.TrimSpace(stderrTail)
		if msg == "" {
			msg = err.Error()
		}
		s.emitLocked(Event{Kind: KindError, Message: s.meta.Agent + " exited: " + lastRunes(msg, 600)})
	}
	s.gen++ // late callbacks of this process are now stale
	s.setStatusLocked(StatusExited)
	m.mu.Unlock()
	for _, r := range replies {
		r(DecisionDeny)
	}
}
