package timers

import "time"

// Timer states.
const (
	StateRunning = "running"
	StatePaused  = "paused"
	StateRinging = "ringing" // finished, waiting to be dismissed or snoozed
)

// Stopwatch states.
const (
	SWIdle    = "idle"
	SWRunning = "running"
	SWPaused  = "paused"
)

// Pomodoro phases.
const (
	PhaseWork      = "work"
	PhaseBreak     = "break"
	PhaseLongBreak = "longBreak"
)

// Timer is one countdown. Times are unix milliseconds (wall clock), so a
// running timer keeps counting while the daemon is down.
type Timer struct {
	ID         string    `json:"id"`
	Name       string    `json:"name"`
	State      string    `json:"state"`
	TotalMs    int64     `json:"totalMs"`          // length of the current run, added time included
	EndsAt     int64     `json:"endsAt,omitempty"` // running: when it fires
	LeftMs     int64     `json:"leftMs"`           // paused: frozen time left (views: always filled)
	CreatedAt  int64     `json:"createdAt"`
	FinishedAt int64     `json:"finishedAt,omitempty"` // ringing: when it fired
	Pomodoro   *Pomodoro `json:"pomodoro,omitempty"`
}

// Pomodoro makes a timer cycle work/break phases by itself.
type Pomodoro struct {
	WorkMs      int64  `json:"workMs"`
	BreakMs     int64  `json:"breakMs"`
	LongBreakMs int64  `json:"longBreakMs"`
	Every       int    `json:"every"`  // long break after every N work sessions
	Rounds      int    `json:"rounds"` // work sessions in total; 0 = endless
	Phase       string `json:"phase"`
	Round       int    `json:"round"` // current work session, 1-based
}

// PomodoroConfig are the Pomodoro lengths; zero fields take the defaults.
type PomodoroConfig struct {
	Name      string
	Work      time.Duration
	Break     time.Duration
	LongBreak time.Duration
	Every     int
	Rounds    int
}

// Lap is one stopwatch lap.
type Lap struct {
	N       int   `json:"n"`
	TotalMs int64 `json:"totalMs"` // elapsed at the lap
	SplitMs int64 `json:"splitMs"` // since the previous lap
}

// Stopwatch is the single shell stopwatch.
type Stopwatch struct {
	State     string `json:"state"`
	StartedAt int64  `json:"startedAt,omitempty"` // running: wall ms the current run began
	AccumMs   int64  `json:"accumMs"`             // elapsed before the current run
	ElapsedMs int64  `json:"elapsedMs"`           // views only
	Laps      []Lap  `json:"laps"`
}

// Reminder fires once at a wall-clock time.
type Reminder struct {
	ID        string `json:"id"`
	Message   string `json:"message"`
	At        int64  `json:"at"`
	CreatedAt int64  `json:"createdAt"`
	LeftMs    int64  `json:"leftMs"` // views only
}

// State is everything persisted to timers.json.
type State struct {
	Version   int         `json:"version"`
	NextID    int         `json:"nextId"`
	Timers    []*Timer    `json:"timers"`
	Stopwatch Stopwatch   `json:"stopwatch"`
	Reminders []*Reminder `json:"reminders"`
}

// Event is published when something fires.
type Event struct {
	Kind    string `json:"kind"` // "timer", "pomodoro" or "reminder"
	ID      string `json:"id"`
	Name    string `json:"name,omitempty"`
	Message string `json:"message"` // human sentence for notifications
	// MsgKey/MsgArgs: the translation of Message (shell I18n, %1...);
	// empty when Message is the user's own text.
	MsgKey  string `json:"msgKey,omitempty"`
	MsgArgs []any  `json:"msgArgs,omitempty"`
	Phase   string `json:"phase,omitempty"` // pomodoro: the phase that starts now ("" when done)
	Done    bool   `json:"done"`            // timer rings / pomodoro complete / reminder
	Missed  bool   `json:"missed"`          // fired late (the daemon was not running)
	DueAt   int64  `json:"dueAt"`
}

// View is the snapshot sent to clients (`timers.list`, `timers.state`).
type View struct {
	Now       int64      `json:"now"`
	Timers    []Timer    `json:"timers"`
	Stopwatch Stopwatch  `json:"stopwatch"`
	Reminders []Reminder `json:"reminders"`
	Ringing   int        `json:"ringing"` // timers waiting to be dismissed
	Active    bool       `json:"active"`  // anything running or ringing
}

func ms(d time.Duration) int64 { return int64(d / time.Millisecond) }
