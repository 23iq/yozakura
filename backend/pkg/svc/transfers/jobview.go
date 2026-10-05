package transfers

import (
	"bufio"
	"context"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/godbus/dbus/v5"
)

// jobView: KDE's job tracking server, the protocol KIO (Dolphin copies and
// moves, Ark, KGet, Plasma browser integration, anything using KJobWidgets)
// reports progress through. Outside Plasma nothing owns the bus name, so we
// do: org.kde.JobViewServer (+ the legacy org.kde.kuiserver name) at
// /JobViewServer, implementing org.kde.JobViewServer (requestView ->
// org.kde.JobViewV2 objects) and org.kde.JobViewServerV2 (requestView with
// a desktop entry and hints -> org.kde.JobViewV3, a single update(a{sv})).
// When Plasma (or kuiserver) already owns the name the source stays idle.

func init() { register("jobView", func() Source { return newJobViewSource() }) }

const (
	jobViewServerName = "org.kde.JobViewServer"
	jobViewLegacyName = "org.kde.kuiserver"
	jobViewServerPath = dbus.ObjectPath("/JobViewServer")
	ifaceServerV1     = "org.kde.JobViewServer"
	ifaceServerV2     = "org.kde.JobViewServerV2"
	ifaceViewV2       = "org.kde.JobViewV2"
	ifaceViewV3       = "org.kde.JobViewV3"
	ifaceIntrospect   = "org.freedesktop.DBus.Introspectable"

	// KJob::Capabilities
	capKillable    = 1
	capSuspendable = 2

	jobDoneShown = 4 * time.Second
)

// jobViewConnect opens a private, authenticated session bus connection
// (replaced by tests with a private daemon). SessionBusPrivate would skip
// Auth/Hello, making RequestName fail.
var jobViewConnect = func() (*dbus.Conn, error) { return dbus.ConnectSessionBus() }

type jobState struct {
	path       dbus.ObjectPath
	iface      string // ifaceViewV2 or ifaceViewV3
	app, icon  string
	caps       int32
	title      string // V3 "title" / V1 info message
	info       string
	fields     map[uint32][2]string // number -> (label, value)
	dest       string
	processed  int64
	total      int64
	percent    int64
	speed      float64
	suspended  bool
	terminated bool
	failed     bool
	errorMsg   string
	started    time.Time
	finishedAt time.Time
}

type jobViewSource struct {
	mu     sync.Mutex
	conn   *dbus.Conn
	jobs   map[string]*jobState // key "job<N>"
	next   int
	now    func() time.Time
	notify func()
}

func newJobViewSource() *jobViewSource {
	return &jobViewSource{jobs: map[string]*jobState{}, now: time.Now, notify: func() {}}
}

func (s *jobViewSource) Run(ctx context.Context, env *Env) {
	conn, err := jobViewConnect()
	if err != nil {
		return
	}
	defer conn.Close()
	s.mu.Lock()
	s.conn = conn
	s.notify = func() { env.Update(s.items()) }
	s.mu.Unlock()

	if err := s.exportServer(conn); err != nil {
		return
	}
	reply, err := conn.RequestName(jobViewServerName, dbus.NameFlagDoNotQueue)
	if err != nil || reply != dbus.RequestNameReplyPrimaryOwner {
		return // Plasma or kuiserver tracks jobs already
	}
	defer conn.ReleaseName(jobViewServerName)
	if r, err := conn.RequestName(jobViewLegacyName, dbus.NameFlagDoNotQueue); err == nil && r == dbus.RequestNameReplyPrimaryOwner {
		defer conn.ReleaseName(jobViewLegacyName)
	}

	// Terminated jobs are removed once they have been shown
	for sleepOrWake(ctx, time.Second, nil) {
		if s.prune() {
			env.Update(s.items())
		}
	}
}

func (s *jobViewSource) exportServer(conn *dbus.Conn) error {
	v1 := map[string]any{
		"requestView": func(appName, appIcon string, caps int32) (dbus.ObjectPath, *dbus.Error) {
			return s.newView(ifaceViewV2, appName, appIcon, caps, nil), nil
		},
	}
	v2 := map[string]any{
		"requestView": func(desktopEntry string, caps int32, hints map[string]dbus.Variant) (dbus.ObjectPath, *dbus.Error) {
			name, icon := desktopEntryInfo(desktopEntry)
			return s.newView(ifaceViewV3, name, icon, caps, hints), nil
		},
	}
	intro := map[string]any{
		"Introspect": func() (string, *dbus.Error) { return jobViewServerXML, nil },
	}
	if err := conn.ExportMethodTable(v1, jobViewServerPath, ifaceServerV1); err != nil {
		return err
	}
	if err := conn.ExportMethodTable(v2, jobViewServerPath, ifaceServerV2); err != nil {
		return err
	}
	return conn.ExportMethodTable(intro, jobViewServerPath, ifaceIntrospect)
}

func (s *jobViewSource) newView(iface, app, icon string, caps int32, hints map[string]dbus.Variant) dbus.ObjectPath {
	s.mu.Lock()
	s.next++
	key := fmt.Sprintf("job%d", s.next)
	path := dbus.ObjectPath(fmt.Sprintf("/JobViewServer/JobView_%d", s.next))
	j := &jobState{path: path, iface: iface, app: app, icon: icon, caps: caps,
		fields: map[uint32][2]string{}, processed: -1, total: -1, percent: -1, speed: -1, started: s.now()}
	s.jobs[key] = j
	conn := s.conn
	s.mu.Unlock()
	if len(hints) > 0 {
		s.apply(key, hints)
	}
	if conn != nil {
		if iface == ifaceViewV2 {
			conn.ExportMethodTable(s.viewV2Methods(key), path, ifaceViewV2)
		} else {
			conn.ExportMethodTable(s.viewV3Methods(key), path, ifaceViewV3)
		}
		conn.ExportMethodTable(map[string]any{
			"Introspect": func() (string, *dbus.Error) {
				if iface == ifaceViewV2 {
					return jobViewV2XML, nil
				}
				return jobViewV3XML, nil
			},
		}, path, ifaceIntrospect)
	}
	s.notify()
	return path
}

// with runs f on a job under the lock and publishes the change.
func (s *jobViewSource) with(key string, f func(j *jobState)) *dbus.Error {
	s.mu.Lock()
	j := s.jobs[key]
	if j != nil && !j.terminated {
		f(j)
	}
	s.mu.Unlock()
	s.notify()
	return nil
}

func (s *jobViewSource) viewV2Methods(key string) map[string]any {
	return map[string]any{
		"terminate": func(msg string) *dbus.Error {
			return s.with(key, func(j *jobState) { s.terminate(j, msg != "", msg) })
		},
		"setSuspended": func(b bool) *dbus.Error {
			return s.with(key, func(j *jobState) { j.suspended = b })
		},
		"setTotalAmount": func(amount uint64, unit string) *dbus.Error {
			return s.with(key, func(j *jobState) {
				if unit == "bytes" {
					j.total = int64(amount)
				}
			})
		},
		"setProcessedAmount": func(amount uint64, unit string) *dbus.Error {
			return s.with(key, func(j *jobState) {
				if unit == "bytes" {
					j.processed = int64(amount)
				}
			})
		},
		"setPercent": func(p uint32) *dbus.Error {
			return s.with(key, func(j *jobState) { j.percent = int64(p) })
		},
		"setSpeed": func(bps uint64) *dbus.Error {
			return s.with(key, func(j *jobState) { j.speed = float64(bps) })
		},
		"setInfoMessage": func(msg string) *dbus.Error {
			return s.with(key, func(j *jobState) { j.info = msg })
		},
		"setDescriptionField": func(n uint32, name, value string) (bool, *dbus.Error) {
			s.with(key, func(j *jobState) { j.fields[n] = [2]string{name, value} })
			return true, nil
		},
		"clearDescriptionField": func(n uint32) *dbus.Error {
			return s.with(key, func(j *jobState) { delete(j.fields, n) })
		},
		"setDestUrl": func(v dbus.Variant) *dbus.Error {
			return s.with(key, func(j *jobState) { j.dest = variantString(v) })
		},
		"setError": func(code uint32) *dbus.Error {
			return s.with(key, func(j *jobState) {
				if code != 0 {
					j.failed = true
				}
			})
		},
	}
}

func (s *jobViewSource) viewV3Methods(key string) map[string]any {
	return map[string]any{
		"terminate": func(code uint32, msg string, hints map[string]dbus.Variant) *dbus.Error {
			s.apply(key, hints)
			return s.with(key, func(j *jobState) { s.terminate(j, code != 0 || msg != "", msg) })
		},
		"update": func(data map[string]dbus.Variant) *dbus.Error {
			s.apply(key, data)
			return nil
		},
	}
}

func (s *jobViewSource) terminate(j *jobState, failed bool, msg string) {
	j.terminated = true
	j.failed = j.failed || failed
	j.errorMsg = msg
	j.finishedAt = s.now()
}

// apply merges a JobViewV3 update / requestView hints map.
func (s *jobViewSource) apply(key string, data map[string]dbus.Variant) {
	s.with(key, func(j *jobState) {
		for k, v := range data {
			switch k {
			case "title":
				j.title = variantString(v)
			case "infoMessage":
				j.info = variantString(v)
			case "descriptionLabel1", "descriptionValue1", "descriptionLabel2", "descriptionValue2":
				n := uint32(0)
				if strings.HasSuffix(k, "2") {
					n = 1
				}
				f := j.fields[n]
				if strings.HasPrefix(k, "descriptionLabel") {
					f[0] = variantString(v)
				} else {
					f[1] = variantString(v)
				}
				j.fields[n] = f
			case "totalBytes":
				j.total = variantInt(v)
			case "processedBytes":
				j.processed = variantInt(v)
			case "percent":
				j.percent = variantInt(v)
			case "speed":
				j.speed = float64(variantInt(v))
			case "suspended":
				if b, ok := v.Value().(bool); ok {
					j.suspended = b
				}
			case "destUrl":
				j.dest = variantString(v)
			}
		}
	})
}

// prune drops jobs shown as finished long enough; reports a change.
func (s *jobViewSource) prune() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	changed := false
	now := s.now()
	for key, j := range s.jobs {
		if j.terminated && now.Sub(j.finishedAt) > jobDoneShown {
			delete(s.jobs, key)
			if s.conn != nil {
				s.conn.ExportMethodTable(nil, j.path, j.iface)
				s.conn.ExportMethodTable(nil, j.path, ifaceIntrospect)
			}
			changed = true
		}
	}
	return changed
}

func (s *jobViewSource) items() []Transfer {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]Transfer, 0, len(s.jobs))
	for key, j := range s.jobs {
		out = append(out, j.transfer(key))
	}
	sort.Slice(out, func(i, k int) bool {
		return out[i].StartedAt < out[k].StartedAt || (out[i].StartedAt == out[k].StartedAt && out[i].Key < out[k].Key)
	})
	return out
}

func (j *jobState) transfer(key string) Transfer {
	t := Unknown()
	t.Key = key
	t.App, t.AppIcon = j.app, j.icon
	if t.AppIcon == "" {
		t.AppIcon = "system-file-manager"
	}
	src, dst := "", ""
	for _, f := range j.fields {
		switch strings.ToLower(f[0]) {
		case "source", "from":
			src = f[1]
		case "destination", "to":
			dst = f[1]
		}
	}
	dest := j.dest
	if dest == "" {
		dest = dst
	}
	if p := localPath(dest); p != "" {
		t.Path = p
		t.Dir = filepath.Dir(p)
		if strings.HasSuffix(dest, "/") {
			t.Dir = p
		}
	}
	switch {
	case src != "":
		t.Title = urlBase(src)
	case dst != "":
		t.Title = urlBase(dst)
	case j.title != "":
		t.Title = j.title
	case j.info != "":
		t.Title = j.info
	default:
		t.Title = j.app
	}
	t.Detail = j.title
	if j.info != "" && j.info != t.Title {
		t.Detail = j.info
	}
	if j.processed >= 0 && j.total > 0 {
		t.Processed, t.Total = j.processed, j.total
	} else if j.percent >= 0 {
		// Percent-only clients (KGet, browser integration)
		t.Processed, t.Total, t.Units = j.percent, 100, UnitsPercent
	} else if j.processed >= 0 {
		t.Processed = j.processed
	}
	t.Rate = j.speed
	t.Kind = jobKind(j)
	t.StartedAt = j.started.UnixMilli()
	switch {
	case j.terminated && j.failed:
		t.State = StateFailed
		if j.errorMsg != "" {
			t.Detail = j.errorMsg
		}
		t.Rate = -1
	case j.terminated:
		t.State = StateDone
		t.Rate = -1
		if t.Total > 0 {
			t.Processed = t.Total
		}
	case j.suspended:
		t.State = StatePaused
	}
	t.Actions = []string{}
	if !j.terminated {
		if j.caps&capKillable != 0 {
			t.Actions = append(t.Actions, ActionCancel)
		}
		if j.caps&capSuspendable != 0 {
			if j.suspended {
				t.Actions = append(t.Actions, ActionResume)
			} else {
				t.Actions = append(t.Actions, ActionSuspend)
			}
		}
	}
	return t
}

// jobKind: file operations from Dolphin/KIO are copies, the rest downloads.
func jobKind(j *jobState) string {
	app := strings.ToLower(j.app + " " + j.icon)
	text := strings.ToLower(j.title + " " + j.info)
	for _, w := range []string{"copying", "moving", "deleting", "trash", "extracting", "compressing"} {
		if strings.Contains(text, w) {
			return KindCopy
		}
	}
	for _, w := range []string{"dolphin", "kio", "ark", "kded", "system-file-manager", "konqueror"} {
		if strings.Contains(app, w) {
			return KindCopy
		}
	}
	return KindDownload
}

// Action emits the signal the job's owner listens to.
func (s *jobViewSource) Action(key, action string) error {
	s.mu.Lock()
	j := s.jobs[key]
	conn := s.conn
	s.mu.Unlock()
	if j == nil || conn == nil {
		return fmt.Errorf("unknown job %q", key)
	}
	var signal string
	switch action {
	case ActionCancel:
		signal = "cancelRequested"
	case ActionSuspend:
		signal = "suspendRequested"
	case ActionResume:
		signal = "resumeRequested"
	default:
		return fmt.Errorf("unsupported action %q", action)
	}
	return conn.Emit(j.path, j.iface+"."+signal)
}

func variantString(v dbus.Variant) string {
	switch x := v.Value().(type) {
	case string:
		return x
	case dbus.Variant:
		return variantString(x)
	}
	return ""
}

func variantInt(v dbus.Variant) int64 {
	switch x := v.Value().(type) {
	case uint64:
		return int64(x)
	case int64:
		return x
	case uint32:
		return int64(x)
	case int32:
		return int64(x)
	case uint16:
		return int64(x)
	case int16:
		return int64(x)
	case byte:
		return int64(x)
	case float64:
		return int64(x)
	case dbus.Variant:
		return variantInt(x)
	}
	return -1
}

// localPath turns "file:///a/b" (or a plain path) into a path; "" for remote.
func localPath(u string) string {
	if strings.HasPrefix(u, "/") {
		return strings.TrimSuffix(u, "/")
	}
	p, err := url.Parse(u)
	if err != nil || p.Scheme != "file" {
		return ""
	}
	return strings.TrimSuffix(p.Path, "/")
}

func urlBase(u string) string {
	if p := localPath(u); p != "" {
		return filepath.Base(p)
	}
	if p, err := url.Parse(u); err == nil && p.Path != "" {
		return filepath.Base(strings.TrimSuffix(p.Path, "/"))
	}
	return filepath.Base(u)
}

// desktopDataDirs lists the applications/ dirs (overridable in tests).
var desktopDataDirs = func() []string {
	var dirs []string
	if d := os.Getenv("XDG_DATA_HOME"); d != "" {
		dirs = append(dirs, d)
	} else if home, err := os.UserHomeDir(); err == nil {
		dirs = append(dirs, filepath.Join(home, ".local/share"))
	}
	xdg := os.Getenv("XDG_DATA_DIRS")
	if xdg == "" {
		xdg = "/usr/local/share:/usr/share"
	}
	dirs = append(dirs, strings.Split(xdg, ":")...)
	for i := range dirs {
		dirs[i] = filepath.Join(dirs[i], "applications")
	}
	return dirs
}

// desktopEntryInfo resolves a desktop entry id ("org.kde.dolphin") to its
// Name and Icon, falling back to the id.
func desktopEntryInfo(id string) (name, icon string) {
	id = strings.TrimSuffix(id, ".desktop")
	name, icon = id, id
	if i := strings.LastIndex(id, "."); i >= 0 && i < len(id)-1 {
		name = id[i+1:]
	}
	if name != "" {
		name = strings.ToUpper(name[:1]) + name[1:]
	}
	for _, dir := range desktopDataDirs() {
		f, err := os.Open(filepath.Join(dir, id+".desktop"))
		if err != nil {
			continue
		}
		sc := bufio.NewScanner(f)
		inEntry := false
		for sc.Scan() {
			line := strings.TrimSpace(sc.Text())
			if strings.HasPrefix(line, "[") {
				inEntry = line == "[Desktop Entry]"
				continue
			}
			if !inEntry {
				continue
			}
			if v, ok := strings.CutPrefix(line, "Name="); ok {
				name = v
			} else if v, ok := strings.CutPrefix(line, "Icon="); ok {
				icon = v
			}
		}
		f.Close()
		break
	}
	return name, icon
}

const jobViewServerXML = `<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
<node>
 <interface name="org.kde.JobViewServer">
  <method name="requestView"><arg name="appName" type="s" direction="in"/><arg name="appIconName" type="s" direction="in"/><arg name="capabilities" type="i" direction="in"/><arg type="o" direction="out"/></method>
 </interface>
 <interface name="org.kde.JobViewServerV2">
  <method name="requestView"><arg name="desktopEntry" type="s" direction="in"/><arg name="capabilities" type="i" direction="in"/><arg name="hints" type="a{sv}" direction="in"/><arg type="o" direction="out"/></method>
 </interface>
 <interface name="org.freedesktop.DBus.Introspectable">
  <method name="Introspect"><arg type="s" direction="out"/></method>
 </interface>
</node>`

const jobViewV2XML = `<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
<node>
 <interface name="org.kde.JobViewV2">
  <method name="terminate"><arg name="errorMessage" type="s" direction="in"/></method>
  <method name="setSuspended"><arg name="suspended" type="b" direction="in"/></method>
  <method name="setTotalAmount"><arg name="amount" type="t" direction="in"/><arg name="unit" type="s" direction="in"/></method>
  <method name="setProcessedAmount"><arg name="amount" type="t" direction="in"/><arg name="unit" type="s" direction="in"/></method>
  <method name="setPercent"><arg name="percent" type="u" direction="in"/></method>
  <method name="setSpeed"><arg name="bytesPerSecond" type="t" direction="in"/></method>
  <method name="setInfoMessage"><arg name="message" type="s" direction="in"/></method>
  <method name="setDescriptionField"><arg name="number" type="u" direction="in"/><arg name="name" type="s" direction="in"/><arg name="value" type="s" direction="in"/><arg type="b" direction="out"/></method>
  <method name="clearDescriptionField"><arg name="number" type="u" direction="in"/></method>
  <method name="setDestUrl"><arg name="destUrl" type="v" direction="in"/></method>
  <method name="setError"><arg name="errorCode" type="u" direction="in"/></method>
  <signal name="suspendRequested"/>
  <signal name="resumeRequested"/>
  <signal name="cancelRequested"/>
 </interface>
</node>`

const jobViewV3XML = `<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
<node>
 <interface name="org.kde.JobViewV3">
  <method name="terminate"><arg name="errorCode" type="u" direction="in"/><arg name="errorMessage" type="s" direction="in"/><arg name="hints" type="a{sv}" direction="in"/></method>
  <method name="update"><arg name="data" type="a{sv}" direction="in"/></method>
  <signal name="suspendRequested"/>
  <signal name="resumeRequested"/>
  <signal name="cancelRequested"/>
 </interface>
</node>`
