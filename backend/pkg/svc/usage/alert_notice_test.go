package usage

import (
	"testing"
	"time"

	"yozakura/backend/pkg/svc/notify"

	"github.com/stretchr/testify/assert"
)

func TestAlertNotice(t *testing.T) {
	now := at("2026-10-06 10:00")
	p := Alert{Provider: "claude", Window: "5h", Threshold: 80, Used: 81.4, ResetsAt: now.Add(90 * time.Minute)}.Notice(now)
	assert.Equal(t, "Claude: 81% of the 5-hour limit used", p.Summary)
	assert.Equal(t, "notify.usage.alert", p.SummaryKey)
	assert.Equal(t, "notify.usage.resets", p.BodyKey)
	assert.Equal(t, []any{"Claude", 81, notify.Text{Key: "notify.usage.window.5h", Text: "5-hour"}, "1h 30m"}, p.Args)

	p = Alert{Provider: "other", Window: "x", Used: 90, ResetsAt: now.Add(time.Second)}.Notice(now)
	assert.Equal(t, "x", p.Args[2])
	assert.Equal(t, "notify.usage.soon", p.Args[3].(notify.Text).Key)

	p = Alert{Provider: "codex", Window: "week", Used: 95}.Notice(now)
	assert.Empty(t, p.BodyKey)
	assert.Empty(t, p.Body)
}
