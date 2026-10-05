package transfers

import (
	"context"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// browserDownloads: in-progress browser downloads in XDG_DOWNLOAD_DIR.
// Browsers write next to the final name with a suffix (Firefox "x.zip.part",
// Chromium family "x.zip.crdownload", Opera "x.zip.opdownload") and rename
// on completion. Sizes come from stat, the rate from size deltas; browsers
// do not expose the total on disk, so progress is indeterminate unless a
// richer source (notification, JobView) reports the same file. The owning
// browser is resolved once per file from /proc/*/fd.

func init() { register("browserDownloads", func() Source { return newBrowserSource() }) }

var browserSuffixes = map[string]browserInfo{
	".part":       {"Firefox", "firefox"},
	".crdownload": {"Chromium", "chromium"},
	".opdownload": {"Opera", "opera"},
}

type browserInfo struct{ app, icon string }

// Process comm -> browser
var browserByComm = map[string]browserInfo{
	"firefox":       {"Firefox", "firefox"},
	"firefox-bin":   {"Firefox", "firefox"},
	"firefox-esr":   {"Firefox", "firefox"},
	"librewolf":     {"LibreWolf", "librewolf"},
	"floorp":        {"Floorp", "floorp"},
	"zen":           {"Zen Browser", "zen-browser"},
	"zen-bin":       {"Zen Browser", "zen-browser"},
	"waterfox":      {"Waterfox", "waterfox"},
	"chrome":        {"Google Chrome", "google-chrome"},
	"google-chrome": {"Google Chrome", "google-chrome"},
	"chromium":      {"Chromium", "chromium"},
	"brave":         {"Brave", "brave-browser"},
	"brave-browser": {"Brave", "brave-browser"},
	"msedge":        {"Microsoft Edge", "microsoft-edge"},
	"vivaldi-bin":   {"Vivaldi", "vivaldi"},
	"vivaldi":       {"Vivaldi", "vivaldi"},
	"opera":         {"Opera", "opera"},
	"thorium":       {"Thorium", "thorium-browser"},
	"yt-dlp":        {"yt-dlp", "utilities-terminal"},
}

const (
	browserStall     = 10 * time.Second
	browserDoneShown = 4 * time.Second
	ownerAttempts    = 3
)

type partialFile struct {
	meter    RateMeter
	info     browserInfo
	resolved bool
	tries    int
	size     int64
}

type finishedFile struct {
	item Transfer
	at   time.Time
}

type browserSource struct {
	dir      string
	now      func() time.Time
	owners   func([]string) map[string]string
	partials map[string]*partialFile // by partial path
	finished map[string]finishedFile // by partial path
}

func newBrowserSource() *browserSource {
	return &browserSource{
		now:      time.Now,
		owners:   FileOwners,
		partials: map[string]*partialFile{},
		finished: map[string]finishedFile{},
	}
}

func (b *browserSource) Run(ctx context.Context, env *Env) {
	b.dir = DownloadDir(env.Options.DownloadDir)
	var watch *DirWatch
	for {
		_, err := os.Stat(b.dir)
		dirOK := err == nil
		if !dirOK && watch != nil {
			watch.Close() // directory removed: re-arm once it is back
			watch = nil
		}
		if dirOK && watch == nil {
			watch = WatchDir(ctx, b.dir)
		}
		env.Update(b.scan())
		interval := 2 * time.Second
		switch {
		case len(b.partials) > 0 || len(b.finished) > 0:
			interval = time.Second
		case !dirOK:
			interval = 5 * time.Second
		case watch.Events != nil:
			interval = time.Minute // inotify wakes us; this only rechecks the dir
		}
		var wake <-chan struct{}
		if watch != nil {
			wake = watch.Events
		}
		if !sleepOrWake(ctx, interval, wake) {
			return
		}
	}
}

// partialSuffix returns the in-progress suffix of name ("" when none).
func partialSuffix(name string) string {
	for suf := range browserSuffixes {
		if strings.HasSuffix(name, suf) && len(name) > len(suf) {
			return suf
		}
	}
	return ""
}

func (b *browserSource) scan() []Transfer {
	now := b.now()
	seen := map[string]bool{}
	var unresolved []string
	if entries, err := os.ReadDir(b.dir); err == nil {
		for _, e := range entries {
			suf := partialSuffix(e.Name())
			if suf == "" || !e.Type().IsRegular() {
				continue
			}
			path := filepath.Join(b.dir, e.Name())
			size := FileSize(path)
			if size < 0 {
				continue
			}
			seen[path] = true
			p := b.partials[path]
			if p == nil {
				p = &partialFile{info: browserSuffixes[suf]}
				b.partials[path] = p
			}
			p.size = size
			p.meter.Observe(size, now)
			if !p.resolved && p.tries < ownerAttempts {
				unresolved = append(unresolved, path)
			}
		}
	}
	if len(unresolved) > 0 {
		owners := b.owners(unresolved)
		for _, path := range unresolved {
			p := b.partials[path]
			p.tries++
			if info, ok := browserByComm[owners[path]]; ok {
				p.info = info
				p.resolved = true
			} else if owners[path] != "" {
				p.resolved = true // some other app: keep the suffix guess
			}
		}
	}
	// Gone partials: renamed to the final name = done, otherwise cancelled
	for path, p := range b.partials {
		if seen[path] {
			continue
		}
		final := strings.TrimSuffix(path, partialSuffix(path))
		if size := FileSize(final); size > 0 && size >= p.size {
			item := b.item(path, p, now)
			item.State = StateDone
			item.Processed, item.Total, item.Rate = size, size, -1
			b.finished[path] = finishedFile{item: item, at: now}
		}
		delete(b.partials, path)
	}

	var out []Transfer
	for path, p := range b.partials {
		out = append(out, b.item(path, p, now))
	}
	for path, f := range b.finished {
		if now.Sub(f.at) > browserDoneShown {
			delete(b.finished, path)
			continue
		}
		out = append(out, f.item)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Key < out[j].Key })
	return out
}

func (b *browserSource) item(path string, p *partialFile, now time.Time) Transfer {
	final := strings.TrimSuffix(path, partialSuffix(path))
	t := Unknown()
	t.Key = filepath.Base(path)
	t.App, t.AppIcon = p.info.app, p.info.icon
	t.Title = filepath.Base(final)
	t.Path = final
	t.Dir = filepath.Dir(final)
	t.Processed = p.size
	t.Rate = p.meter.Rate()
	t.StartedAt = p.meter.Started().UnixMilli()
	if p.meter.Stalled(now, browserStall) {
		t.State = StatePaused
		t.Detail = "Stalled"
		t.Rate = 0
	}
	return t
}
