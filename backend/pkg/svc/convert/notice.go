package convert

import (
	"path/filepath"

	conv "yozakura/backend/pkg/convert"
	notifysvc "yozakura/backend/pkg/svc/notify"
)

// A job that finishes while no converter window listens (it was closed,
// or the job came from a script) is announced as a desktop notification
// through the shell (notify.Send), translated there.

// noticeIfUnwatched notifies the end of job id when nobody subscribes.
func (s *Service) noticeIfUnwatched(id string) {
	if s.o.Notify == nil {
		return
	}
	s.mu.Lock()
	j, ok := s.jobs[id]
	var job Job
	if ok {
		job = *j
	}
	watched := len(s.subs) > 0
	s.mu.Unlock()
	if !ok || watched || (job.State != StateDone && job.State != StateFailed) {
		return
	}
	s.o.Notify(jobNotice(job))
}

// jobNotice is the notification of a finished job.
func jobNotice(j Job) notifysvc.SendParams {
	p := notifysvc.SendParams{ReplaceKey: "convert-" + j.ID, Urgency: "normal"}
	if j.State == StateDone {
		out := filepath.Base(j.Output)
		p.Summary, p.Body = "Converted "+j.Name, "Saved as "+out
		p.SummaryKey, p.BodyKey, p.Args = "notify.convert.done", "notify.convert.saved", []any{j.Name, out}
		p.AppIcon = "document-save"
		return p
	}
	reason := notifysvc.Text{Text: j.Error}
	if j.Code != "" && !conv.DetailCodes[j.Code] {
		args := make([]any, len(j.ErrorArgs))
		for i, a := range j.ErrorArgs {
			args[i] = a
		}
		reason.Key, reason.Args = "converter.error."+j.Code, args
	}
	p.Summary, p.Body = "Could not convert "+j.Name, j.Error
	p.SummaryKey, p.BodyKey, p.Args = "notify.convert.failed", "notify.convert.reason", []any{j.Name, reason}
	p.AppIcon = "dialog-error"
	return p
}
