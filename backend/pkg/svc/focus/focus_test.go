package focus

import (
	"encoding/json"
	"testing"
	"time"

	"yozakura/backend/pkg/svc/timers"

	"github.com/stretchr/testify/assert"
)

func TestFocusStatus(t *testing.T) {
	now := time.UnixMilli(1_000_000_000)
	list := map[string]timers.Timer{
		"t1": {ID: "t1", State: timers.StateRunning, EndsAt: now.UnixMilli() + 25*60_000 - 30_000},
		"t2": {ID: "t2", State: timers.StatePaused, LeftMs: 90_000},
	}
	s := NewService(func(id string) (timers.Timer, bool) { t, ok := list[id]; return t, ok })
	s.now = func() time.Time { return now }

	assert.Equal(t, Status{}, s.Status(), "nothing reported yet")

	res, err := s.handleSet(json.RawMessage(`{"active":true,"timerId":"t1","startedAt":42}`))
	assert.NoError(t, err)
	st := res.(Status)
	assert.True(t, st.Active && st.Known)
	assert.Equal(t, int64(42), st.StartedAt)
	assert.Equal(t, list["t1"].EndsAt, st.EndsAt)
	assert.Equal(t, int64(25*60_000-30_000), st.LeftMs)
	assert.Equal(t, 25, st.MinutesLeft)

	s.Set(State{Active: true, TimerID: "t2"})
	st = s.Status()
	assert.True(t, st.Paused)
	assert.Equal(t, 2, st.MinutesLeft)
	assert.Zero(t, st.EndsAt)

	s.Set(State{Active: true, TimerID: "gone"})
	assert.Equal(t, Status{Active: true, Known: true, TimerID: "gone"}, s.Status())

	s.Set(State{Active: false, TimerID: "t1", StartedAt: 9})
	assert.Equal(t, Status{Known: true}, s.Status())

	_, err = s.handleSet(json.RawMessage(`nope`))
	assert.Error(t, err)
}
