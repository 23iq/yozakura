package usage

import (
	"errors"
	"fmt"
	"math"
	"sort"
	"strings"
	"sync"
	"time"
)

// Window is one subscription rate-limit window. UsedPercent is 0-100.
type Window struct {
	ID          string    `json:"id"` // "5h", "week", "week_opus", …
	UsedPercent float64   `json:"usedPercent"`
	ResetsAt    time.Time `json:"resetsAt,omitzero"`
}

// Limits are the subscription windows of one provider ("claude", "codex").
type Limits struct {
	Provider  string    `json:"provider"`
	Windows   []Window  `json:"windows"`
	Source    string    `json:"source,omitempty"` // "oauth", "agent", …
	UpdatedAt time.Time `json:"updatedAt"`
}

// Thresholds (percent) that raise a notification, once per window reset.
var Thresholds = []float64{80, 90}

// resetSlack tolerates jitter in reported reset times: a resetsAt that moves
// less than this is the same window.
const resetSlack = 10 * time.Minute

// Alert is a threshold crossing to notify about.
type Alert struct {
	Provider  string
	Window    string
	Threshold float64
	Used      float64
	ResetsAt  time.Time
}

type windowState struct {
	resetsAt time.Time
	notified float64 // highest threshold notified in this window
}

// LimitsStore keeps the latest limits per provider in memory and detects
// threshold crossings.
type LimitsStore struct {
	mu     sync.Mutex
	limits map[string]Limits
	state  map[string]*windowState // provider/window
	// thresholds that notify (sorted); empty: notifications off
	thresholds []float64
}

func NewLimitsStore() *LimitsStore {
	return &LimitsStore{limits: map[string]Limits{}, state: map[string]*windowState{},
		thresholds: append([]float64(nil), Thresholds...)}
}

// Set merges l into the store: windows are replaced by id, others kept.
// It returns the merged limits and the thresholds newly crossed.
func (s *LimitsStore) Set(l Limits, now time.Time) (Limits, []Alert, error) {
	l.Provider = strings.ToLower(strings.TrimSpace(l.Provider))
	if l.Provider == "" {
		return Limits{}, nil, errors.New("usage: limits provider required")
	}
	for _, w := range l.Windows {
		if w.ID == "" {
			return Limits{}, nil, errors.New("usage: window id required")
		}
		if math.IsNaN(w.UsedPercent) || w.UsedPercent < 0 {
			return Limits{}, nil, errors.New("usage: usedPercent must be >= 0")
		}
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	cur := s.limits[l.Provider]
	cur.Provider = l.Provider
	if l.Source != "" {
		cur.Source = l.Source
	}
	cur.UpdatedAt = now
	if !l.UpdatedAt.IsZero() {
		cur.UpdatedAt = l.UpdatedAt
	}
	var alerts []Alert
	for _, w := range l.Windows {
		replaced := false
		for i := range cur.Windows {
			if cur.Windows[i].ID == w.ID {
				cur.Windows[i] = w
				replaced = true
			}
		}
		if !replaced {
			cur.Windows = append(cur.Windows, w)
		}
		if a, ok := s.check(l.Provider, w); ok {
			alerts = append(alerts, a)
		}
	}
	sort.Slice(cur.Windows, func(i, j int) bool { return cur.Windows[i].ID < cur.Windows[j].ID })
	s.limits[l.Provider] = cur
	return cur, alerts, nil
}

// check returns the highest threshold w crossed that was not notified yet
// in its window. A new window starts when resetsAt moves by more than
// resetSlack, or (without reset times) when usage falls below the first
// threshold again.
func (s *LimitsStore) check(provider string, w Window) (Alert, bool) {
	key := provider + "/" + w.ID
	st := s.state[key]
	if st == nil {
		st = &windowState{resetsAt: w.ResetsAt}
		s.state[key] = st
	}
	newWindow := false
	if !w.ResetsAt.IsZero() && !st.resetsAt.IsZero() {
		d := w.ResetsAt.Sub(st.resetsAt)
		newWindow = d > resetSlack || d < -resetSlack
	} else if w.UsedPercent < s.firstThreshold() {
		newWindow = true
	}
	if newWindow {
		st.notified = 0
	}
	if !w.ResetsAt.IsZero() {
		st.resetsAt = w.ResetsAt
	}
	crossed := 0.0
	for _, t := range s.thresholds {
		if w.UsedPercent >= t {
			crossed = t
		}
	}
	if crossed == 0 || crossed <= st.notified {
		return Alert{}, false
	}
	st.notified = crossed
	return Alert{Provider: provider, Window: w.ID, Threshold: crossed, Used: w.UsedPercent, ResetsAt: w.ResetsAt}, true
}

func (s *LimitsStore) firstThreshold() float64 {
	if len(s.thresholds) == 0 {
		return Thresholds[0]
	}
	return s.thresholds[0]
}

// Get returns the limits of provider, or all providers sorted when provider
// is empty.
func (s *LimitsStore) Get(provider string) []Limits {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := []Limits{}
	for p, l := range s.limits {
		if provider == "" || p == strings.ToLower(provider) {
			l.Windows = append([]Window(nil), l.Windows...)
			out = append(out, l)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Provider < out[j].Provider })
	return out
}

// AlertState is the persisted "already notified" marker of one window, so
// a restart does not repeat a notification within the same window.
type AlertState struct {
	ResetsAt time.Time `json:"resetsAt,omitzero"`
	Notified float64   `json:"notified"`
}

// AlertStates exports the notification markers.
func (s *LimitsStore) AlertStates() map[string]AlertState {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make(map[string]AlertState, len(s.state))
	for k, st := range s.state {
		out[k] = AlertState{ResetsAt: st.resetsAt, Notified: st.notified}
	}
	return out
}

// RestoreAlertStates imports markers saved by AlertStates.
func (s *LimitsStore) RestoreAlertStates(m map[string]AlertState) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for k, st := range m {
		s.state[k] = &windowState{resetsAt: st.ResetsAt, notified: st.Notified}
	}
}

var providerLabels = map[string]string{"claude": "Claude", "codex": "Codex", "anthropic": "Anthropic", "openai": "OpenAI"}

var windowLabels = map[string]string{"5h": "5-hour", "week": "weekly", "week_opus": "weekly Opus", "week_sonnet": "weekly Sonnet"}

// Message renders an alert as notification text.
func (a Alert) Message(now time.Time) (string, string) {
	prov := providerLabels[a.Provider]
	if prov == "" {
		prov = a.Provider
	}
	win := windowLabels[a.Window]
	if win == "" {
		win = a.Window
	}
	summary := fmt.Sprintf("%s: %.0f%% of the %s limit used", prov, a.Used, win)
	body := ""
	if !a.ResetsAt.IsZero() {
		body = "Resets in " + humanDuration(a.ResetsAt.Sub(now))
	}
	return summary, body
}

func humanDuration(d time.Duration) string {
	if d < time.Minute {
		return "less than a minute"
	}
	d = d.Round(time.Minute)
	days := int(d / (24 * time.Hour))
	hours := int(d%(24*time.Hour)) / int(time.Hour)
	mins := int(d%time.Hour) / int(time.Minute)
	switch {
	case days > 0:
		return fmt.Sprintf("%dd %dh", days, hours)
	case hours > 0:
		return fmt.Sprintf("%dh %dm", hours, mins)
	}
	return fmt.Sprintf("%dm", mins)
}
