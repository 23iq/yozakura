package timers

import (
	"encoding/json"
	"errors"
	"os"
	"time"

	"yozakura/backend/pkg/fsutil"
)

// FileName is the state file under the app data dir.
const FileName = "timers.json"

// Load reads the persisted state; a missing file is an empty state. A
// corrupt file is reported, and the caller starts empty.
func Load(path string) (*State, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return &State{}, nil
	}
	if err != nil {
		return &State{}, err
	}
	var st State
	if err := json.Unmarshal(data, &st); err != nil {
		return &State{}, err
	}
	return &st, nil
}

// Save writes the state atomically.
func Save(path string, st State) error {
	if st.Timers == nil {
		st.Timers = []*Timer{}
	}
	if st.Reminders == nil {
		st.Reminders = []*Reminder{}
	}
	if st.Stopwatch.Laps == nil {
		st.Stopwatch.Laps = []Lap{}
	}
	data, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		return err
	}
	return fsutil.WriteFile(path, append(data, '\n'), 0o644)
}

// SystemPomodoro reads the Pomodoro lengths of the shell config
// (system.pomodoro.workTime / restTime, in seconds) from the system domain
// file. Missing values stay zero (the engine defaults).
func SystemPomodoro(systemFile string) PomodoroConfig {
	var doc struct {
		Pomodoro struct {
			WorkTime float64 `json:"workTime"`
			RestTime float64 `json:"restTime"`
		} `json:"pomodoro"`
	}
	data, err := os.ReadFile(systemFile)
	if err != nil || json.Unmarshal(data, &doc) != nil {
		return PomodoroConfig{}
	}
	return PomodoroConfig{
		Work:  time.Duration(doc.Pomodoro.WorkTime * float64(time.Second)),
		Break: time.Duration(doc.Pomodoro.RestTime * float64(time.Second)),
	}
}
