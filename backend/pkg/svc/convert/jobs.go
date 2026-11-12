package convert

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	conv "yozakura/backend/pkg/convert"
)

// Job states.
const (
	StateQueued    = "queued"
	StateRunning   = "running"
	StateDone      = "done"
	StateFailed    = "failed"
	StateCancelled = "cancelled"
)

// maxJobs: finished jobs beyond this are forgotten, oldest first.
const maxJobs = 200

// Job is one conversion and its state.
type Job struct {
	ID   string `json:"id"`
	Path string `json:"path"`
	Name string `json:"name"`
	From string `json:"from"`
	To   string `json:"to"`
	// Progress 0..1, -1 while unknown (engines without progress).
	Progress float64 `json:"progress"`
	State    string  `json:"state"`
	Output   string  `json:"output,omitempty"`
	Error    string  `json:"error,omitempty"`
	Engine   string  `json:"engine,omitempty"`

	outDir  string
	quality conv.Quality
	ctx     context.Context
}

func (j *Job) finished() bool {
	return j.State == StateDone || j.State == StateFailed || j.State == StateCancelled
}

// Item is one file to convert and its target format.
type Item struct {
	Path   string `json:"path"`
	Target string `json:"target"`
}

// StartParams: the files, where results go ("" = next to each source) and
// the quality of lossy targets.
type StartParams struct {
	Items   []Item `json:"items"`
	OutDir  string `json:"outDir"`
	Quality string `json:"quality"`
}

func (s *Service) start(params json.RawMessage) (any, error) {
	var p StartParams
	if err := json.Unmarshal(params, &p); err != nil || len(p.Items) == 0 {
		return nil, errors.New("items is required")
	}
	jobs, err := s.Start(p)
	if err != nil {
		return nil, err
	}
	return map[string]any{"jobs": jobs}, nil
}

// Start queues one job per item and returns them (queued, or failed at
// once when the file or target is not convertible).
func (s *Service) Start(p StartParams) ([]Job, error) {
	outDir := expandHome(strings.TrimSpace(p.OutDir), s.o.Home)
	if outDir != "" {
		if st, err := os.Stat(outDir); err != nil || !st.IsDir() {
			return nil, fmt.Errorf("output folder %s does not exist", outDir)
		}
	}
	q := conv.ParseQuality(p.Quality)
	out := make([]Job, 0, len(p.Items))
	for _, it := range p.Items {
		j, err := s.newJob(it, outDir, q)
		if err != nil {
			return out, err
		}
		out = append(out, j)
	}
	return out, nil
}

// newJob checks the file (outside the lock: a slow disk must not stall the
// service) and registers the job with its own context, so a cancel that
// arrives before the job runs still reaches it. A queued job starts.
func (s *Service) newJob(it Item, outDir string, q conv.Quality) (Job, error) {
	path := it.Path
	if abs, err := filepath.Abs(path); err == nil {
		path = abs
	}
	state, msg, from := StateQueued, "", ""
	switch fm, ok := conv.Detect(path); {
	case !conv.IsRegular(path):
		state, msg = StateFailed, "not a regular file"
	case !ok:
		state, msg = StateFailed, "unknown format"
	default:
		from = fm.ID
		if _, ok := conv.Lookup(it.Target); !ok {
			state, msg = StateFailed, "unknown target "+it.Target
		}
	}
	if outDir == "" && s.isPasted(path) {
		outDir = s.pastedOutDir()
	}
	ctx, cancel := context.WithCancel(context.Background())
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.stopped {
		cancel()
		return Job{}, errors.New("the converter is shutting down")
	}
	s.seq++
	j := &Job{ID: fmt.Sprintf("c%d", s.seq), Path: path, Name: filepath.Base(path), From: from, To: it.Target,
		State: state, Error: msg, Progress: -1, outDir: outDir, quality: q, ctx: ctx}
	s.jobs[j.ID] = j
	s.order = append(s.order, j.ID)
	s.trim()
	s.publish(j)
	if state == StateQueued {
		s.cancels[j.ID] = cancel
		s.wg.Add(1)
		go s.run(j.ID)
	} else {
		cancel()
	}
	return *j, nil
}

// trim forgets the oldest finished jobs beyond maxJobs; s.mu is held.
func (s *Service) trim() {
	for len(s.order) > maxJobs {
		dropped := false
		for i, id := range s.order {
			if s.jobs[id].finished() {
				delete(s.jobs, id)
				s.order = append(s.order[:i], s.order[i+1:]...)
				dropped = true
				break
			}
		}
		if !dropped {
			return
		}
	}
}

// update changes a job under the lock and publishes it.
func (s *Service) update(id string, fn func(j *Job)) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if j, ok := s.jobs[id]; ok {
		fn(j)
		s.publish(j)
	}
}

func (s *Service) run(id string) {
	defer s.wg.Done()
	s.mu.Lock()
	j, ok := s.jobs[id]
	cancel := s.cancels[id]
	if !ok || j.State != StateQueued {
		s.mu.Unlock()
		return
	}
	ctx := j.ctx
	req := conv.Request{Src: j.Path, From: j.From, To: j.To, Quality: j.quality}
	outDir := j.outDir
	s.mu.Unlock()
	defer func() {
		s.mu.Lock()
		delete(s.cancels, id)
		s.mu.Unlock()
		if cancel != nil {
			cancel()
		}
	}()

	select {
	case s.sem <- struct{}{}:
		defer func() { <-s.sem }()
	case <-ctx.Done():
		s.update(id, func(j *Job) { j.State = StateCancelled })
		return
	}
	output, err := s.convert(ctx, id, req, outDir)
	s.update(id, func(j *Job) {
		switch {
		case err == nil:
			// a result renamed into place is done, even if a cancel came late
			j.State, j.Output, j.Progress, j.Error = StateDone, output, 1, ""
		case ctx.Err() != nil:
			j.State, j.Error = StateCancelled, ""
		default:
			j.State, j.Error = StateFailed, err.Error()
		}
	})
}

// convert runs one job in a private work directory: under the cache when
// it is on the output's filesystem (nothing appears in the user's folder
// and the result is still renamed, never copied), else a hidden one in the
// output folder. The result gets a reserved name only once it exists.
func (s *Service) convert(ctx context.Context, id string, req conv.Request, outDir string) (string, error) {
	t := s.Tools()
	to, _ := conv.Lookup(req.To)
	dir := outDir
	if dir == "" {
		dir = filepath.Dir(req.Src)
	}
	work, err := s.workDir(dir)
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(work)
	plan, err := conv.BuildPlan(req, t, work, conv.PlanOptions{OfficeProfile: s.officeProfile()})
	if err != nil {
		return "", err
	}
	if plan.Engine == conv.EngineSoffice || plan.Engine == conv.EngineDocPDF {
		// one LibreOffice per profile; a cancelled job stops waiting
		select {
		case s.office <- struct{}{}:
			defer func() { <-s.office }()
		case <-ctx.Done():
			return "", ctx.Err()
		}
	}
	if plan.Engine == conv.EngineFFmpeg {
		plan.Duration = t.ProbeDuration(ctx, req.Src)
	}
	s.update(id, func(j *Job) { j.State, j.Engine, j.Progress = StateRunning, string(plan.Engine), -1 })
	if err := plan.Run(ctx, func(f float64) {
		s.update(id, func(j *Job) { j.Progress = f })
	}); err != nil {
		return "", err
	}
	if err := ctx.Err(); err != nil {
		return "", err
	}
	final, err := conv.Reserve(req.Src, to.Ext(), dir)
	if err != nil {
		return "", err
	}
	if err := os.Rename(plan.Out, final); err != nil {
		os.Remove(final)
		return "", fmt.Errorf("cannot write to %s", dir)
	}
	return final, nil
}

func (s *Service) cancel(params json.RawMessage) (any, error) {
	var p struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(params, &p); err != nil || p.ID == "" {
		return nil, errors.New("id is required")
	}
	s.mu.Lock()
	c, ok := s.cancels[p.ID]
	j := s.jobs[p.ID]
	s.mu.Unlock()
	if j == nil {
		return nil, errors.New("unknown job " + p.ID)
	}
	if ok {
		c()
	}
	return map[string]any{}, nil
}

func (s *Service) clear(json.RawMessage) (any, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	keep := s.order[:0]
	for _, id := range s.order {
		if s.jobs[id].finished() {
			delete(s.jobs, id)
		} else {
			keep = append(keep, id)
		}
	}
	s.order = keep
	return map[string]any{}, nil
}

// Jobs returns a copy of every known job, oldest first.
func (s *Service) Jobs() []Job {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]Job, 0, len(s.order))
	for _, id := range s.order {
		out = append(out, *s.jobs[id])
	}
	return out
}

func expandHome(p, home string) string {
	if p == "~" {
		return home
	}
	if strings.HasPrefix(p, "~/") {
		return filepath.Join(home, p[2:])
	}
	return p
}
