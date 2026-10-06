package usage

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestMain(m *testing.M) {
	time.Local = time.FixedZone("UTC+2", 2*3600) // calendar math must use local time
	os.Exit(m.Run())
}

func at(s string) time.Time {
	t, err := time.ParseInLocation("2006-01-02 15:04", s, time.Local)
	if err != nil {
		panic(err)
	}
	return t
}

func rec(when, provider, model string, in, out int64, cost float64) Record {
	r := Record{Time: at(when), Provider: provider, Model: model, InputTokens: in, OutputTokens: out}
	if cost >= 0 {
		r.CostUSD = ptr(cost)
	}
	return r
}

func TestLedgerRotatesMonthly(t *testing.T) {
	dir := t.TempDir()
	l := NewLedger(dir)
	require.NoError(t, l.Append(rec("2026-09-30 23:30", "openai", "gpt-4o", 10, 5, 0.1)))
	require.NoError(t, l.Append(rec("2026-10-01 00:30", "openai", "gpt-4o", 20, 5, 0.2)))
	require.NoError(t, l.Append(rec("2026-10-05 12:00", "anthropic", "claude-opus-5-5", 30, 5, 0.3)))

	assert.Equal(t, []string{"2026-09", "2026-10"}, l.Months())
	data, err := os.ReadFile(filepath.Join(dir, "2026-10.jsonl"))
	require.NoError(t, err)
	assert.Equal(t, 2, len(splitLines(string(data))))

	// A fresh ledger (new process) reads the same records back.
	recs, err := NewLedger(dir).Between(at("2026-09-30 00:00"), time.Time{})
	require.NoError(t, err)
	assert.Len(t, recs, 3)
	recs, err = NewLedger(dir).Between(at("2026-10-01 00:00"), at("2026-10-02 00:00"))
	require.NoError(t, err)
	require.Len(t, recs, 1)
	assert.Equal(t, int64(20), recs[0].InputTokens)
}

func TestLedgerCacheSeesAppends(t *testing.T) {
	l := NewLedger(t.TempDir())
	require.NoError(t, l.Append(rec("2026-10-05 10:00", "openai", "gpt-4o", 1, 1, 0)))
	recs, _ := l.Between(at("2026-10-01 00:00"), time.Time{})
	require.Len(t, recs, 1)
	require.NoError(t, l.Append(rec("2026-10-05 11:00", "openai", "gpt-4o", 1, 1, 0)))
	recs, _ = l.Between(at("2026-10-01 00:00"), time.Time{})
	assert.Len(t, recs, 2)
}

func TestLedgerSkipsBrokenLines(t *testing.T) {
	dir := t.TempDir()
	content := `{"time":"2026-10-05T10:00:00+02:00","provider":"openai","inputTokens":3,"outputTokens":1}
{"time":"2026-10-05T10:01:00+02:00","prov
{"time":"2026-10-05T10:02:00+02:00","provider":"groq","inputTokens":4,"outputTokens":1}
`
	require.NoError(t, os.WriteFile(filepath.Join(dir, "2026-10.jsonl"), []byte(content), 0o600))
	require.NoError(t, os.WriteFile(filepath.Join(dir, "notes.txt"), []byte("x"), 0o600))
	l := NewLedger(dir)
	assert.Equal(t, []string{"2026-10"}, l.Months())
	recs, err := l.Between(at("2026-10-01 00:00"), time.Time{})
	require.NoError(t, err)
	assert.Len(t, recs, 2)
}

func TestRecordValidation(t *testing.T) {
	now := at("2026-10-05 10:00")
	r := Record{Provider: " OpenAI "}
	require.NoError(t, r.normalize(now))
	assert.Equal(t, "openai", r.Provider)
	assert.Equal(t, now, r.Time)

	for _, bad := range []Record{
		{},
		{Provider: "x", InputTokens: -1},
		{Provider: "x", CostUSD: ptr(-1)},
		{Provider: "x", Space: "other"},
		{Provider: "x", Engine: "cli"},
	} {
		assert.Error(t, bad.normalize(now), "%+v", bad)
	}
}

func splitLines(s string) []string {
	var out []string
	start := 0
	for i := 0; i < len(s); i++ {
		if s[i] == '\n' {
			out = append(out, s[start:i])
			start = i + 1
		}
	}
	return out
}
