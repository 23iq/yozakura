package agents

import (
	"fmt"
	"strings"
)

// unifiedDiff renders a unified diff (3 lines of context) between two
// texts. Very large inputs degrade to a single replace-everything hunk.
func unifiedDiff(path, oldText, newText string) string {
	if oldText == newText {
		return ""
	}
	a, b := splitLines(oldText), splitLines(newText)
	ops := diffOps(a, b)
	var sb strings.Builder
	from, to := "a/"+path, "b/"+path
	if oldText == "" {
		from = "/dev/null"
	}
	if newText == "" {
		to = "/dev/null"
	}
	fmt.Fprintf(&sb, "--- %s\n+++ %s\n", from, to)
	const ctx = 3
	// Hunks: ranges around each change, merged when they overlap.
	type rng struct{ lo, hi int }
	var hunks []rng
	for k, op := range ops {
		if op.kind == ' ' {
			continue
		}
		lo, hi := k-ctx, k+ctx+1
		if lo < 0 {
			lo = 0
		}
		if hi > len(ops) {
			hi = len(ops)
		}
		if n := len(hunks); n > 0 && lo <= hunks[n-1].hi {
			hunks[n-1].hi = hi
		} else {
			hunks = append(hunks, rng{lo, hi})
		}
	}
	for _, r := range hunks {
		h := ops[r.lo:r.hi]
		oStart, nStart, oLen, nLen := h[0].a+1, h[0].b+1, 0, 0
		for _, op := range h {
			if op.kind != '+' {
				oLen++
			}
			if op.kind != '-' {
				nLen++
			}
		}
		if oLen == 0 {
			oStart--
		}
		if nLen == 0 {
			nStart--
		}
		fmt.Fprintf(&sb, "@@ -%d,%d +%d,%d @@\n", oStart, oLen, nStart, nLen)
		for _, op := range h {
			sb.WriteByte(op.kind)
			sb.WriteString(op.text)
			sb.WriteByte('\n')
		}
	}
	return sb.String()
}

type diffOp struct {
	kind byte // ' ', '-', '+'
	text string
	a, b int // line index in old/new at this op
}

func splitLines(s string) []string {
	if s == "" {
		return nil
	}
	s = strings.TrimSuffix(s, "\n")
	return strings.Split(s, "\n")
}

// diffOps computes an LCS-based edit script.
func diffOps(a, b []string) []diffOp {
	n, m := len(a), len(b)
	if n*m > 4_000_000 {
		ops := make([]diffOp, 0, n+m)
		for i, l := range a {
			ops = append(ops, diffOp{'-', l, i, 0})
		}
		for j, l := range b {
			ops = append(ops, diffOp{'+', l, n, j})
		}
		return ops
	}
	lcs := make([][]int32, n+1)
	for i := range lcs {
		lcs[i] = make([]int32, m+1)
	}
	for i := n - 1; i >= 0; i-- {
		for j := m - 1; j >= 0; j-- {
			if a[i] == b[j] {
				lcs[i][j] = lcs[i+1][j+1] + 1
			} else if lcs[i+1][j] >= lcs[i][j+1] {
				lcs[i][j] = lcs[i+1][j]
			} else {
				lcs[i][j] = lcs[i][j+1]
			}
		}
	}
	var ops []diffOp
	i, j := 0, 0
	for i < n || j < m {
		switch {
		case i < n && j < m && a[i] == b[j]:
			ops = append(ops, diffOp{' ', a[i], i, j})
			i++
			j++
		case j < m && (i == n || lcs[i][j+1] > lcs[i+1][j]):
			ops = append(ops, diffOp{'+', b[j], i, j})
			j++
		default:
			ops = append(ops, diffOp{'-', a[i], i, j})
			i++
		}
	}
	return ops
}

// structuredPatchDiff renders Claude Code's tool_use_result.structuredPatch.
func structuredPatchDiff(path string, hunks []any) string {
	var sb strings.Builder
	fmt.Fprintf(&sb, "--- a/%s\n+++ b/%s\n", path, path)
	for _, h := range hunks {
		hm, _ := h.(map[string]any)
		if hm == nil {
			continue
		}
		num := func(k string) int { f, _ := hm[k].(float64); return int(f) }
		fmt.Fprintf(&sb, "@@ -%d,%d +%d,%d @@\n", num("oldStart"), num("oldLines"), num("newStart"), num("newLines"))
		lines, _ := hm["lines"].([]any)
		for _, l := range lines {
			s, _ := l.(string)
			sb.WriteString(s)
			sb.WriteByte('\n')
		}
	}
	return sb.String()
}

// withHeader prefixes a bare hunk diff ("@@ ...") with file headers.
func withHeader(path, diff string) string {
	if strings.HasPrefix(diff, "---") || strings.HasPrefix(diff, "diff --git") {
		return diff
	}
	return fmt.Sprintf("--- a/%s\n+++ b/%s\n%s", path, path, diff)
}
