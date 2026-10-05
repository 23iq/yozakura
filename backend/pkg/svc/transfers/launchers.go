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
	"time"
)

// Game launchers, best effort:
//   - Heroic (Epic/GOG/Amazon): its helpers legendary, gogdl and nile run
//     with an install/update/repair subcommand while downloading. Progress
//     comes from the newest Heroic log ("Progress for <game>: 12.34%/...")
//     or the helpers' own progress lines when they are logged; otherwise the
//     item is indeterminate.
//   - Lutris: a running "lutris lutris:install/<slug>" (or -i/--install)
//     is shown as an indeterminate installer.
func init() { register("launchers", func() Source { return newLaunchersSource() }) }

const (
	launcherPollEvery = 2 * time.Second
	launcherIdleEvery = 5 * time.Second
	// A log not written for this long holds no current progress
	launcherLogFresh = 30 * time.Second
	launcherLogTail  = 32 * 1024
)

var launcherHelpers = map[string]struct {
	store string
	subs  []string
}{
	"legendary": {"Epic Games", []string{"install", "update", "repair", "download", "verify"}},
	"gogdl":     {"GOG", []string{"download", "update", "repair"}},
	"nile":      {"Amazon Games", []string{"install", "update", "verify"}},
}

// heroicProgress is the latest progress seen in a log.
type heroicProgress struct {
	Title      string
	Percent    float64 // -1 unknown
	Downloaded int64   // bytes, -1 unknown
	Total      int64   // bytes, -1 unknown
	Rate       float64 // bytes/s, -1 unknown
}

const mib = 1024 * 1024

var (
	// Heroic: "Progress for Hades: 12.34%/123.45MiB/00:01:20 Down: 12.34MB/s / Disk: 23.45MB/s"
	heroicLine = regexp.MustCompile(`Progress for (.+?):\s+([\d.]+)%/([\d.]+)MiB/\S*\s+Down:\s+([\d.]+)MB/s`)
	// legendary/gogdl/nile: "= Progress: 12.34% (1234/9999), Running for ..." (gogdl omits the %)
	helperProgress = regexp.MustCompile(`= Progress: ([\d.]+)%?\s`)
	helperDone     = regexp.MustCompile(`[-=] Downloaded: ([\d.]+) MiB`)
	helperRate     = regexp.MustCompile(`\+ Download\s+-\s+([\d.]+) MiB/s`)
	helperSize     = regexp.MustCompile(`Download size: ([\d.]+) MiB`)
)

// parseLauncherLog scans log text for the newest progress information.
func parseLauncherLog(text string) (heroicProgress, bool) {
	p := heroicProgress{Percent: -1, Downloaded: -1, Total: -1, Rate: -1}
	found := false
	for _, line := range strings.Split(text, "\n") {
		if m := heroicLine.FindStringSubmatch(line); m != nil {
			p.Title = strings.TrimSpace(m[1])
			p.Percent, _ = strconv.ParseFloat(m[2], 64)
			d, _ := strconv.ParseFloat(m[3], 64)
			p.Downloaded = int64(d * mib)
			r, _ := strconv.ParseFloat(m[4], 64)
			p.Rate = r * mib
			found = true
			continue
		}
		if m := helperSize.FindStringSubmatch(line); m != nil {
			v, _ := strconv.ParseFloat(m[1], 64)
			p.Total = int64(v * mib)
		}
		if m := helperProgress.FindStringSubmatch(line); m != nil {
			p.Percent, _ = strconv.ParseFloat(m[1], 64)
			found = true
		}
		if m := helperDone.FindStringSubmatch(line); m != nil {
			v, _ := strconv.ParseFloat(m[1], 64)
			p.Downloaded = int64(v * mib)
		}
		if m := helperRate.FindStringSubmatch(line); m != nil {
			v, _ := strconv.ParseFloat(m[1], 64)
			p.Rate = v * mib
		}
	}
	if found && p.Total < 0 && p.Percent > 0 && p.Downloaded > 0 {
		p.Total = int64(float64(p.Downloaded) / (p.Percent / 100))
	}
	return p, found
}

type launchersSource struct {
	listProc func() []Proc
	logDirs  []string
	now      func() time.Time
	started  map[string]time.Time
}

func newLaunchersSource() *launchersSource {
	home, _ := os.UserHomeDir()
	cfg := os.Getenv("XDG_CONFIG_HOME")
	if cfg == "" {
		cfg = filepath.Join(home, ".config")
	}
	return &launchersSource{
		listProc: func() []Proc {
			return ListProcs(func(c string) bool { _, ok := launcherHelpers[c]; return ok || c == "lutris" })
		},
		logDirs: []string{
			filepath.Join(cfg, "heroic", "logs"),
			filepath.Join(home, ".var/app/com.heroicgameslauncher.hgl/config/heroic/logs"),
		},
		now:     time.Now,
		started: map[string]time.Time{},
	}
}

func (s *launchersSource) Run(ctx context.Context, env *Env) {
	var last []Transfer
	for {
		items := s.scan()
		if !reflect.DeepEqual(items, last) {
			last = items
			env.Update(items)
		}
		wait := launcherIdleEvery
		if len(items) > 0 {
			wait = launcherPollEvery
		}
		if !sleepOrWake(ctx, wait, nil) {
			return
		}
	}
}

// helperJob returns the subcommand and game id of a helper invocation that
// downloads, or ok=false (launching a game, listing, auth...).
func helperJob(p Proc) (sub, game string, ok bool) {
	h, known := launcherHelpers[p.Comm]
	if !known {
		return "", "", false
	}
	for i, a := range p.Args {
		for _, s := range h.subs {
			if a == s {
				for _, rest := range p.Args[i+1:] {
					if !strings.HasPrefix(rest, "-") {
						return s, rest, true
					}
				}
				return s, "", true
			}
		}
	}
	return "", "", false
}

func lutrisJob(p Proc) (string, bool) {
	if p.Comm != "lutris" {
		return "", false
	}
	for i, a := range p.Args {
		if slug, ok := strings.CutPrefix(a, "lutris:install/"); ok {
			return slug, true
		}
		if (a == "-i" || a == "--install") && i+1 < len(p.Args) {
			return strings.TrimSuffix(filepath.Base(p.Args[i+1]), filepath.Ext(p.Args[i+1])), true
		}
	}
	return "", false
}

// freshLog returns the tail of the newest .log written recently.
func (s *launchersSource) freshLog() string {
	var newest string
	var newestMod time.Time
	for _, dir := range s.logDirs {
		filepath.WalkDir(dir, func(path string, d os.DirEntry, err error) error {
			if err != nil {
				return nil
			}
			if d.IsDir() && strings.Count(strings.TrimPrefix(path, dir), "/") > 3 {
				return filepath.SkipDir
			}
			if d.IsDir() || !strings.HasSuffix(path, ".log") {
				return nil
			}
			if info, err := d.Info(); err == nil && info.ModTime().After(newestMod) {
				newest, newestMod = path, info.ModTime()
			}
			return nil
		})
	}
	if newest == "" || s.now().Sub(newestMod) > launcherLogFresh {
		return ""
	}
	f, err := os.Open(newest)
	if err != nil {
		return ""
	}
	defer f.Close()
	if st, err := f.Stat(); err == nil && st.Size() > launcherLogTail {
		f.Seek(st.Size()-launcherLogTail, io.SeekStart)
	}
	data, _ := io.ReadAll(f)
	return string(data)
}

func (s *launchersSource) scan() []Transfer {
	now := s.now()
	var items []Transfer
	seen := map[string]bool{}
	var progress heroicProgress
	var haveProgress, logRead bool
	for _, p := range s.listProc() {
		key := ""
		it := Unknown()
		if sub, game, ok := helperJob(p); ok {
			if !logRead {
				logRead = true
				progress, haveProgress = parseLauncherLog(s.freshLog())
			}
			key = p.Comm + ":" + game
			it.App = "Heroic"
			it.AppIcon = "heroic"
			it.Title = game
			it.Detail = launcherHelpers[p.Comm].store
			if sub == "update" {
				it.Kind = KindUpdate
			}
			if sub == "repair" || sub == "verify" {
				it.Kind, it.Detail = KindUpdate, "Verifying"
			}
			if haveProgress {
				if progress.Title != "" {
					it.Title = progress.Title
				}
				if progress.Total > 0 {
					it.Total = progress.Total
					it.Processed = progress.Downloaded
					if it.Processed < 0 && progress.Percent >= 0 {
						it.Processed = int64(progress.Percent / 100 * float64(progress.Total))
					}
				}
				it.Rate = progress.Rate
			}
		} else if slug, ok := lutrisJob(p); ok {
			key = "lutris:" + slug
			it.App = "Lutris"
			it.AppIcon = "lutris"
			it.Title = slug
			it.Detail = "Installer"
		} else {
			continue
		}
		if seen[key] {
			continue // child processes of the same job
		}
		seen[key] = true
		if it.Title == "" {
			it.Title = it.App
		}
		if _, ok := s.started[key]; !ok {
			s.started[key] = now
		}
		it.Key = key
		it.StartedAt = s.started[key].UnixMilli()
		items = append(items, it)
	}
	for k := range s.started {
		if !seen[k] {
			delete(s.started, k)
		}
	}
	return items
}
