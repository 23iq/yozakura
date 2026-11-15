package convert

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime/debug"
	"strings"
	"syscall"
	"time"

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
	// Code is the error's stable cause (conv.Code*), ErrorArgs the
	// arguments of its translation; Error stays the English message (a
	// tool's own words for conv.DetailCodes). A cancelled job has code
	// "cancelled".
	Code      string   `json:"code,omitempty"`
	ErrorArgs []string `json:"errorArgs,omitempty"`
	Engine    string   `json:"engine,omitempty"`

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
		return nil, conv.Errorf(conv.CodeBadRequest, nil, "items is required")
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
		// a relative folder would resolve against whatever directory
		// each tool runs in
		if abs, err := filepath.Abs(outDir); err == nil {
			outDir = abs
		}
		if st, err := os.Stat(outDir); err != nil || !st.IsDir() {
			return nil, conv.Errorf(conv.CodeOutDir, []string{outDir}, "output folder %s does not exist", outDir)
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
	state, msg, code, from, to := StateQueued, "", "", "", it.Target
	var args []string
	switch fm, ok := conv.Detect(path); {
	case !conv.IsRegular(path):
		state, msg, code = StateFailed, "not a regular file", conv.CodeNotRegular
		if _, err := os.Stat(path); err != nil {
			msg, code = "not found", conv.CodeNotFound
		}
	case !ok:
		state, msg, code = StateFailed, "unknown format", conv.CodeUnknownFormat
	default:
		from = fm.ID
		// "jpeg", "JPG", ".png" name a format; the routes know its id
		if f, ok := conv.Lookup(it.Target); ok {
			to = f.ID
		} else {
			state, msg, code, args = StateFailed, "unknown target "+it.Target, conv.CodeUnknownTarget, []string{it.Target}
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
		return Job{}, conv.Errorf(conv.CodeStopping, nil, "the converter is shutting down")
	}
	s.seq++
	j := &Job{ID: fmt.Sprintf("c%d", s.seq), Path: path, Name: filepath.Base(path), From: from, To: to,
		State: state, Error: msg, Code: code, ErrorArgs: args, Progress: -1, outDir: outDir, quality: q, ctx: ctx}
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
		s.update(id, func(j *Job) { j.State, j.Code = StateCancelled, conv.CodeCancelled })
		return
	}
	output, err := s.safeConvert(ctx, id, req, outDir)
	s.update(id, func(j *Job) {
		switch {
		case err == nil:
			// a result renamed into place is done, even if a cancel came late
			j.State, j.Output, j.Progress, j.Error = StateDone, output, 1, ""
		case ctx.Err() != nil:
			j.State, j.Error, j.Code = StateCancelled, "", conv.CodeCancelled
		default:
			// an uncoded error is a tool's (or the system's) own words
			j.State, j.Error = StateFailed, err.Error()
			j.Code, j.ErrorArgs = conv.CodeOf(err, conv.CodeToolFailed)
		}
	})
	s.noticeIfUnwatched(id)
}

// safeConvert is convert with a panic turned into the job's error: the
// service lives in the daemon that supervises the shell.
func (s *Service) safeConvert(ctx context.Context, id string, req conv.Request, outDir string) (out string, err error) {
	defer func() {
		if r := recover(); r != nil {
			fmt.Fprintf(os.Stderr, "convert: job %s panicked: %v\n%s", id, r, debug.Stack())
			out, err = "", conv.Errorf(conv.CodeCrashed, nil, "the converter failed on this file (%v)", r)
		}
	}()
	return s.convert(ctx, id, req, outDir)
}

// progressEvery: progress is published at most this often (ffmpeg reports
// many times a second; the end and unknown progress always go out).
const progressEvery = 100 * time.Millisecond

// progress returns the job's throttled progress callback.
func (s *Service) progress(id string) conv.ProgressFunc {
	last, lastAt := -2.0, time.Time{}
	return func(f float64) {
		now := time.Now()
		if f == last || (f >= 0 && f < 1 && last >= 0 && now.Sub(lastAt) < progressEvery) {
			return
		}
		last, lastAt = f, now
		s.update(id, func(j *Job) { j.Progress = f })
	}
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
	work, release, err := s.workDir(dir)
	if err != nil {
		return "", err
	}
	defer release()
	opts := conv.PlanOptions{OfficeProfile: s.officeProfile()}
	// a text result of a docx / odt / epub keeps its images in a folder
	// next to it, named before the run (the text links to it)
	media := ""
	if conv.ShipsMedia(req.From, req.To) {
		if media, err = conv.ReserveDir(conv.MediaName(req.Src), dir); err != nil {
			return "", err
		}
		opts.MediaLink = filepath.Base(media)
		defer func() {
			if media != "" {
				_ = os.Remove(media) // unused: still empty
			}
		}()
	}
	plan, err := conv.BuildPlan(req, t, work, opts)
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
	s.update(id, func(j *Job) { j.State, j.Engine, j.Progress = StateRunning, string(plan.Engine), -1 })
	if err := plan.Run(ctx, s.progress(id)); err != nil {
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
		return "", conv.Errorf(conv.CodeNoWrite, []string{dir}, "cannot write to %s", dir)
	}
	if media != "" && plan.Media != "" {
		// onto the reserved empty folder: rename(2) replaces an empty one
		// (os.Rename refuses any existing folder)
		if st, err := os.Stat(plan.Media); err == nil && st.IsDir() && syscall.Rename(plan.Media, media) == nil {
			media = ""
		}
	}
	return final, nil
}

func (s *Service) cancel(params json.RawMessage) (any, error) {
	var p struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(params, &p); err != nil || p.ID == "" {
		return nil, conv.Errorf(conv.CodeBadRequest, nil, "id is required")
	}
	s.mu.Lock()
	c, ok := s.cancels[p.ID]
	j := s.jobs[p.ID]
	s.mu.Unlock()
	if j == nil {
		return nil, conv.Errorf(conv.CodeUnknownJob, []string{p.ID}, "unknown job %s", p.ID)
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
