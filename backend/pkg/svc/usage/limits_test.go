package usage

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestLimitsStoreMergesWindows(t *testing.T) {
	s := NewLimitsStore()
	now := at("2026-10-06 10:00")
	reset := now.Add(3 * time.Hour)
	_, _, err := s.Set(Limits{Provider: "Codex", Source: "agent", Windows: []Window{{ID: "5h", UsedPercent: 10, ResetsAt: reset}, {ID: "week", UsedPercent: 20}}}, now)
	require.NoError(t, err)
	l, _, err := s.Set(Limits{Provider: "codex", Windows: []Window{{ID: "5h", UsedPercent: 15, ResetsAt: reset}}}, now.Add(time.Minute))
	require.NoError(t, err)
	assert.Equal(t, "codex", l.Provider)
	assert.Equal(t, "agent", l.Source) // kept when the update has none
	assert.Equal(t, now.Add(time.Minute), l.UpdatedAt)
	require.Len(t, l.Windows, 2)
	assert.Equal(t, 15.0, l.Windows[0].UsedPercent)
	assert.Equal(t, "week", l.Windows[1].ID)

	_, _, err = s.Set(Limits{Provider: "claude", Windows: []Window{{ID: "5h", UsedPercent: 1}}}, now)
	require.NoError(t, err)
	all := s.Get("")
	require.Len(t, all, 2)
	assert.Equal(t, "claude", all[0].Provider)
	assert.Len(t, s.Get("CODEX"), 1)
	assert.Empty(t, s.Get("nobody"))

	_, _, err = s.Set(Limits{}, now)
	assert.Error(t, err)
	_, _, err = s.Set(Limits{Provider: "x", Windows: []Window{{UsedPercent: 1}}}, now)
	assert.Error(t, err)
	_, _, err = s.Set(Limits{Provider: "x", Windows: []Window{{ID: "5h", UsedPercent: -1}}}, now)
	assert.Error(t, err)
}

func setWin(t *testing.T, s *LimitsStore, used float64, reset time.Time) []Alert {
	t.Helper()
	_, alerts, err := s.Set(Limits{Provider: "claude", Windows: []Window{{ID: "5h", UsedPercent: used, ResetsAt: reset}}}, at("2026-10-06 10:00"))
	require.NoError(t, err)
	return alerts
}

func TestThresholdsOncePerWindow(t *testing.T) {
	s := NewLimitsStore()
	reset := at("2026-10-06 12:00")
	assert.Empty(t, setWin(t, s, 50, reset))
	a := setWin(t, s, 81, reset)
	require.Len(t, a, 1)
	assert.Equal(t, 80.0, a[0].Threshold)
	assert.Empty(t, setWin(t, s, 85, reset))
	// Reset times jitter by fractions of a second: same window.
	assert.Empty(t, setWin(t, s, 86, reset.Add(300*time.Millisecond)))
	a = setWin(t, s, 92, reset)
	require.Len(t, a, 1)
	assert.Equal(t, 90.0, a[0].Threshold)
	assert.Empty(t, setWin(t, s, 99, reset))

	// The window resets: the next crossing notifies again.
	next := reset.Add(5 * time.Hour)
	assert.Empty(t, setWin(t, s, 5, next))
	a = setWin(t, s, 95, next) // jumps straight past both: one alert, the highest
	require.Len(t, a, 1)
	assert.Equal(t, 90.0, a[0].Threshold)
}

func TestThresholdsWithoutResetTimes(t *testing.T) {
	s := NewLimitsStore()
	require.Len(t, setWin(t, s, 80, time.Time{}), 1)
	assert.Empty(t, setWin(t, s, 82, time.Time{}))
	assert.Empty(t, setWin(t, s, 10, time.Time{})) // dropped back: new window
	assert.Len(t, setWin(t, s, 80, time.Time{}), 1)
}

func TestAlertStatesSurviveRestart(t *testing.T) {
	s := NewLimitsStore()
	reset := at("2026-10-06 12:00")
	require.Len(t, setWin(t, s, 85, reset), 1)
	s2 := NewLimitsStore()
	s2.RestoreAlertStates(s.AlertStates())
	assert.Empty(t, setWin(t, s2, 85, reset))
	assert.Len(t, setWin(t, s2, 91, reset), 1)
}

func TestAlertMessage(t *testing.T) {
	now := at("2026-10-06 10:00")
	sum, body := Alert{Provider: "claude", Window: "5h", Threshold: 80, Used: 81.4, ResetsAt: now.Add(90 * time.Minute)}.Message(now)
	assert.Equal(t, "Claude: 81% of the 5-hour limit used", sum)
	assert.Equal(t, "Resets in 1h 30m", body)
	sum, body = Alert{Provider: "other", Window: "x", Used: 90}.Message(now)
	assert.Equal(t, "other: 90% of the x limit used", sum)
	assert.Empty(t, body)
	assert.Equal(t, "2d 3h", humanDuration(51*time.Hour))
	assert.Equal(t, "less than a minute", humanDuration(time.Second))
}
