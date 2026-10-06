// Package timers is the shell's timer service: named countdown timers
// (Pomodoro as a preset), one stopwatch with laps and wall-clock reminders.
// State is persisted, so timers keep counting by wall clock across daemon
// restarts. This file holds the human time parser shared by the CLI, the
// MCP tools and the QML-facing IPC (`timers.parse`, `timers.quick`).
package timers

import (
	"fmt"
	"strconv"
	"strings"
	"time"
	"unicode"
)

// SpecKind tells a duration ("10m") from a clock time ("18:00").
type SpecKind string

const (
	KindDuration SpecKind = "duration"
	KindClock    SpecKind = "clock"
)

// Spec is a parsed time expression.
type Spec struct {
	Kind     SpecKind      `json:"kind"`
	Duration time.Duration `json:"-"`
	// At is the next occurrence of a clock time (KindClock only).
	At time.Time `json:"-"`
}

// Until returns how long from now the spec ends: the duration itself or
// the time left until the clock time.
func (s Spec) Until(now time.Time) time.Duration {
	if s.Kind == KindClock {
		return s.At.Sub(now)
	}
	return s.Duration
}

// Deadline returns the absolute end of the spec.
func (s Spec) Deadline(now time.Time) time.Time {
	if s.Kind == KindClock {
		return s.At
	}
	return now.Add(s.Duration)
}

var unitScale = map[string]time.Duration{
	"h": time.Hour, "hr": time.Hour, "hrs": time.Hour, "hour": time.Hour, "hours": time.Hour,
	"m": time.Minute, "min": time.Minute, "mins": time.Minute, "minute": time.Minute, "minutes": time.Minute,
	"s": time.Second, "sec": time.Second, "secs": time.Second, "second": time.Second, "seconds": time.Second,
}

// ParseDuration reads a human duration: "10m", "1h30", "1h30m", "90s",
// "1.5h", "2h 15m", "25" (a bare number is minutes) or "1:30:00"
// (h:mm:ss). A trailing bare number after a unit takes the next smaller
// unit ("1h30" = 1h30m, "2m30" = 2m30s). Clock-looking "7:30" is not a
// duration here: use ParseSpec, which treats it as a time of day.
func ParseDuration(s string) (time.Duration, error) {
	in := strings.ToLower(strings.TrimSpace(s))
	if in == "" {
		return 0, fmt.Errorf("empty duration")
	}
	if strings.Count(in, ":") == 2 {
		return parseHMS(in)
	}
	var total time.Duration
	var last time.Duration // unit of the previous token
	rest := in
	for {
		rest = strings.TrimLeft(rest, " ")
		if rest == "" {
			break
		}
		num, after := takeNumber(rest)
		if num == "" {
			return 0, fmt.Errorf("invalid duration %q", s)
		}
		v, err := strconv.ParseFloat(num, 64)
		if err != nil {
			return 0, fmt.Errorf("invalid duration %q", s)
		}
		after = strings.TrimLeft(after, " ")
		unit, tail := takeUnit(after)
		var scale time.Duration
		switch {
		case unit != "":
			sc, ok := unitScale[unit]
			if !ok {
				return 0, fmt.Errorf("unknown unit %q in %q", unit, s)
			}
			scale = sc
		case last == time.Hour:
			scale = time.Minute
		case last == time.Minute:
			scale = time.Second
		case last == 0:
			scale = time.Minute
		default:
			return 0, fmt.Errorf("invalid duration %q", s)
		}
		if last != 0 && scale >= last {
			return 0, fmt.Errorf("units out of order in %q", s)
		}
		total += time.Duration(v * float64(scale))
		last = scale
		rest = tail
	}
	if total <= 0 {
		return 0, fmt.Errorf("duration must be positive: %q", s)
	}
	return total, nil
}

func takeNumber(s string) (string, string) {
	i := 0
	for i < len(s) && (s[i] >= '0' && s[i] <= '9' || s[i] == '.' || s[i] == ',') {
		i++
	}
	return strings.ReplaceAll(s[:i], ",", "."), s[i:]
}

func takeUnit(s string) (string, string) {
	i := 0
	for i < len(s) && unicode.IsLetter(rune(s[i])) {
		i++
	}
	return s[:i], s[i:]
}

func parseHMS(s string) (time.Duration, error) {
	parts := strings.Split(s, ":")
	var n [3]int
	for i, p := range parts {
		v, err := strconv.Atoi(strings.TrimSpace(p))
		if err != nil || v < 0 || (i > 0 && v > 59) {
			return 0, fmt.Errorf("invalid duration %q", s)
		}
		n[i] = v
	}
	d := time.Duration(n[0])*time.Hour + time.Duration(n[1])*time.Minute + time.Duration(n[2])*time.Second
	if d <= 0 {
		return 0, fmt.Errorf("duration must be positive: %q", s)
	}
	return d, nil
}

// ParseClock reads a time of day ("18:00", "7:30", "7:30pm", "7pm",
// "at 9:15") and returns its next occurrence after now (today, or
// tomorrow when it has passed).
func ParseClock(s string, now time.Time) (time.Time, error) {
	in := strings.ToLower(strings.TrimSpace(s))
	in = strings.TrimSpace(strings.TrimPrefix(in, "at "))
	pm, am := strings.HasSuffix(in, "pm"), strings.HasSuffix(in, "am")
	if pm || am {
		in = strings.TrimSpace(in[:len(in)-2])
	}
	hs, ms, hasColon := strings.Cut(in, ":")
	if !hasColon {
		hs, ms, hasColon = strings.Cut(in, ".")
	}
	if !hasColon && !pm && !am {
		return time.Time{}, fmt.Errorf("invalid time of day %q", s)
	}
	h, err := strconv.Atoi(hs)
	if err != nil {
		return time.Time{}, fmt.Errorf("invalid time of day %q", s)
	}
	m := 0
	if hasColon {
		if len(ms) != 2 {
			return time.Time{}, fmt.Errorf("invalid time of day %q", s)
		}
		if m, err = strconv.Atoi(ms); err != nil || m > 59 || m < 0 {
			return time.Time{}, fmt.Errorf("invalid time of day %q", s)
		}
	}
	if pm || am {
		if h < 1 || h > 12 {
			return time.Time{}, fmt.Errorf("invalid time of day %q", s)
		}
		h %= 12
		if pm {
			h += 12
		}
	}
	if h < 0 || h > 23 {
		return time.Time{}, fmt.Errorf("invalid time of day %q", s)
	}
	at := time.Date(now.Year(), now.Month(), now.Day(), h, m, 0, 0, now.Location())
	if !at.After(now) {
		at = at.AddDate(0, 0, 1)
	}
	return at, nil
}

// ParseSpec reads either a clock time ("18:00", "7:30pm", "at 9:00") or a
// duration ("10m", "in 1h30", "25"). "h:mm" with one colon is a clock
// time; durations with seconds use "1:30:00" or units.
func ParseSpec(s string, now time.Time) (Spec, error) {
	in := strings.ToLower(strings.TrimSpace(s))
	if rest, ok := strings.CutPrefix(in, "in "); ok {
		d, err := ParseDuration(rest)
		return Spec{Kind: KindDuration, Duration: d}, err
	}
	if looksLikeClock(in) {
		at, err := ParseClock(in, now)
		if err != nil {
			return Spec{}, err
		}
		return Spec{Kind: KindClock, At: at}, nil
	}
	d, err := ParseDuration(in)
	if err != nil {
		return Spec{}, err
	}
	return Spec{Kind: KindDuration, Duration: d}, nil
}

func looksLikeClock(in string) bool {
	if strings.HasPrefix(in, "at ") || strings.HasSuffix(in, "am") || strings.HasSuffix(in, "pm") {
		return true
	}
	return strings.Count(in, ":") == 1
}

// FormatDuration renders a duration compactly: "1h 30m", "10m", "45s",
// "2m 05s".
func FormatDuration(d time.Duration) string {
	if d < 0 {
		d = 0
	}
	d = d.Round(time.Second)
	h := int(d / time.Hour)
	m := int(d%time.Hour) / int(time.Minute)
	sec := int(d%time.Minute) / int(time.Second)
	switch {
	case h > 0 && m > 0:
		return fmt.Sprintf("%dh %dm", h, m)
	case h > 0:
		return fmt.Sprintf("%dh", h)
	case m > 0 && sec > 0:
		return fmt.Sprintf("%dm %02ds", m, sec)
	case m > 0:
		return fmt.Sprintf("%dm", m)
	}
	return fmt.Sprintf("%ds", sec)
}

// FormatClock renders a countdown as "1:05:09" / "4:59".
func FormatClock(d time.Duration) string {
	if d < 0 {
		d = 0
	}
	sec := int((d + time.Second - 1) / time.Second) // round up: 0.2s left shows 0:01
	h, m, s := sec/3600, sec%3600/60, sec%60
	if h > 0 {
		return fmt.Sprintf("%d:%02d:%02d", h, m, s)
	}
	return fmt.Sprintf("%d:%02d", m, s)
}
