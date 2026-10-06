package binds

import (
	"fmt"
	"strings"
	"unicode"
)

// reservedReason says why a combo should not be bound even when free
// (system or near-universal conventions); "" when it is fine.
func reservedReason(c Combo) string {
	mods := strings.Join(NormalizeMods(c.Modifiers), "+")
	k := NormalizeKey(c.Key)
	switch {
	case mods == "CTRL+ALT" && (k == "delete" || k == "backspace"):
		return "reserved by the system (session / X keys)"
	case mods == "CTRL+ALT" && len(k) >= 2 && k[0] == 'f' && isDigits(k[1:]):
		return "switches virtual terminals"
	case mods == "ALT" && (k == "tab" || k == "f4"):
		return "window switching / closing in most apps"
	case (mods == "SUPER" || mods == "SUPER+SHIFT") && len(k) == 1 && k[0] >= '0' && k[0] <= '9':
		return "workspace keys by convention (SUPER+N switches, SUPER+SHIFT+N moves)"
	case mods == "SUPER" && k == "l":
		return "lock screen by convention"
	case mods == "" && len([]rune(k)) == 1:
		return "a plain key without modifiers would stop it typing"
	case mods == "SHIFT" && len([]rune(k)) == 1:
		return "SHIFT + a character types it"
	}
	return ""
}

func isDigits(s string) bool {
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return s != ""
}

// CheckResult is whether a combo is free.
type CheckResult struct {
	Combo     string `json:"combo"`
	Free      bool   `json:"free"`
	Conflicts []Bind `json:"conflicts"`
	// Reserved is set for combos to avoid even when nothing uses them.
	Reserved        string `json:"reserved,omitempty"`
	CompositorError string `json:"compositorError,omitempty"`
}

// conflicts returns the enabled binds on combo (compositor binds in a
// submap other than the default do not count).
func conflicts(binds []Bind, id string) []Bind {
	out := []Bind{}
	for _, b := range binds {
		if b.Enabled && b.id == id && b.Submap == "" {
			out = append(out, b)
		}
	}
	return out
}

// Check tells whether combo is free across the shell's binds (core and
// custom) and the compositor's own.
func (a *Advisor) Check(combo string) (*CheckResult, error) {
	c, err := ParseCombo(combo)
	if err != nil {
		return nil, err
	}
	l, err := a.List()
	if err != nil {
		return nil, err
	}
	res := &CheckResult{Combo: c.String(), Conflicts: conflicts(l.Binds, c.ID()), Reserved: reservedReason(c), CompositorError: l.CompositorError}
	res.Free = len(res.Conflicts) == 0 && res.Reserved == ""
	return res, nil
}

// Suggestion is a free combo for an action.
type Suggestion struct {
	Combo  string `json:"combo"`
	Reason string `json:"reason"`
}

// SuggestResult holds the suggestions and the action they are for.
type SuggestResult struct {
	Action      *Result      `json:"action,omitempty"`
	Label       string       `json:"label"`
	Suggestions []Suggestion `json:"suggestions"`
	// Bound lists combos already running the action.
	Bound           []string `json:"bound,omitempty"`
	CompositorError string   `json:"compositorError,omitempty"`
}

var labelStopWords = map[string]bool{"open": true, "toggle": true, "show": true, "take": true, "the": true, "to": true, "a": true, "of": true, "(hold)": true}

// mnemonic returns the letters to try for a label: first letters of the
// significant words, then their other letters, then the rest of the label.
func mnemonic(label string) []rune {
	var first, rest, other []rune
	for _, w := range strings.Fields(strings.ToLower(label)) {
		letters := []rune{}
		for _, r := range w {
			if r < unicode.MaxASCII && (unicode.IsLetter(r) || unicode.IsDigit(r)) {
				letters = append(letters, r)
			}
		}
		if len(letters) == 0 {
			continue
		}
		if labelStopWords[w] {
			other = append(other, letters...)
			continue
		}
		first = append(first, letters[0])
		rest = append(rest, letters[1:]...)
	}
	seen := map[rune]bool{}
	var out []rune
	for _, r := range append(append(first, rest...), other...) {
		if !seen[r] && r >= 'a' && r <= 'z' {
			seen[r] = true
			out = append(out, r)
		}
	}
	return out
}

var suggestTiers = [][]string{{"SUPER"}, {"SUPER", "SHIFT"}, {"SUPER", "ALT"}, {"SUPER", "CTRL"}, {"SUPER", "CTRL", "SHIFT"}}

// Suggest proposes up to n free, ergonomic combos for an action id or a
// search query: SUPER + a letter of the label (mnemonic), then
// SUPER+SHIFT, SUPER+ALT, SUPER+CTRL with it, then other letters, skipping
// taken and reserved combos.
func (a *Advisor) Suggest(target string, n int) (*SuggestResult, error) {
	if n <= 0 {
		n = 5
	}
	res := &SuggestResult{Suggestions: []Suggestion{}}
	if act, ok := a.Catalog.Action(target); ok {
		res.Label = act.Label("en")
		res.Action = &Result{Kind: KindAction, ID: act.ID, Label: act.Label(a.lang()), Group: act.Group, Action: ActionRef{ID: act.ID, Args: map[string]any{}}}
	} else {
		hits, err := a.Search(target, 1)
		if err != nil {
			return nil, err
		}
		if len(hits) == 0 {
			return nil, fmt.Errorf("no action matches %q (try binds_search)", target)
		}
		res.Action = &hits[0]
		res.Label = hits[0].Label
		if act, ok := a.Catalog.Action(hits[0].ID); ok {
			res.Label = act.Label("en")
		}
	}
	l, err := a.List()
	if err != nil {
		return nil, err
	}
	res.CompositorError = l.CompositorError
	for _, b := range boundTo(l.Binds, res.Action.Action.ID) {
		if res.Action.Kind == KindAction {
			res.Bound = append(res.Bound, b.Combo)
		}
	}
	taken := map[string]bool{}
	for _, b := range l.Binds {
		if b.Enabled && b.Submap == "" {
			taken[b.id] = true
		}
	}
	letters := mnemonic(res.Label)
	inLabel := map[rune]bool{}
	for _, r := range letters {
		inLabel[r] = true
	}
	for r := 'a'; r <= 'z'; r++ {
		if !inLabel[r] {
			letters = append(letters, r)
		}
	}
	try := func(mods []string, r rune) bool {
		c := Combo{Modifiers: mods, Key: string(r)}.Stored()
		if taken[c.ID()] || reservedReason(c) != "" {
			return false
		}
		reason := "free"
		if inLabel[r] {
			reason = fmt.Sprintf("%s: “%s” is in “%s”", c.String(), strings.ToUpper(string(r)), res.Label)
		}
		res.Suggestions = append(res.Suggestions, Suggestion{Combo: c.String(), Reason: reason})
		taken[c.ID()] = true
		return len(res.Suggestions) >= n
	}
	// Mnemonic letters across the tiers first, then everything else.
	for _, phase := range []bool{true, false} {
		for _, mods := range suggestTiers {
			for _, r := range letters {
				if inLabel[r] != phase {
					continue
				}
				if try(mods, r) {
					return res, nil
				}
			}
		}
	}
	return res, nil
}
