package usage

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestBounds(t *testing.T) {
	now := at("2026-10-07 15:00") // a Wednesday
	from, to, err := Bounds(SummaryQuery{Range: RangeToday}, now)
	require.NoError(t, err)
	assert.Equal(t, at("2026-10-07 00:00"), from)
	assert.Equal(t, at("2026-10-08 00:00"), to)

	from, to, _ = Bounds(SummaryQuery{Range: RangeWeek}, now)
	assert.Equal(t, at("2026-10-05 00:00"), from) // Monday
	assert.Equal(t, at("2026-10-12 00:00"), to)

	from, _, _ = Bounds(SummaryQuery{Range: RangeWeek}, at("2026-10-11 23:00")) // Sunday
	assert.Equal(t, at("2026-10-05 00:00"), from)

	from, to, _ = Bounds(SummaryQuery{Range: RangeMonth}, now)
	assert.Equal(t, at("2026-10-01 00:00"), from)
	assert.Equal(t, at("2026-11-01 00:00"), to)

	_, _, err = Bounds(SummaryQuery{Range: RangeCustom}, now)
	assert.Error(t, err)
	from, to, err = Bounds(SummaryQuery{Range: RangeCustom, From: at("2026-09-01 00:00"), To: at("2026-09-02 00:00")}, now)
	require.NoError(t, err)
	assert.Equal(t, at("2026-09-01 00:00"), from)
	assert.Equal(t, at("2026-09-02 00:00"), to)
	_, _, err = Bounds(SummaryQuery{Range: "year"}, now)
	assert.Error(t, err)
}

func TestSummarizeMath(t *testing.T) {
	recs := []Record{
		rec("2026-10-05 10:00", "openai", "gpt-4o", 1000, 100, 0.5),
		rec("2026-10-05 11:00", "openai", "gpt-4o-mini", 2000, 200, 0.25),
		rec("2026-10-06 09:00", "anthropic", "claude-opus-5-5", 500, 50, 1.0),
		rec("2026-10-06 09:30", "custom", "mystery", 300, 30, -1), // unpriced
	}
	recs[1].Estimated = true
	recs[1].CachedTokens = 500

	rows, total, err := Summarize(recs, GroupProvider)
	require.NoError(t, err)
	assert.Equal(t, 4, total.Requests)
	assert.Equal(t, int64(3800), total.InputTokens)
	assert.Equal(t, int64(380), total.OutputTokens)
	assert.Equal(t, int64(500), total.CachedTokens)
	assert.InDelta(t, 1.75, total.CostUSD, 1e-9)
	assert.True(t, total.Estimated)
	assert.Equal(t, 1, total.Unpriced)
	require.Len(t, rows, 3)
	assert.Equal(t, "anthropic", rows[0].Key) // most expensive first
	assert.Equal(t, "openai", rows[1].Key)
	assert.InDelta(t, 0.75, rows[1].CostUSD, 1e-9)
	assert.Equal(t, 2, rows[1].Requests)
	assert.Equal(t, "custom", rows[2].Key)

	rows, _, _ = Summarize(recs, GroupModel)
	require.Len(t, rows, 4)
	assert.Equal(t, "claude-opus-5-5", rows[0].Key)
	assert.Equal(t, "anthropic", rows[0].Provider)

	rows, _, _ = Summarize(recs, GroupDay)
	require.Len(t, rows, 2)
	assert.Equal(t, "2026-10-05", rows[0].Key)
	assert.Equal(t, "2026-10-06", rows[1].Key)
	assert.Equal(t, 2, rows[1].Requests)

	_, _, err = Summarize(recs, "color")
	assert.Error(t, err)
}

func TestLedgerSummaryAndSession(t *testing.T) {
	l := NewLedger(t.TempDir())
	a := rec("2026-10-05 10:00", "openai", "gpt-4o", 100, 10, 0.1)
	a.SessionID = "s1"
	b := rec("2026-10-07 10:00", "openai", "gpt-4o", 200, 20, 0.2)
	b.SessionID = "s1"
	c := rec("2026-09-20 10:00", "groq", "llama", 50, 5, 0)
	for _, r := range []Record{a, b, c} {
		require.NoError(t, l.Append(r))
	}
	now := at("2026-10-07 18:00")
	s, err := l.Summary(SummaryQuery{Range: RangeToday}, now)
	require.NoError(t, err)
	assert.Equal(t, 1, s.Totals.Requests)
	assert.Equal(t, RangeToday, s.Range)
	assert.Equal(t, GroupProvider, s.GroupBy)

	s, _ = l.Summary(SummaryQuery{Range: RangeWeek}, now)
	assert.Equal(t, 2, s.Totals.Requests)
	s, _ = l.Summary(SummaryQuery{Range: RangeCustom, From: at("2026-09-01 00:00")}, now)
	assert.Equal(t, 3, s.Totals.Requests)

	tot, err := l.Session("s1", now)
	require.NoError(t, err)
	assert.Equal(t, 2, tot.Requests)
	assert.Equal(t, int64(300), tot.InputTokens)
	assert.InDelta(t, 0.3, tot.CostUSD, 1e-9)
	_, err = l.Session("", now)
	assert.Error(t, err)

	// Records older than the lookback do not count.
	tot, _ = l.Session("s1", now.Add(SessionLookback+72*time.Hour))
	assert.Equal(t, 0, tot.Requests)
}
