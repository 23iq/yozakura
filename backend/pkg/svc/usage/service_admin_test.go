package usage

import (
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestAlertsSetThresholds(t *testing.T) {
	s, n := testService(t, nil)
	res, err := s.handleAlertsSet(json.RawMessage(`{"thresholds":[95,50,50,0,150]}`))
	require.NoError(t, err)
	assert.Equal(t, map[string]any{"thresholds": []float64{50, 95}}, res)

	require.NoError(t, s.SetLimits(Limits{Provider: "codex", Windows: []Window{{ID: "5h", UsedPercent: 60}}}))
	assert.Equal(t, 1, n.count(), "50%% notifies")
	require.NoError(t, s.SetLimits(Limits{Provider: "codex", Windows: []Window{{ID: "5h", UsedPercent: 85}}}))
	assert.Equal(t, 1, n.count(), "80%% is no longer a threshold")

	// [] turns notifications off.
	_, err = s.handleAlertsSet(json.RawMessage(`{"thresholds":[]}`))
	require.NoError(t, err)
	require.NoError(t, s.SetLimits(Limits{Provider: "claude", Windows: []Window{{ID: "5h", UsedPercent: 99}}}))
	assert.Equal(t, 1, n.count())

	_, err = s.handleAlertsSet(json.RawMessage(`{}`))
	assert.Error(t, err)
}

func TestClearLedger(t *testing.T) {
	s, _ := testService(t, nil)
	_, err := s.Record(Record{Provider: "openai", Model: "gpt-4o", InputTokens: 10, OutputTokens: 1})
	require.NoError(t, err)
	_, err = s.handleClear(json.RawMessage(`{}`))
	assert.Error(t, err, "needs confirm")

	res, err := s.handleClear(json.RawMessage(`{"confirm":true}`))
	require.NoError(t, err)
	assert.Equal(t, map[string]any{"files": 1}, res)
	sum, err := s.ledger.Summary(SummaryQuery{Range: "month"}, s.now())
	require.NoError(t, err)
	assert.Equal(t, 0, sum.Totals.Requests)

	// The ledger keeps working after a clear.
	_, err = s.Record(Record{Provider: "openai", InputTokens: 1})
	require.NoError(t, err)
	sum, _ = s.ledger.Summary(SummaryQuery{Range: "month"}, s.now())
	assert.Equal(t, 1, sum.Totals.Requests)
}

func TestSummarizeProviderDay(t *testing.T) {
	recs := []Record{
		{Time: at("2026-10-06 10:00"), Provider: "openai", InputTokens: 1},
		{Time: at("2026-10-05 10:00"), Provider: "openai", InputTokens: 2},
		{Time: at("2026-10-05 11:00"), Provider: "claude", InputTokens: 3},
		{Time: at("2026-10-05 12:00"), Provider: "openai", InputTokens: 4},
	}
	rows, total, err := Summarize(recs, GroupProviderDay)
	require.NoError(t, err)
	assert.Equal(t, int64(10), total.InputTokens)
	require.Len(t, rows, 3)
	got := []string{}
	for _, r := range rows {
		got = append(got, r.Key+"/"+r.Provider)
	}
	assert.Equal(t, []string{"2026-10-05/claude", "2026-10-05/openai", "2026-10-06/openai"}, got)
	assert.Equal(t, int64(6), rows[1].InputTokens)
}

func TestInfo(t *testing.T) {
	s := NewService(Options{Dir: t.TempDir(), PricesOverride: "/x/ai-prices.json"})
	res, err := s.handleInfo(nil)
	require.NoError(t, err)
	m := res.(map[string]any)
	assert.Equal(t, "/x/ai-prices.json", m["pricesOverride"])
	assert.Equal(t, []float64{80, 90}, m["thresholds"])
	assert.Equal(t, false, m["claudeLimits"])
}
