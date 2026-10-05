package transfers

import (
	"context"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

// terminal: command-line downloaders (curl, wget, aria2c, yt-dlp,
// gallery-dl, axel...). Each process's largest regular file opened for
// writing is the download; its size growth gives bytes and rate. Totals are
// unknown (the tools only print them to their terminal), so progress is
// indeterminate. yt-dlp's "*.part" names are shown without the suffix.

func init() {
	register("terminal", func() Source { return newProcSource(terminalTools, terminalPick) })
}

var terminalTools = map[string]string{
	"curl":       "curl",
	"wget":       "wget",
	"wget2":      "wget2",
	"aria2c":     "aria2",
	"yt-dlp":     "yt-dlp",
	"youtube-dl": "youtube-dl",
	"gallery-dl": "gallery-dl",
	"axel":       "axel",
	"lftp":       "lftp",
	"megadl":     "megadl",
	"spotdl":     "spotdl",
}

// Side files that are never the payload
var terminalSideFile = []string{".ytdl", ".aria2", ".log", ".json", ".tmp-journal"}

// terminalPick chooses the payload: the largest writable regular file.
func terminalPick(p Proc, fds []FD) *procPick {
	var best *FD
	bestSize := int64(-1)
	for i := range fds {
		fd := fds[i]
		if !fd.Writable() || hasAnySuffix(fd.Target, terminalSideFile) {
			continue
		}
		if size := FileSize(fd.Target); size > bestSize {
			best, bestSize = &fds[i], size
		}
	}
	if best == nil {
		return nil
	}
	final := strings.TrimSuffix(best.Target, ".part")
	return &procPick{
		key:       strconv.Itoa(p.PID) + ":" + filepath.Base(best.Target),
		title:     filepath.Base(final),
		path:      final,
		processed: bestSize,
		total:     -1,
		kind:      KindDownload,
		app:       terminalTools[p.Comm],
		icon:      "utilities-terminal",
	}
}

func hasAnySuffix(s string, suffixes []string) bool {
	for _, suf := range suffixes {
		if strings.HasSuffix(s, suf) {
			return true
		}
	}
	return false
}

// ── shared engine for per-process sources (terminal, fileOps) ─────────

// procPick is what a source extracts from one process.
type procPick struct {
	key, title, path, detail, app, icon, kind string
	processed, total                          int64
}

type tracked struct {
	pick  procPick
	meter RateMeter
	seen  time.Time
}

type procSource struct {
	tools    map[string]string
	pick     func(Proc, []FD) *procPick
	now      func() time.Time
	maxAge   time.Duration
	items    map[string]*tracked
	finished map[string]finishedFile
}

func newProcSource(tools map[string]string, pick func(Proc, []FD) *procPick) *procSource {
	return &procSource{
		tools:    tools,
		pick:     pick,
		now:      time.Now,
		maxAge:   activeSampling / 2,
		items:    map[string]*tracked{},
		finished: map[string]finishedFile{},
	}
}

func (s *procSource) Run(ctx context.Context, env *Env) {
	for {
		env.Update(s.scan())
		interval := idleDiscovery
		if len(s.items) > 0 || len(s.finished) > 0 {
			interval = activeSampling
		}
		if !sleepOrWake(ctx, interval, nil) {
			return
		}
	}
}

func (s *procSource) names() map[string]bool {
	out := map[string]bool{}
	for k := range s.tools {
		out[k] = true
	}
	return out
}

func (s *procSource) scan() []Transfer {
	now := s.now()
	live := map[string]bool{}
	for _, p := range procsNamed(s.maxAge, s.names()) {
		if !OwnedByMe(p.PID) {
			continue
		}
		pick := s.pick(p, ListFDs(p.PID, true))
		if pick == nil {
			continue
		}
		live[pick.key] = true
		t := s.items[pick.key]
		if t == nil {
			t = &tracked{}
			s.items[pick.key] = t
		}
		t.pick = *pick
		t.seen = now
		t.meter.Observe(pick.processed, now)
	}
	for key, t := range s.items {
		if live[key] {
			continue
		}
		// Process gone: finished if it was still moving and (when the total
		// is known) nearly complete; otherwise it was cancelled or failed.
		complete := t.pick.total <= 0 || t.pick.processed*100 >= t.pick.total*99
		if complete && t.meter.Rate() > 0 && !t.meter.Stalled(now, 5*time.Second) {
			item := s.item(key, t, now)
			item.State = StateDone
			item.Rate = -1
			if item.Total <= 0 {
				item.Total = item.Processed
			} else {
				item.Processed = item.Total
			}
			s.finished[key] = finishedFile{item: item, at: now}
		}
		delete(s.items, key)
	}
	var out []Transfer
	for key, t := range s.items {
		out = append(out, s.item(key, t, now))
	}
	for key, f := range s.finished {
		if now.Sub(f.at) > browserDoneShown {
			delete(s.finished, key)
			continue
		}
		out = append(out, f.item)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Key < out[j].Key })
	return out
}

func (s *procSource) item(key string, t *tracked, now time.Time) Transfer {
	it := Unknown()
	it.Key = key
	it.App, it.AppIcon = t.pick.app, t.pick.icon
	it.Title, it.Path, it.Detail = t.pick.title, t.pick.path, t.pick.detail
	if it.Path != "" {
		it.Dir = filepath.Dir(it.Path)
	}
	it.Kind = t.pick.kind
	it.Processed, it.Total = t.pick.processed, t.pick.total
	it.Rate = t.meter.Rate()
	it.StartedAt = t.meter.Started().UnixMilli()
	if t.meter.Stalled(now, browserStall) {
		it.State = StatePaused
		if it.Detail == "" {
			it.Detail = "Stalled"
		} else {
			it.Detail += " (stalled)"
		}
		it.Rate = 0
	}
	return it
}
