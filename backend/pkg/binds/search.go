package binds

import (
	"sort"
	"strings"
	"unicode"

	"yozakura/backend/pkg/brand"
)

// Result kinds.
const (
	KindAction     = "action"
	KindApp        = "app"
	KindCommand    = "command"
	KindRoutine    = "routine"
	KindWorkaround = "workaround"
)

// FieldInfo is an argument the caller fills before binds_set.
type FieldInfo struct {
	Key         string `json:"key"`
	Label       string `json:"label"`
	Placeholder string `json:"placeholder,omitempty"`
	Default     string `json:"default,omitempty"`
}

// Result is one search hit with the action to bind.
type Result struct {
	Kind   string      `json:"kind"`
	ID     string      `json:"id"`
	Label  string      `json:"label"`
	Group  string      `json:"group,omitempty"`
	Score  float64     `json:"score"`
	Action ActionRef   `json:"action"`
	Fields []FieldInfo `json:"fields,omitempty"`
	// Bound lists the combos already running this action.
	Bound []string `json:"bound,omitempty"`
	Note  string   `json:"note,omitempty"`
	// Compositors limits a workaround ("" = any).
	Compositors []string `json:"compositors,omitempty"`
}

const minScore = 0.4

// appVerbs let "open Firefox" / "запустить телеграм" match an app.
const appVerbs = "open launch start run app открыть запустить приложение"

type word struct {
	text   string
	weight float64
}

type alt struct {
	text   string
	weight float64
}

// tokens lower-cases and splits on anything but letters and digits.
func tokens(s string) []string {
	s = strings.ReplaceAll(strings.ToLower(s), "ё", "е")
	return strings.FieldsFunc(s, func(r rune) bool { return !unicode.IsLetter(r) && !unicode.IsDigit(r) })
}

// matchWord rates how well query word q matches word w (0..1): equal,
// prefix, shared stem (Russian inflection: "громкости" ~ "громкость"),
// substring.
func matchWord(q, w string) float64 {
	if q == w {
		return 1
	}
	rq, rw := []rune(q), []rune(w)
	if len(rq) >= 3 && strings.HasPrefix(w, q) {
		return 0.8
	}
	if len(rw) >= 4 && strings.HasPrefix(q, w) {
		return 0.7
	}
	n := 0
	for n < len(rq) && n < len(rw) && rq[n] == rw[n] {
		n++
	}
	short := min(len(rq), len(rw))
	if n >= 4 && n >= short-2 {
		return 0.85 // same word, another ending ("раскладку" ~ "раскладка")
	}
	if n >= 4 && float64(n) >= 0.6*float64(short) {
		return 0.6
	}
	if len(rq) >= 4 && strings.Contains(w, q) {
		return 0.5
	}
	return 0
}

// expand returns a query word and its synonyms.
func expand(q string) []alt {
	out := []alt{{q, 1}}
	seen := map[string]bool{q: true}
	for _, group := range synonyms {
		hit := false
		for _, s := range group {
			if matchWord(q, s) >= 0.7 || matchWord(s, q) >= 0.7 {
				hit = true
				break
			}
		}
		if !hit {
			continue
		}
		for _, s := range group {
			for _, t := range tokens(s) {
				if !seen[t] {
					seen[t] = true
					out = append(out, alt{t, 0.85})
				}
			}
		}
	}
	return out
}

// query is a parsed search query.
type query [][]alt

func parseQuery(s string) query {
	var q query
	for _, t := range tokens(s) {
		if !stopWords[t] {
			q = append(q, expand(t))
		}
	}
	return q
}

// score rates a haystack against the query: the mean over query words of
// the best (synonym-weighted) match.
func (q query) score(hay []word) float64 {
	if len(q) == 0 {
		return 0
	}
	total := 0.0
	for _, alts := range q {
		best := 0.0
		for _, a := range alts {
			for _, w := range hay {
				if s := a.weight * w.weight * matchWord(a.text, w.text); s > best {
					best = s
				}
			}
		}
		total += best
	}
	return total / float64(len(q))
}

func addWords(hay []word, s string, weight float64) []word {
	for _, t := range tokens(s) {
		hay = append(hay, word{t, weight})
	}
	return hay
}

func (a *Advisor) actionHay(act *Action) []word {
	var hay []word
	for _, l := range act.Labels {
		hay = addWords(hay, l, 1)
	}
	hay = addWords(hay, strings.TrimPrefix(act.ID, brand.AppID+"."), 0.9)
	hay = addWords(hay, actionKeywords[strings.TrimPrefix(act.ID, brand.AppID+".")], 0.9)
	hay = addWords(hay, act.Category, 0.5)
	for _, g := range a.Catalog.Groups {
		if g.ID == act.Group {
			hay = addWords(hay, g.ID, 0.5)
			for _, l := range g.Labels {
				hay = addWords(hay, l, 0.5)
			}
		}
	}
	return hay
}

func (a *Advisor) fieldsOf(act *Action) []FieldInfo {
	var out []FieldInfo
	for _, f := range act.Args {
		out = append(out, FieldInfo{Key: f.Key, Label: pick(f.Labels, a.lang(), f.Key), Placeholder: f.Placeholder, Default: f.Default})
	}
	return out
}

// Search finds what a bind could run: catalog actions, installed apps,
// launcher commands, routines and (when nothing fits well) workarounds,
// best first.
func (a *Advisor) Search(text string, limit int) ([]Result, error) {
	q := parseQuery(text)
	if len(q) == 0 {
		return []Result{}, nil
	}
	var shell []Bind
	if doc, err := loadDocument(a.File, a.appID()); err == nil {
		shell = a.shellBinds(doc)
	}
	var out []Result
	for i := range a.Catalog.Actions {
		act := &a.Catalog.Actions[i]
		if act.Hidden {
			continue
		}
		if s := q.score(a.actionHay(act)); s >= minScore {
			r := Result{Kind: KindAction, ID: act.ID, Label: act.Label(a.lang()), Group: act.Group, Score: s,
				Action: ActionRef{ID: act.ID, Args: map[string]any{}}, Fields: a.fieldsOf(act)}
			for _, f := range act.Args {
				r.Action.Args[f.Key] = f.Default
			}
			for _, b := range boundTo(shell, act.ID) {
				r.Bound = append(r.Bound, b.Combo)
			}
			out = append(out, r)
		}
	}
	out = append(out, a.searchApps(q, shell)...)
	out = append(out, a.searchCommands(q)...)
	out = append(out, a.searchRoutines(q)...)
	out = append(out, a.Workarounds(text)...)
	sort.SliceStable(out, func(i, j int) bool { return out[i].Score > out[j].Score })
	if limit > 0 && len(out) > limit {
		out = out[:limit]
	}
	for i := range out {
		out[i].Score = float64(int(out[i].Score*100+0.5)) / 100
	}
	return out, nil
}

func (a *Advisor) searchApps(q query, shell []Bind) []Result {
	if a.Apps == nil {
		return nil
	}
	var out []Result
	for _, app := range a.Apps() {
		hay := addWords(addWords(nil, app.Name, 1), app.ID, 0.8)
		hay = addWords(hay, appVerbs, 0.6)
		s := q.score(hay) * 0.95
		if s < 0.5 {
			continue
		}
		r := Result{Kind: KindApp, ID: app.ID, Label: app.Name, Group: "apps", Score: s,
			Action: ActionRef{ID: "apps.launch", Args: map[string]any{"app": app.ID}}}
		for _, b := range boundTo(shell, "apps.launch") {
			if len(b.Actions) > 0 && b.Actions[0].Args["app"] == app.ID {
				r.Bound = append(r.Bound, b.Combo)
			}
		}
		out = append(out, r)
	}
	return out
}

func (a *Advisor) searchCommands(q query) []Result {
	if a.Commands == nil {
		return nil
	}
	var out []Result
	for _, c := range a.Commands() {
		hay := addWords(nil, c.Label, 1)
		hay = addWords(hay, c.Keywords, 0.8)
		hay = addWords(hay, c.ID, 0.9)
		hay = addWords(hay, c.Help, 0.4)
		s := q.score(hay) * 0.9
		if s < minScore {
			continue
		}
		cmd := brand.Command("cmd", c.ID)
		r := Result{Kind: KindCommand, ID: c.ID, Label: c.Label, Group: "apps", Score: s,
			Action: ActionRef{ID: "command.run", Args: map[string]any{"command": cmd}},
			Note:   "launcher command (" + cmd + ")"}
		if c.Arg != nil && c.Arg.Required {
			r.Note = "launcher command; append its argument to the command: " + cmd + " <value>"
		}
		out = append(out, r)
	}
	return out
}

func (a *Advisor) searchRoutines(q query) []Result {
	if a.Routines == nil {
		return nil
	}
	var out []Result
	for _, rt := range a.Routines() {
		hay := addWords(addWords(nil, rt.Name, 1), rt.Keywords, 0.8)
		if s := q.score(hay); s >= minScore {
			out = append(out, Result{Kind: KindRoutine, ID: rt.ID, Label: rt.Name, Group: "apps", Score: s, Action: rt.Action})
		}
	}
	return out
}
