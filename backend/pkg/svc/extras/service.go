// The "extras" IPC service (catalog, status, install queue).
//
// IPC (service "extras"); errors are "<code>: <JSON>" (see ParseError):
//
//	catalog {}                          -> {categories, entries, platform}
//	status {refresh?}                   -> {<id>: Status}   (cached 30 s)
//	install {ids, confirmMultilib?}     -> {jobs: [{id, kind, entries}]}
//	                                       errors: needs_confirm, unavailable
//	cancel {job}                        -> {}  errors: not_cancellable, unknown_job
//	upgradeAndRetry {job}               -> {jobs}  system upgrade, then the job again
//	log {job}                           -> {text}
//	ollamaPull {model}                  -> {jobs}
//	setLoginShell {shell}               -> {jobs}  (shell must be in /etc/shells)
//
// Events: extras.progress (Progress), extras.status (full {<id>: Status}).
package extras

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/user"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"

	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/paths"
)

const statusTTL = 30 * time.Second

// Options are the side effects of the service (all faked in tests).
type Options struct {
	Catalog  func() (*Catalog, error)
	Platform func() Platform
	Probe    Probe
	Runner   Runner
	Notify   func(title, body string)
	Self     func() string // binary pkexec runs for `sys ...`
	User     func() string
	ReadFile func(string) ([]byte, error)
	Now      func() time.Time
	LogDir   string // "" = the default
}

// Service is the extras IPC service.
type Service struct {
	o Options
	q *Queue

	mu      sync.Mutex
	cat     *Catalog
	cache   map[string]Status
	cacheAt time.Time
	failed  map[string]string   // entry -> reason of its last failed job
	active  map[string][]string // queued/running job -> its entries
	planned map[string]Job      // jobs handed to the queue, for retries
	order   []string
	subs    []*ipc.Subscriber

	refreshMu sync.Mutex
}

// NewService returns the service with the real host.
func NewService(notify func(title, body string)) *Service {
	return newService(Options{
		Catalog:  func() (*Catalog, error) { return LoadCatalog(CatalogPath()) },
		Platform: func() Platform { return DetectPlatform(OSFS{}, ExecProbe{}.LookPath) },
		Probe:    ExecProbe{},
		Runner:   ExecRunner{},
		Notify:   notify,
		Self:     defaultHelper,
		User: func() string {
			if u, err := user.Current(); err == nil {
				return u.Username
			}
			return ""
		},
		ReadFile: os.ReadFile,
		Now:      time.Now,
	})
}

func newService(o Options) *Service {
	s := &Service{o: o, failed: map[string]string{}, active: map[string][]string{}, planned: map[string]Job{}}
	s.q = NewQueue(o.Runner, s.onProgress, o.Notify)
	if o.LogDir != "" {
		s.q.logDir = o.LogDir
	}
	s.q.SetPostActions(func(id string) []string {
		if c, err := s.catalog(); err == nil {
			if e, ok := c.Get(id); ok {
				return e.Post
			}
		}
		return nil
	})
	s.q.SetAfterJob(func(_ Job, ok bool) {
		if ok {
			s.refresh()
		}
	})
	return s
}

// Register exposes the service over IPC.
func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "extras",
		Methods: map[string]ipc.HandlerFunc{
			"catalog": s.catalogM, "status": s.statusM, "install": s.install,
			"cancel": s.cancel, "upgradeAndRetry": s.upgradeAndRetry, "log": s.log,
			"ollamaPull": s.ollamaPull, "setLoginShell": s.setLoginShell,
		},
		Subscribe: s.subscribe,
		Async: map[string]bool{"install": true, "upgradeAndRetry": true, "ollamaPull": true,
			"status": true, "catalog": true, "setLoginShell": true},
	})
}

func (s *Service) catalog() (*Catalog, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.cat == nil {
		c, err := s.o.Catalog()
		if err != nil {
			return nil, err
		}
		s.cat = c
	}
	return s.cat, nil
}

// refresh re-detects every entry now and stores the result.
func (s *Service) refresh() map[string]Status {
	s.refreshMu.Lock()
	defer s.refreshMu.Unlock()
	c, err := s.catalog()
	if err != nil {
		return nil
	}
	st := Detect(c, s.o.Platform(), s.o.Probe)
	s.mu.Lock()
	s.cache, s.cacheAt = st, s.o.Now()
	s.mu.Unlock()
	return st
}

// detected returns the cached detection, refreshing it when older than 30 s
// (or when force is set).
func (s *Service) detected(force bool) map[string]Status {
	s.mu.Lock()
	fresh := s.cache != nil && s.o.Now().Sub(s.cacheAt) < statusTTL
	st := s.cache
	s.mu.Unlock()
	if fresh && !force {
		return st
	}
	return s.refresh()
}

// overlay adds the queue state (installing, failed) to the detection.
func (s *Service) overlay(det map[string]Status) map[string]Status {
	out := make(map[string]Status, len(det))
	s.mu.Lock()
	defer s.mu.Unlock()
	active := map[string]bool{}
	for _, entries := range s.active {
		for _, id := range entries {
			active[id] = true
		}
	}
	for id, st := range det {
		if st.State != StateInstalled {
			if active[id] {
				st.State, st.Reason = StateInstalling, ""
			} else if r, ok := s.failed[id]; ok {
				st.State, st.Reason = StateFailed, r
			}
		}
		out[id] = st
	}
	return out
}

func (s *Service) currentStatus() map[string]Status {
	s.mu.Lock()
	det := s.cache
	s.mu.Unlock()
	return s.overlay(det)
}

// onProgress is the queue's emit: it tracks failures, forwards the job
// event and publishes the status map after every state change.
func (s *Service) onProgress(p Progress) {
	s.mu.Lock()
	if p.State == JobQueued || p.State == JobRunning {
		s.active[p.Job] = p.Entries
	} else {
		delete(s.active, p.Job)
	}
	for _, id := range p.Entries {
		switch p.State {
		case JobFailed:
			s.failed[id] = p.Reason
		case JobDone, JobQueued:
			delete(s.failed, id)
		}
	}
	s.mu.Unlock()
	s.broadcast("extras.progress", p)
	if p.State != JobRunning {
		s.broadcast("extras.status", s.currentStatus())
	}
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.mu.Lock()
	s.subs = append(s.subs, sub)
	s.mu.Unlock()
	for _, p := range s.q.Jobs() {
		sub.Send("extras.progress", p)
	}
	go func() {
		<-sub.StopCh()
		s.mu.Lock()
		defer s.mu.Unlock()
		for i, x := range s.subs {
			if x == sub {
				s.subs = append(s.subs[:i], s.subs[i+1:]...)
				return
			}
		}
	}()
}

func (s *Service) broadcast(name string, data any) {
	s.mu.Lock()
	subs := append([]*ipc.Subscriber(nil), s.subs...)
	s.mu.Unlock()
	for _, sub := range subs {
		sub.Send(name, data)
	}
}

func (s *Service) catalogM(json.RawMessage) (any, error) {
	c, err := s.catalog()
	if err != nil {
		return nil, err
	}
	return map[string]any{"categories": c.Categories, "entries": c.Entries, "platform": s.o.Platform()}, nil
}

func (s *Service) statusM(params json.RawMessage) (any, error) {
	var p struct {
		Refresh bool `json:"refresh"`
	}
	if len(params) > 0 {
		if err := json.Unmarshal(params, &p); err != nil {
			return nil, err
		}
	}
	det := s.detected(p.Refresh)
	if det == nil {
		return nil, errors.New("extras catalog is not available")
	}
	out := s.overlay(det)
	if p.Refresh {
		s.broadcast("extras.status", out)
	}
	return out, nil
}

type jobRef struct {
	ID      string   `json:"id"`
	Kind    JobKind  `json:"kind"`
	Entries []string `json:"entries"`
}

// enqueue remembers the jobs (for retries) and queues them as one batch.
func (s *Service) enqueue(jobs []Job) map[string]any {
	refs := make([]jobRef, 0, len(jobs))
	s.mu.Lock()
	for _, j := range jobs {
		s.planned[j.ID] = j
		s.order = append(s.order, j.ID)
		if len(s.order) > 64 {
			delete(s.planned, s.order[0])
			s.order = s.order[1:]
		}
		e := j.Entries
		if e == nil {
			e = []string{}
		}
		refs = append(refs, jobRef{j.ID, j.Kind, e})
	}
	s.mu.Unlock()
	s.q.Enqueue(jobs)
	return map[string]any{"jobs": refs}
}

func (s *Service) install(params json.RawMessage) (any, error) {
	var p struct {
		IDs             []string `json:"ids"`
		ConfirmMultilib bool     `json:"confirmMultilib"`
	}
	if err := json.Unmarshal(params, &p); err != nil || len(p.IDs) == 0 {
		return nil, errors.New("ids is required")
	}
	c, err := s.catalog()
	if err != nil {
		return nil, err
	}
	det := s.detected(true) // never plan from a stale cache
	jobs, err := Plan(c, s.o.Platform(), det, s.notActive(p.IDs), s.o.Self(), PlanOptions{
		ConfirmMultilib: p.ConfirmMultilib,
		ScriptsDir:      filepath.Join(paths.FindShellSource(), "scripts"),
	})
	if err != nil {
		return nil, codeOf(err)
	}
	return s.enqueue(jobs), nil
}

// notActive drops ids that already belong to a queued or running job.
func (s *Service) notActive(ids []string) []string {
	s.mu.Lock()
	defer s.mu.Unlock()
	busy := map[string]bool{}
	for _, entries := range s.active {
		for _, id := range entries {
			busy[id] = true
		}
	}
	var out []string
	for _, id := range ids {
		if !busy[id] {
			out = append(out, id)
		}
	}
	return out
}

func jobParam(params json.RawMessage) (string, error) {
	var p struct {
		Job string `json:"job"`
	}
	if err := json.Unmarshal(params, &p); err != nil || p.Job == "" {
		return "", errors.New("job is required")
	}
	return p.Job, nil
}

func (s *Service) cancel(params json.RawMessage) (any, error) {
	id, err := jobParam(params)
	if err != nil {
		return nil, err
	}
	if err := s.q.Cancel(id); err != nil {
		return nil, codeOf(err)
	}
	return map[string]any{}, nil
}

// upgradeAndRetry queues a system upgrade and then the failed job again
// (its dependency on the upgrade makes it skip when the upgrade fails).
func (s *Service) upgradeAndRetry(params json.RawMessage) (any, error) {
	id, err := jobParam(params)
	if err != nil {
		return nil, err
	}
	s.mu.Lock()
	old, ok := s.planned[id]
	s.mu.Unlock()
	if !ok {
		return nil, codeOf(ErrUnknownJob)
	}
	up := UpgradeJob(s.o.Self())
	retry := old
	retry.ID, retry.Deps = newJobID(old.Kind), []string{up.ID}
	return s.enqueue([]Job{up, retry}), nil
}

var reJobID = regexp.MustCompile(`^[a-z]+-\d+$`)

const maxLogBytes = 256 << 10

func (s *Service) log(params json.RawMessage) (any, error) {
	id, err := jobParam(params)
	if err != nil {
		return nil, err
	}
	if !reJobID.MatchString(id) {
		return nil, errors.New("bad job id")
	}
	data, err := s.o.ReadFile(filepath.Join(s.q.logDir, id+".log"))
	if err != nil {
		return nil, codeOf(ErrUnknownJob)
	}
	if len(data) > maxLogBytes {
		data = data[len(data)-maxLogBytes:]
	}
	return map[string]any{"text": string(data)}, nil
}

var reModel = regexp.MustCompile(`^[a-z0-9._:/-]+$`)

func (s *Service) ollamaPull(params json.RawMessage) (any, error) {
	var p struct {
		Model string `json:"model"`
	}
	if err := json.Unmarshal(params, &p); err != nil || !reModel.MatchString(p.Model) || strings.HasPrefix(p.Model, "-") {
		return nil, errors.New("invalid model name")
	}
	return s.enqueue([]Job{{ID: newJobID(KindOllama), Kind: KindOllama, Entries: []string{},
		Names: []string{p.Model}, Argv: []string{"ollama", "pull", p.Model}}}), nil
}

// validShell reports whether shell is an absolute path listed in /etc/shells
// (the privileged helper checks again).
func validShell(etcShells []byte, shell string) bool {
	if !strings.HasPrefix(shell, "/") || strings.ContainsAny(shell, " \t\r\n") {
		return false
	}
	for _, l := range strings.Split(string(etcShells), "\n") {
		if strings.TrimSpace(l) == shell {
			return true
		}
	}
	return false
}

func (s *Service) setLoginShell(params json.RawMessage) (any, error) {
	var p struct {
		Shell string `json:"shell"`
	}
	if err := json.Unmarshal(params, &p); err != nil || p.Shell == "" {
		return nil, errors.New("shell is required")
	}
	shells, err := s.o.ReadFile("/etc/shells")
	if err != nil || !validShell(shells, p.Shell) {
		return nil, fmt.Errorf("shell %q is not listed in /etc/shells", p.Shell)
	}
	name := s.o.User()
	if name == "" {
		return nil, errors.New("can't determine the current user")
	}
	return s.enqueue([]Job{{ID: newJobID(KindLogin), Kind: KindLogin, Entries: []string{},
		Names: []string{"login shell"}, NeedsRoot: true,
		Argv: []string{"pkexec", s.o.Self(), "sys", "chsh", name, p.Shell}}}), nil
}
