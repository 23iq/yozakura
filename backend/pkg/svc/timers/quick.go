package timers

import (
	"fmt"
	"strings"
	"time"
)

// Intent is what a one-line quick input means. The notch quick input, the
// launcher "t" prefix and `timers.quick` share it.
type Intent struct {
	// Kind: "timer", "reminder", "stopwatch" or "pomodoro".
	Kind    string        `json:"kind"`
	Spec    Spec          `json:"-"`
	Name    string        `json:"name,omitempty"`    // timer name / reminder message
	Work    time.Duration `json:"-"`                 // pomodoro work length (0: default)
	Break   time.Duration `json:"-"`                 // pomodoro break length (0: default)
	Seconds int64         `json:"seconds,omitempty"` // timer length / time left to the reminder
	At      int64         `json:"at,omitempty"`      // reminder: unix ms
	Label   string        `json:"label"`             // human summary ("Timer 10m: tea")
}

// SplitSpec splits "1h 30m pasta" into the longest leading time expression
// and the remaining text. It returns an error when no prefix parses.
func SplitSpec(text string, now time.Time) (Spec, string, error) {
	words := strings.Fields(text)
	if len(words) == 0 {
		return Spec{}, "", fmt.Errorf("empty time")
	}
	limit := len(words)
	if limit > 4 {
		limit = 4
	}
	var firstErr error
	for n := limit; n >= 1; n-- {
		sp, err := ParseSpec(strings.Join(words[:n], " "), now)
		if err == nil {
			return sp, strings.Join(words[n:], " "), nil
		}
		if n == 1 || firstErr == nil {
			firstErr = err
		}
	}
	return Spec{}, "", firstErr
}

// ParseQuick reads a quick input line:
//
//	10m tea | 1h30 | 25          timer (bare number = minutes), rest = name
//	sw | stopwatch               stopwatch toggle
//	pomo [work] [break]          Pomodoro ("pomo 50 10")
//	18:00 call mom | at 7:30     reminder (alarm) at a clock time
//	in 20m stretch               reminder after a duration
//	remind <time|in spec> <text> reminder
func ParseQuick(text string, now time.Time) (Intent, error) {
	words := strings.Fields(strings.TrimSpace(text))
	if len(words) == 0 {
		return Intent{}, fmt.Errorf("nothing to parse")
	}
	head := strings.ToLower(words[0])
	switch head {
	case "sw", "stopwatch":
		return Intent{Kind: "stopwatch", Label: "Stopwatch"}, nil
	case "pomo", "pomodoro":
		it := Intent{Kind: "pomodoro"}
		if len(words) > 1 {
			d, err := ParseDuration(words[1])
			if err != nil {
				return Intent{}, err
			}
			it.Work = d
		}
		if len(words) > 2 {
			d, err := ParseDuration(words[2])
			if err != nil {
				return Intent{}, err
			}
			it.Break = d
		}
		it.Label = "Pomodoro"
		return it, nil
	case "remind", "reminder", "alarm":
		return reminderIntent(strings.Join(words[1:], " "), now)
	}
	lower := strings.ToLower(strings.TrimSpace(text))
	if strings.HasPrefix(lower, "in ") || strings.HasPrefix(lower, "at ") || looksLikeClock(head) {
		return reminderIntent(text, now)
	}
	sp, rest, err := SplitSpec(text, now)
	if err != nil {
		return Intent{}, err
	}
	if sp.Kind == KindClock {
		return reminderIntent(text, now)
	}
	it := Intent{Kind: "timer", Spec: sp, Name: rest, Seconds: int64(sp.Duration / time.Second)}
	it.Label = "Timer " + FormatDuration(sp.Duration)
	if rest != "" {
		it.Label += ": " + rest
	}
	return it, nil
}

func reminderIntent(text string, now time.Time) (Intent, error) {
	sp, rest, err := SplitSpec(text, now)
	if err != nil {
		return Intent{}, err
	}
	at := sp.Deadline(now)
	it := Intent{Kind: "reminder", Spec: sp, Name: rest, At: at.UnixMilli(),
		Seconds: int64(at.Sub(now).Round(time.Second) / time.Second)}
	it.Label = "Reminder at " + at.Format("15:04")
	if rest != "" {
		it.Label += ": " + rest
	}
	return it, nil
}
