package usage

import (
	"errors"
	"sort"
	"time"
)

// Ranges and groupings accepted by Summary.
const (
	RangeToday  = "today"
	RangeWeek   = "week"
	RangeMonth  = "month"
	RangeCustom = "custom"

	GroupProvider = "provider"
	GroupModel    = "model"
	GroupDay      = "day"
	// GroupProviderDay: one row per provider and day (Key = day, Provider
	// set), chronological; the AI bar draws per-provider sparklines from it.
	GroupProviderDay = "provider_day"
)

// SummaryQuery selects records and how to group them. From/To are only
// used by the custom range.
type SummaryQuery struct {
	Range   string    `json:"range"`
	GroupBy string    `json:"groupBy"`
	From    time.Time `json:"from,omitzero"`
	To      time.Time `json:"to,omitzero"`
}

// Row is one group of a summary. Provider is filled for model rows.
type Row struct {
	Key      string `json:"key"`
	Provider string `json:"provider,omitempty"`
	Totals
}

// Summary is the answer of usage.summary.
type Summary struct {
	Range   string    `json:"range"`
	GroupBy string    `json:"groupBy"`
	From    time.Time `json:"from"`
	To      time.Time `json:"to"`
	Totals  Totals    `json:"totals"`
	Rows    []Row     `json:"rows"`
}

// Bounds resolves a named range to [from, to) in local time. Ranges are
// calendar based: today from midnight, week from Monday, month from the 1st.
func Bounds(q SummaryQuery, now time.Time) (time.Time, time.Time, error) {
	now = now.Local()
	day := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.Local)
	switch q.Range {
	case "", RangeToday:
		return day, day.AddDate(0, 0, 1), nil
	case RangeWeek:
		offset := (int(day.Weekday()) + 6) % 7 // Monday = 0
		start := day.AddDate(0, 0, -offset)
		return start, start.AddDate(0, 0, 7), nil
	case RangeMonth:
		start := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.Local)
		return start, start.AddDate(0, 1, 0), nil
	case RangeCustom:
		if q.From.IsZero() {
			return time.Time{}, time.Time{}, errors.New("usage: custom range needs from")
		}
		to := q.To
		if to.IsZero() {
			to = now.Add(time.Second)
		}
		if !to.After(q.From) {
			return time.Time{}, time.Time{}, errors.New("usage: to must be after from")
		}
		return q.From, to, nil
	}
	return time.Time{}, time.Time{}, errors.New("usage: range must be today, week, month or custom")
}

// Summarize groups recs (already filtered to the range). Rows are sorted by
// cost then tokens, descending; day rows chronologically.
func Summarize(recs []Record, groupBy string) ([]Row, Totals, error) {
	if groupBy == "" {
		groupBy = GroupProvider
	}
	type key struct{ k, provider string }
	groups := map[key]*Row{}
	var total Totals
	for _, r := range recs {
		total.add(r)
		var k key
		switch groupBy {
		case GroupProvider:
			k = key{k: r.Provider}
		case GroupModel:
			k = key{k: r.Model, provider: r.Provider}
		case GroupDay:
			k = key{k: r.Time.Local().Format("2006-01-02")}
		case GroupProviderDay:
			k = key{k: r.Time.Local().Format("2006-01-02"), provider: r.Provider}
		default:
			return nil, Totals{}, errors.New("usage: groupBy must be provider, model, day or provider_day")
		}
		row := groups[k]
		if row == nil {
			row = &Row{Key: k.k, Provider: k.provider}
			groups[k] = row
		}
		row.add(r)
	}
	rows := make([]Row, 0, len(groups))
	for _, r := range groups {
		rows = append(rows, *r)
	}
	sort.Slice(rows, func(i, j int) bool {
		a, b := rows[i], rows[j]
		if groupBy == GroupDay || groupBy == GroupProviderDay {
			if a.Key != b.Key {
				return a.Key < b.Key
			}
			return a.Provider < b.Provider
		}
		if a.CostUSD != b.CostUSD {
			return a.CostUSD > b.CostUSD
		}
		ta, tb := a.InputTokens+a.OutputTokens, b.InputTokens+b.OutputTokens
		if ta != tb {
			return ta > tb
		}
		return a.Provider+"/"+a.Key < b.Provider+"/"+b.Key
	})
	return rows, total, nil
}

// Summary answers a query against the ledger.
func (l *Ledger) Summary(q SummaryQuery, now time.Time) (Summary, error) {
	from, to, err := Bounds(q, now)
	if err != nil {
		return Summary{}, err
	}
	recs, err := l.Between(from, to)
	if err != nil {
		return Summary{}, err
	}
	rows, total, err := Summarize(recs, q.GroupBy)
	if err != nil {
		return Summary{}, err
	}
	rng, group := q.Range, q.GroupBy
	if rng == "" {
		rng = RangeToday
	}
	if group == "" {
		group = GroupProvider
	}
	return Summary{Range: rng, GroupBy: group, From: from, To: to, Totals: total, Rows: rows}, nil
}

// SessionLookback bounds how far back a session total looks.
const SessionLookback = 92 * 24 * time.Hour

// Session sums the records of one session id within SessionLookback.
func (l *Ledger) Session(id string, now time.Time) (Totals, error) {
	var t Totals
	if id == "" {
		return t, errors.New("usage: sessionId required")
	}
	recs, err := l.Between(now.Add(-SessionLookback), time.Time{})
	if err != nil {
		return t, err
	}
	for _, r := range recs {
		if r.SessionID == id {
			t.add(r)
		}
	}
	return t, nil
}
