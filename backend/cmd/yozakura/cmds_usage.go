package main

import (
	"encoding/json"
	"fmt"
	"io"
	"strings"
	"text/tabwriter"
	"time"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/svc/usage"
)

type usageCaller interface {
	Call(method string, params any) (json.RawMessage, error)
}

const usageHelp = `Usage: {bin} usage [today|week|month] [--by provider|model|day] [--json]
       {bin} usage limits [--json]

AI token usage and cost from the usage ledger (costs marked ≈ are estimates
from the price table). Ranges are calendar based: today, this week (from
Monday), this month. limits shows the subscription windows (Claude, Codex)
reported to the running shell.
`

// runUsage prints the usage summary or the subscription limits. The summary
// reads the ledger directly when the shell is not running.
func runUsage(args []string, c usageCaller, out, errOut io.Writer) int {
	q := usage.SummaryQuery{Range: usage.RangeToday, GroupBy: usage.GroupProvider}
	asJSON, limits := false, false
	for i := 0; i < len(args); i++ {
		a := args[i]
		switch {
		case a == "help" || a == "-h" || a == "--help":
			fmt.Fprint(out, branded(usageHelp))
			return 0
		case a == "--json":
			asJSON = true
		case a == "limits":
			limits = true
		case a == usage.RangeToday || a == usage.RangeWeek || a == usage.RangeMonth:
			q.Range = a
		case a == "--by" && i+1 < len(args):
			i++
			q.GroupBy = args[i]
		case strings.HasPrefix(a, "--by="):
			q.GroupBy = strings.TrimPrefix(a, "--by=")
		default:
			fmt.Fprintf(errOut, "Error: unknown argument %q\n", a)
			fmt.Fprint(errOut, branded(usageHelp))
			return 2
		}
	}
	if q.GroupBy != usage.GroupProvider && q.GroupBy != usage.GroupModel && q.GroupBy != usage.GroupDay {
		fmt.Fprintf(errOut, "Error: --by must be provider, model or day\n")
		return 2
	}
	if limits {
		return printUsageLimits(c, asJSON, out, errOut)
	}
	var sum usage.Summary
	raw, err := c.Call("usage.summary", q)
	if err == nil {
		err = json.Unmarshal(raw, &sum)
	} else {
		sum, err = usage.NewLedger(usage.DefaultDir(paths.New().DataDir)).Summary(q, time.Now())
	}
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	if asJSON {
		data, _ := json.MarshalIndent(sum, "", "  ")
		fmt.Fprintln(out, string(data))
		return 0
	}
	printUsageSummary(sum, out)
	return 0
}

func formatCost(t usage.Totals) string {
	if t.Requests > 0 && t.Unpriced == t.Requests {
		return "-"
	}
	s := fmt.Sprintf("$%.4f", t.CostUSD)
	if t.Estimated {
		s = "≈" + s
	}
	if t.Unpriced > 0 {
		s += "+"
	}
	return s
}

func formatTokens(n int64) string {
	switch {
	case n >= 1_000_000:
		return fmt.Sprintf("%.2fM", float64(n)/1e6)
	case n >= 10_000:
		return fmt.Sprintf("%.1fk", float64(n)/1e3)
	}
	return fmt.Sprint(n)
}

func printUsageSummary(sum usage.Summary, out io.Writer) {
	fmt.Fprintf(out, "%s usage, %s – %s, by %s\n\n", strings.ToUpper(sum.Range[:1])+sum.Range[1:],
		sum.From.Format("2006-01-02"), sum.To.Add(-time.Second).Format("2006-01-02"), sum.GroupBy)
	if sum.Totals.Requests == 0 {
		fmt.Fprintln(out, "No usage recorded.")
		return
	}
	w := tabwriter.NewWriter(out, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, strings.ToUpper(sum.GroupBy)+"\tREQUESTS\tINPUT\tOUTPUT\tCACHED\tCOST")
	for _, r := range sum.Rows {
		key := r.Key
		if r.Provider != "" {
			key = r.Provider + "/" + r.Key
		}
		if key == "" {
			key = "(unknown)"
		}
		fmt.Fprintf(w, "%s\t%d\t%s\t%s\t%s\t%s\n", key, r.Requests, formatTokens(r.InputTokens),
			formatTokens(r.OutputTokens), formatTokens(r.CachedTokens), formatCost(r.Totals))
	}
	t := sum.Totals
	fmt.Fprintf(w, "TOTAL\t%d\t%s\t%s\t%s\t%s\n", t.Requests, formatTokens(t.InputTokens),
		formatTokens(t.OutputTokens), formatTokens(t.CachedTokens), formatCost(t))
	w.Flush()
}

func printUsageLimits(c usageCaller, asJSON bool, out, errOut io.Writer) int {
	raw, err := c.Call("usage.limits.get", nil)
	if err != nil {
		fmt.Fprintf(errOut, "Error: %s is not running (limits live in the shell): %v\n", brand.DisplayName, err)
		return 1
	}
	var res struct {
		Limits []usage.Limits `json:"limits"`
	}
	if err := json.Unmarshal(raw, &res); err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	if asJSON {
		data, _ := json.MarshalIndent(res, "", "  ")
		fmt.Fprintln(out, string(data))
		return 0
	}
	if len(res.Limits) == 0 {
		fmt.Fprintln(out, "No subscription limits reported yet.")
		return 0
	}
	now := time.Now()
	w := tabwriter.NewWriter(out, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "PROVIDER\tWINDOW\tUSED\tRESETS\tSOURCE")
	for _, l := range res.Limits {
		for _, win := range l.Windows {
			resets := "-"
			if !win.ResetsAt.IsZero() {
				resets = win.ResetsAt.Local().Format("Mon 15:04") + " (in " + win.ResetsAt.Sub(now).Round(time.Minute).String() + ")"
			}
			fmt.Fprintf(w, "%s\t%s\t%.0f%%\t%s\t%s\n", l.Provider, win.ID, win.UsedPercent, resets, l.Source)
		}
	}
	w.Flush()
	return 0
}
