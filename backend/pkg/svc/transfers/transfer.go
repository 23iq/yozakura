// Package transfers aggregates in-flight downloads, copies, updates and syncs
// from many sources (KDE JobView, browser download dirs, Steam, terminal
// downloaders, file operations, package managers, torrent clients, aria2,
// Syncthing, game launchers) and streams them to the shell as one list.
//
// Each source lives in its own file and registers itself in init() with
// register(). Sources only run while the shell enables them
// (transfers.configure), so idle sources cost nothing.
package transfers

// Transfer states.
const (
	StateRunning = "running"
	StatePaused  = "paused"
	StateQueued  = "queued"
	StateDone    = "done"
	StateFailed  = "failed"
)

// UnitsPercent marks Processed/Total as a 0..100 percentage.
const UnitsPercent = "percent"

// Transfer kinds.
const (
	KindDownload = "download"
	KindUpload   = "upload"
	KindCopy     = "copy"
	KindUpdate   = "update"
	KindSync     = "sync"
)

// Actions a source may support (Transfer.Actions).
const (
	ActionCancel  = "cancel"
	ActionSuspend = "suspend"
	ActionResume  = "resume"
)

// Transfer is one item as sent to QML (see modules/services/activities/
// TransferModel.js for the consumer side). Unknown numbers are -1.
type Transfer struct {
	// ID is "<source>:<key>"; filled in by the service from Key.
	ID     string `json:"id"`
	Key    string `json:"-"`
	Source string `json:"source"`
	// App is a human name ("Firefox", "Steam"), AppIcon an icon theme name
	// or absolute path.
	App     string `json:"app"`
	AppIcon string `json:"appIcon"`
	// Title is what is transferred (file name, game, torrent name).
	Title string `json:"title"`
	// Path is the destination file when known (for "open folder" and for
	// de-duplication across sources), Dir its folder.
	Path      string   `json:"path"`
	Dir       string   `json:"dir"`
	Processed int64    `json:"processed"`
	Total     int64    `json:"total"`
	Rate      float64  `json:"rate"` // bytes/s
	State     string   `json:"state"`
	Kind      string   `json:"kind"`
	Detail    string   `json:"detail"`
	Actions   []string `json:"actions"`
	StartedAt int64    `json:"startedAt"` // unix ms
	// URL opened on click instead of the folder (steam://nav/downloads).
	OpenURL string `json:"openUrl,omitempty"`
	// Units of Processed/Total: "" (bytes) or UnitsPercent (0..100) for
	// sources that only know a percentage.
	Units string `json:"units,omitempty"`
}

// Unknown returns a transfer with every numeric field unknown.
func Unknown() Transfer {
	return Transfer{Processed: -1, Total: -1, Rate: -1, State: StateRunning, Kind: KindDownload}
}
