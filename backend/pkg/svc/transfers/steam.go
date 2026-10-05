package transfers

import (
	"context"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
)

// Steam downloads and updates.
//
// Progress comes from steamapps/appmanifest_<appid>.acf in every library
// (BytesDownloaded/BytesToDownload, then BytesStaged/BytesToStage) and the
// state from StateFlags; logs/content_log.txt is tailed for the live state
// ("state changed", "App update changed") and the download rate ("Current
// download rate: N Mbps"). Real Steam files are only ever read.
func init() { register("steam", func() Source { return newSteamSource() }) }

// EAppState bits (StateFlags).
const (
	steamUpdateRequired = 2
	steamFullyInstalled = 4
	steamUpdateRunning  = 256
	steamUpdatePaused   = 512
	steamUpdateStarted  = 1024
	steamPreallocating  = 524288
	steamValidating     = 131072
	steamDownloading    = 1048576
	steamStaging        = 2097152
	steamCommitting     = 4194304
)

// Bits that mean Steam is working on the app right now. UpdateStarted alone
// is a partially downloaded app waiting in the queue.
const steamActiveBits = steamUpdateRunning | steamDownloading | steamStaging |
	steamCommitting | steamPreallocating | steamValidating

const (
	steamPollRunning = 2 * time.Second
	steamPollIdle    = 10 * time.Second
	steamDoneHold    = 5 * time.Second
	// A "Current download rate" line older than this no longer applies
	steamRateMaxAge = 15 * time.Second
	// Steam logs the rate about every 30s; the first log read only looks
	// this far back from the end of the file
	steamLogBacklog = 64 * 1024
)

type steamManifest struct {
	AppID           string
	Name            string
	InstallDir      string
	Library         string // steamapps dir
	Flags           int64
	BytesToDownload int64
	BytesDownloaded int64
	BytesToStage    int64
	BytesStaged     int64
	SizeOnDisk      int64
}

func parseAppManifest(text string) (*steamManifest, error) {
	root, err := parseVDF(text)
	if err != nil {
		return nil, err
	}
	st := root.Child("AppState")
	if st == nil {
		return nil, errNoAppState
	}
	return &steamManifest{
		AppID:           st.Str("appid"),
		Name:            st.Str("name"),
		InstallDir:      st.Str("installdir"),
		Flags:           st.Int("StateFlags"),
		BytesToDownload: st.Int("BytesToDownload"),
		BytesDownloaded: st.Int("BytesDownloaded"),
		BytesToStage:    st.Int("BytesToStage"),
		BytesStaged:     st.Int("BytesStaged"),
		SizeOnDisk:      st.Int("SizeOnDisk"),
	}, nil
}

type steamError string

func (e steamError) Error() string { return string(e) }

const errNoAppState = steamError("appmanifest without AppState")

// parseLibraryFolders returns the library paths listed in libraryfolders.vdf.
func parseLibraryFolders(text string) []string {
	root, err := parseVDF(text)
	if err != nil {
		return nil
	}
	lf := root.Child("libraryfolders")
	if lf == nil {
		lf = root.Child("LibraryFolders")
	}
	var out []string
	for _, c := range lf.Children() {
		if p := c.Str("path"); p != "" {
			out = append(out, p)
		}
	}
	// Old format: "1" "/path"
	if lf != nil {
		for k, v := range lf.values {
			if _, err := strconv.Atoi(k); err == nil && strings.HasPrefix(v, "/") {
				out = append(out, v)
			}
		}
	}
	return out
}

// ── content_log.txt ───────────────────────────────────────────────────

var (
	steamLogLine   = regexp.MustCompile(`^\[(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)\] (.*)$`)
	steamRateLine  = regexp.MustCompile(`^Current download rate: ([\d.]+) Mbps`)
	steamAppLine   = regexp.MustCompile(`^AppID (\d+) (state changed|App update changed|Shader update changed|update started|update canceled) : (.*)$`)
	steamStartLine = regexp.MustCompile(`download (\d+)/(\d+),.*stage (\d+)/(\d+)`)
)

// steamLogState is what the log says about one app.
type steamLogState struct {
	State      map[string]bool // "Update Running", "Update Queued", ...
	Phase      map[string]bool // App update phase: "Downloading", "Staging", ...
	Shader     map[string]bool // Shader update phase
	lastKind   string          // "app" or "shader": which update the next "update started" belongs to
	DownTotal  int64
	StageTotal int64
	ShaderDown int64
	ShaderSeen bool
}

type steamLog struct {
	Apps     map[string]*steamLogState
	Rate     float64 // bytes/s, -1 unknown
	RateAt   time.Time
	location *time.Location
}

func newSteamLog() *steamLog {
	return &steamLog{Apps: map[string]*steamLogState{}, Rate: -1, location: time.Local}
}

func flagSet(list string) map[string]bool {
	out := map[string]bool{}
	// "Fully Installed,Update Queued, (Update delayed for 5 secs)"
	if i := strings.Index(list, "("); i >= 0 {
		list = list[:i]
	}
	for _, f := range strings.Split(list, ",") {
		if f = strings.TrimSpace(f); f != "" && f != "None" {
			out[f] = true
		}
	}
	return out
}

func (l *steamLog) app(id string) *steamLogState {
	a := l.Apps[id]
	if a == nil {
		a = &steamLogState{State: map[string]bool{}, Phase: map[string]bool{}, Shader: map[string]bool{}}
		l.Apps[id] = a
	}
	return a
}

// Feed parses one log line.
func (l *steamLog) Feed(line string) {
	m := steamLogLine.FindStringSubmatch(strings.TrimRight(line, "\r\n "))
	if m == nil {
		return
	}
	at, _ := time.ParseInLocation("2006-01-02 15:04:05", m[1], l.location)
	msg := m[2]
	if r := steamRateLine.FindStringSubmatch(msg); r != nil {
		mbps, _ := strconv.ParseFloat(r[1], 64)
		l.Rate = mbps * 1e6 / 8
		l.RateAt = at
		return
	}
	a := steamAppLine.FindStringSubmatch(msg)
	if a == nil {
		return
	}
	st := l.app(a[1])
	switch a[2] {
	case "state changed":
		st.State = flagSet(a[3])
	case "App update changed":
		st.Phase = flagSet(a[3])
		st.lastKind = "app"
	case "Shader update changed":
		st.Shader = flagSet(a[3])
		st.ShaderSeen = true
		st.lastKind = "shader"
	case "update started":
		if s := steamStartLine.FindStringSubmatch(a[3]); s != nil {
			down, _ := strconv.ParseInt(s[2], 10, 64)
			stage, _ := strconv.ParseInt(s[4], 10, 64)
			if st.lastKind == "shader" {
				st.ShaderDown = down
			} else {
				st.DownTotal, st.StageTotal = down, stage
			}
		}
	case "update canceled":
		st.Phase = map[string]bool{}
	}
}

// tailer follows a growing log file from where it last stopped.
type tailer struct {
	path    string
	offset  int64
	inode   uint64
	primed  bool
	midLine bool // offset may sit inside a line: drop the first one
}

// Read returns the complete new lines since the last call. The first call
// only reads the last steamLogBacklog bytes; truncation or rotation
// restarts from the beginning of the new file.
func (t *tailer) Read() []string {
	f, err := os.Open(t.path)
	if err != nil {
		t.primed, t.offset = false, 0
		return nil
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return nil
	}
	ino, size := fileInode(st), st.Size()
	switch {
	case !t.primed:
		t.primed = true
		t.offset = 0
		if size > steamLogBacklog {
			t.offset = size - steamLogBacklog
			t.midLine = true
		}
	case ino != t.inode || size < t.offset:
		t.offset, t.midLine = 0, false
	}
	t.inode = ino
	if size <= t.offset {
		return nil
	}
	if _, err := f.Seek(t.offset, io.SeekStart); err != nil {
		return nil
	}
	data, err := io.ReadAll(io.LimitReader(f, size-t.offset))
	if err != nil {
		return nil
	}
	// Leave a trailing partial line for the next read
	end := strings.LastIndexByte(string(data), '\n')
	if end < 0 {
		return nil
	}
	t.offset += int64(end + 1)
	lines := strings.Split(string(data[:end]), "\n")
	if t.midLine {
		t.midLine = false
		lines = lines[1:]
	}
	return lines
}

// ── source ────────────────────────────────────────────────────────────

type steamCached struct {
	mod  time.Time
	size int64
	m    *steamManifest
}

type steamSource struct {
	mu         sync.Mutex
	roots      []string
	manifests  map[string]*steamCached // path -> parsed
	logs       map[string]*tailer      // per root
	log        *steamLog
	active     map[string]bool      // appid -> was active at the last scan
	doneAt     map[string]time.Time // appid -> finished
	started    map[string]time.Time // appid -> first seen active
	wasRunning map[string]bool      // appid -> ran during this session
	last       []Transfer
	now        func() time.Time
	running    func() bool
}

func newSteamSource() *steamSource {
	return &steamSource{
		manifests:  map[string]*steamCached{},
		logs:       map[string]*tailer{},
		log:        newSteamLog(),
		active:     map[string]bool{},
		doneAt:     map[string]time.Time{},
		started:    map[string]time.Time{},
		wasRunning: map[string]bool{},
		now:        time.Now,
		running:    func() bool { return ProcRunning("steam", "steamwebhelper") },
	}
}

// steamRoots resolves the Steam installations (symlinks de-duplicated).
func steamRoots(opts Options) []string {
	cands := opts.SteamRoots
	if len(cands) == 0 {
		home, _ := os.UserHomeDir()
		cands = []string{
			filepath.Join(home, ".local/share/Steam"),
			filepath.Join(home, ".steam/steam"),
			filepath.Join(home, ".steam/root"),
			filepath.Join(home, ".var/app/com.valvesoftware.Steam/.local/share/Steam"),
		}
	}
	seen := map[string]bool{}
	var out []string
	for _, c := range cands {
		real, err := filepath.EvalSymlinks(c)
		if err != nil {
			continue
		}
		if st, err := os.Stat(filepath.Join(real, "steamapps")); err != nil || !st.IsDir() {
			continue
		}
		if !seen[real] {
			seen[real] = true
			out = append(out, real)
		}
	}
	return out
}

// libraries lists every steamapps directory of the given roots.
func steamLibraries(roots []string) []string {
	seen := map[string]bool{}
	var out []string
	add := func(dir string) {
		real, err := filepath.EvalSymlinks(dir)
		if err != nil || seen[real] {
			return
		}
		if st, err := os.Stat(real); err == nil && st.IsDir() {
			seen[real] = true
			out = append(out, real)
		}
	}
	for _, r := range roots {
		add(filepath.Join(r, "steamapps"))
		if data, err := os.ReadFile(filepath.Join(r, "steamapps", "libraryfolders.vdf")); err == nil {
			for _, p := range parseLibraryFolders(string(data)) {
				add(filepath.Join(p, "steamapps"))
			}
		}
	}
	return out
}

func (s *steamSource) Run(ctx context.Context, env *Env) {
	s.roots = steamRoots(env.Options)
	if len(s.roots) == 0 {
		return // Steam is not installed
	}
	libs := steamLibraries(s.roots)
	var wakes []<-chan struct{}
	for _, lib := range libs {
		wakes = append(wakes, WatchDir(ctx, lib).Events)
	}
	wake := mergeWakes(ctx, wakes...)
	for {
		items := s.scan(libs)
		if !reflect.DeepEqual(items, s.last) {
			s.last = items
			env.Update(items)
		}
		interval := steamPollIdle
		if len(items) > 0 || s.running() {
			interval = steamPollRunning
		}
		if !sleepOrWake(ctx, interval, wake) {
			return
		}
	}
}

// mergeWakes fans several wake channels (nil ones ignored) into one.
func mergeWakes(ctx context.Context, chans ...<-chan struct{}) <-chan struct{} {
	out := make(chan struct{}, 1)
	n := 0
	for _, c := range chans {
		if c == nil {
			continue
		}
		n++
		go func(c <-chan struct{}) {
			for {
				select {
				case <-ctx.Done():
					return
				case _, ok := <-c:
					if !ok {
						return
					}
					select {
					case out <- struct{}{}:
					default:
					}
				}
			}
		}(c)
	}
	if n == 0 {
		return nil
	}
	return out
}

func (s *steamSource) readLogs() {
	for _, r := range s.roots {
		t := s.logs[r]
		if t == nil {
			t = &tailer{path: filepath.Join(r, "logs", "content_log.txt")}
			s.logs[r] = t
		}
		for _, line := range t.Read() {
			s.log.Feed(line)
		}
	}
}

func (s *steamSource) loadManifests(libs []string) []*steamManifest {
	seen := map[string]bool{}
	var out []*steamManifest
	for _, lib := range libs {
		paths, _ := filepath.Glob(filepath.Join(lib, "appmanifest_*.acf"))
		for _, p := range paths {
			seen[p] = true
			st, err := os.Stat(p)
			if err != nil {
				continue
			}
			c := s.manifests[p]
			if c == nil || !c.mod.Equal(st.ModTime()) || c.size != st.Size() {
				data, err := os.ReadFile(p)
				if err != nil {
					continue
				}
				m, err := parseAppManifest(string(data))
				if err != nil {
					continue // mid-write; keep the old one next time
				}
				m.Library = lib
				c = &steamCached{mod: st.ModTime(), size: st.Size(), m: m}
				s.manifests[p] = c
			}
			out = append(out, c.m)
		}
	}
	for p := range s.manifests {
		if !seen[p] {
			delete(s.manifests, p)
		}
	}
	return out
}

func (s *steamSource) scan(libs []string) []Transfer {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.readLogs()
	now := s.now()
	rate := -1.0
	if s.log.Rate >= 0 && now.Sub(s.log.RateAt) < steamRateMaxAge {
		rate = s.log.Rate
	}
	var all []Transfer
	anyRunning := false
	rateGiven := false
	for _, m := range s.loadManifests(libs) {
		it, ok := s.appItem(m, now)
		if !ok {
			continue
		}
		if it.State == StateRunning {
			anyRunning = true
			s.wasRunning[it.Key] = true
			if !rateGiven && rate >= 0 {
				// Steam downloads one app at a time
				it.Rate = rate
				rateGiven = true
			}
		}
		all = append(all, it)
		if sh, ok := s.shaderItem(m); ok {
			all = append(all, sh)
		}
	}
	// Steam keeps postponed auto-updates and old paused downloads around
	// for days; they are only worth showing next to an active download or
	// when they were running during this session.
	var items []Transfer
	for _, it := range all {
		if (it.State == StatePaused || it.State == StateQueued) && !anyRunning && !s.wasRunning[it.Key] {
			continue
		}
		items = append(items, it)
	}
	return items
}

// appItem decides whether app m is being downloaded and how far it is.
func (s *steamSource) appItem(m *steamManifest, now time.Time) (Transfer, bool) {
	lg := s.log.Apps[m.AppID]
	downloadingDir := false
	if st, err := os.Stat(filepath.Join(m.Library, "downloading", m.AppID)); err == nil && st.IsDir() {
		downloadingDir = true
	}
	partial := m.BytesToDownload > 0 && m.BytesDownloaded > 0 && m.BytesDownloaded < m.BytesToDownload
	partialStage := m.BytesToStage > 0 && m.BytesStaged > 0 && m.BytesStaged < m.BytesToStage

	begun := partial || partialStage || (downloadingDir && m.BytesDownloaded > 0)
	running := m.Flags&steamActiveBits != 0 && m.Flags&steamUpdatePaused == 0
	paused := m.Flags&steamUpdatePaused != 0 && begun
	queued := !running && !paused && m.Flags&steamUpdateStarted != 0 && begun
	if lg != nil && len(lg.State) > 0 {
		// The log is newer than the manifest
		running = lg.State["Update Running"]
		paused = !running && lg.State["Update Paused"] && begun
		queued = !running && !paused && lg.State["Update Started"] && (lg.State["Update Queued"] || begun)
	}
	if !running && !paused && !queued && downloadingDir && partial {
		paused = true
	}

	key := m.AppID
	if running || paused || queued {
		s.active[key] = true
		delete(s.doneAt, key)
		if _, ok := s.started[key]; !ok {
			s.started[key] = now
		}
	} else if s.active[key] {
		// Was downloading, now not: finished if fully installed
		delete(s.active, key)
		if m.Flags&steamFullyInstalled != 0 && m.Flags&steamUpdateRequired == 0 {
			s.doneAt[key] = now
		} else {
			delete(s.started, key)
		}
	}
	doneAt, done := s.doneAt[key]
	if done && now.Sub(doneAt) > steamDoneHold {
		delete(s.doneAt, key)
		delete(s.started, key)
		done = false
	}
	if !running && !paused && !queued && !done {
		return Transfer{}, false
	}

	it := Unknown()
	it.Key = key
	it.App = "Steam"
	it.AppIcon = "steam"
	it.Title = m.Name
	if it.Title == "" {
		it.Title = "App " + m.AppID
	}
	it.OpenURL = "steam://nav/downloads"
	if m.InstallDir != "" {
		it.Path = filepath.Join(m.Library, "common", m.InstallDir)
		it.Dir = it.Path
	}
	it.StartedAt = s.started[key].UnixMilli()
	it.Kind = KindDownload
	if m.Flags&steamFullyInstalled != 0 || m.SizeOnDisk > 0 && m.Flags&steamUpdateRequired != 0 {
		it.Kind = KindUpdate
	}

	downTotal, stageTotal := m.BytesToDownload, m.BytesToStage
	if lg != nil {
		if downTotal <= 0 {
			downTotal = lg.DownTotal
		}
		if stageTotal <= 0 {
			stageTotal = lg.StageTotal
		}
	}
	phase := map[string]bool{}
	if lg != nil {
		phase = lg.Phase
	}
	switch {
	case done:
		it.State = StateDone
		it.Detail = "Installed"
		if downTotal > 0 {
			it.Processed, it.Total = downTotal, downTotal
		}
		return it, true
	case m.Flags&steamValidating != 0 || phase["Validating"]:
		it.Detail = "Validating"
	case downTotal > 0 && m.BytesDownloaded < downTotal:
		it.Detail = "Downloading"
		it.Processed, it.Total = m.BytesDownloaded, downTotal
	case stageTotal > 0 && m.BytesStaged < stageTotal:
		it.Detail = "Installing"
		it.Processed, it.Total = m.BytesStaged, stageTotal
	case phase["Committing"] || m.Flags&steamCommitting != 0:
		it.Detail = "Installing"
		if stageTotal > 0 {
			it.Processed, it.Total = stageTotal, stageTotal
		}
	default:
		it.Detail = "Downloading"
		if downTotal > 0 {
			it.Processed, it.Total = m.BytesDownloaded, downTotal
		}
	}
	switch {
	case paused:
		it.State = StatePaused
		it.Detail = "Paused"
	case queued:
		it.State = StateQueued
		it.Detail = "Queued"
	}
	return it, true
}

// shaderItem reports a running shader pre-cache download (secondary item).
func (s *steamSource) shaderItem(m *steamManifest) (Transfer, bool) {
	lg := s.log.Apps[m.AppID]
	if lg == nil || !lg.Shader["Running Update"] || !(lg.Shader["Downloading"] || lg.Shader["Staging"]) {
		return Transfer{}, false
	}
	it := Unknown()
	it.Key = "shader:" + m.AppID
	it.App = "Steam"
	it.AppIcon = "steam"
	it.Title = m.Name + " shaders"
	it.Kind = KindUpdate
	it.Detail = "Shader pre-caching"
	it.OpenURL = "steam://nav/downloads"
	if lg.ShaderDown > 0 {
		it.Total = lg.ShaderDown
	}
	return it, true
}
