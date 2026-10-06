package usage

import (
	"time"

	"yozakura/backend/pkg/svc/notify"
)

// Notice is the alert as a shell notification: English text plus the
// translation keys (%1 provider, %2 percent, %3 window, %4 time left).
func (a Alert) Notice(now time.Time) notify.SendParams {
	summary, body := a.Message(now)
	prov := providerLabels[a.Provider]
	if prov == "" {
		prov = a.Provider
	}
	win := any(a.Window)
	if label, ok := windowLabels[a.Window]; ok {
		win = notify.Text{Key: "notify.usage.window." + a.Window, Text: label}
	}
	p := notify.SendParams{Summary: summary, Body: body, SummaryKey: "notify.usage.alert",
		Args: []any{prov, int(a.Used + 0.5), win, ""}}
	if !a.ResetsAt.IsZero() {
		p.BodyKey = "notify.usage.resets"
		left := a.ResetsAt.Sub(now)
		if left < time.Minute {
			p.Args[3] = notify.Text{Key: "notify.usage.soon", Text: humanDuration(left)}
		} else {
			p.Args[3] = humanDuration(left)
		}
	}
	return p
}
