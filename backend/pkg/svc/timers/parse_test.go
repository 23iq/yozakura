package timers

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

var t0 = time.Date(2026, 10, 6, 14, 0, 0, 0, time.Local)

func TestParseDuration(t *testing.T) {
	ok := map[string]time.Duration{
		"10m":       10 * time.Minute,
		"1h30":      90 * time.Minute,
		"1h30m":     90 * time.Minute,
		"1h 30m":    90 * time.Minute,
		"90s":       90 * time.Second,
		"25":        25 * time.Minute,
		"2m30":      150 * time.Second,
		"1.5h":      90 * time.Minute,
		"0,5h":      30 * time.Minute,
		"10 min":    10 * time.Minute,
		"2 hours":   2 * time.Hour,
		"1:30:00":   90 * time.Minute,
		"0:00:45":   45 * time.Second,
		"1h2m3s":    time.Hour + 2*time.Minute + 3*time.Second,
		" 5M ":      5 * time.Minute,
		"3 minutes": 3 * time.Minute,
	}
	for in, want := range ok {
		got, err := ParseDuration(in)
		assert.NoError(t, err, in)
		assert.Equal(t, want, got, in)
	}
	for _, bad := range []string{"", "abc", "10x", "0", "m10", "30m1h", "5m5m", "1:61:00", "tea"} {
		_, err := ParseDuration(bad)
		assert.Error(t, err, bad)
	}
}

func TestParseClock(t *testing.T) {
	cases := map[string]time.Time{
		"18:00":   time.Date(2026, 10, 6, 18, 0, 0, 0, time.Local),
		"7:30":    time.Date(2026, 10, 7, 7, 30, 0, 0, time.Local), // passed today: tomorrow
		"7:30pm":  time.Date(2026, 10, 6, 19, 30, 0, 0, time.Local),
		"7pm":     time.Date(2026, 10, 6, 19, 0, 0, 0, time.Local),
		"12am":    time.Date(2026, 10, 7, 0, 0, 0, 0, time.Local),
		"at 9:15": time.Date(2026, 10, 7, 9, 15, 0, 0, time.Local),
		"14:00":   time.Date(2026, 10, 7, 14, 0, 0, 0, time.Local), // exactly now: tomorrow
		"23.45":   time.Date(2026, 10, 6, 23, 45, 0, 0, time.Local),
	}
	for in, want := range cases {
		got, err := ParseClock(in, t0)
		assert.NoError(t, err, in)
		assert.True(t, want.Equal(got), "%s: %v != %v", in, got, want)
	}
	for _, bad := range []string{"25:00", "7:3", "13pm", "18", "ab:cd", "7:60"} {
		_, err := ParseClock(bad, t0)
		assert.Error(t, err, bad)
	}
}

func TestParseSpec(t *testing.T) {
	sp, err := ParseSpec("18:00", t0)
	assert.NoError(t, err)
	assert.Equal(t, KindClock, sp.Kind)
	assert.Equal(t, 4*time.Hour, sp.Until(t0))

	sp, err = ParseSpec("in 20m", t0)
	assert.NoError(t, err)
	assert.Equal(t, KindDuration, sp.Kind)
	assert.Equal(t, t0.Add(20*time.Minute), sp.Deadline(t0))

	sp, err = ParseSpec("1:30:00", t0)
	assert.NoError(t, err)
	assert.Equal(t, KindDuration, sp.Kind)
	assert.Equal(t, 90*time.Minute, sp.Duration)
}

func TestParseQuick(t *testing.T) {
	it, err := ParseQuick("10m tea", t0)
	assert.NoError(t, err)
	assert.Equal(t, "timer", it.Kind)
	assert.Equal(t, "tea", it.Name)
	assert.EqualValues(t, 600, it.Seconds)
	assert.Equal(t, "Timer 10m: tea", it.Label)

	it, err = ParseQuick("1h 30m pasta water", t0)
	assert.NoError(t, err)
	assert.Equal(t, "pasta water", it.Name)
	assert.EqualValues(t, 5400, it.Seconds)

	it, err = ParseQuick("25", t0)
	assert.NoError(t, err)
	assert.Equal(t, "timer", it.Kind)
	assert.EqualValues(t, 1500, it.Seconds)

	for _, sw := range []string{"sw", "Stopwatch"} {
		it, err = ParseQuick(sw, t0)
		assert.NoError(t, err)
		assert.Equal(t, "stopwatch", it.Kind)
	}

	it, err = ParseQuick("pomo 50 10", t0)
	assert.NoError(t, err)
	assert.Equal(t, "pomodoro", it.Kind)
	assert.Equal(t, 50*time.Minute, it.Work)
	assert.Equal(t, 10*time.Minute, it.Break)

	it, err = ParseQuick("18:00 call mom", t0)
	assert.NoError(t, err)
	assert.Equal(t, "reminder", it.Kind)
	assert.Equal(t, "call mom", it.Name)
	assert.Equal(t, time.Date(2026, 10, 6, 18, 0, 0, 0, time.Local).UnixMilli(), it.At)
	assert.Equal(t, "Reminder at 18:00: call mom", it.Label)

	it, err = ParseQuick("in 20m stretch", t0)
	assert.NoError(t, err)
	assert.Equal(t, "reminder", it.Kind)
	assert.Equal(t, "stretch", it.Name)
	assert.EqualValues(t, 1200, it.Seconds)

	it, err = ParseQuick("remind 7:30pm take pills", t0)
	assert.NoError(t, err)
	assert.Equal(t, "take pills", it.Name)

	_, err = ParseQuick("tea", t0)
	assert.Error(t, err)
	_, err = ParseQuick("", t0)
	assert.Error(t, err)
}

func TestFormat(t *testing.T) {
	assert.Equal(t, "1h 30m", FormatDuration(90*time.Minute))
	assert.Equal(t, "2h", FormatDuration(2*time.Hour))
	assert.Equal(t, "2m 05s", FormatDuration(125*time.Second))
	assert.Equal(t, "45s", FormatDuration(45*time.Second))
	assert.Equal(t, "4:59", FormatClock(299*time.Second))
	assert.Equal(t, "1:05:09", FormatClock(time.Hour+5*time.Minute+9*time.Second))
	assert.Equal(t, "0:01", FormatClock(200*time.Millisecond))
}
