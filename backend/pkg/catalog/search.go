package catalog

import (
	"sort"
	"strings"
)

// Hit is one search result.
type Hit struct {
	Entry *Entry
	Score int
}

// Search ranks keys by how well every word of query matches their key,
// title, description, settings keywords and allowed values. Object keys
// are included (they group related settings).
func (c *Catalog) Search(query string, limit int) []Hit {
	words := strings.Fields(strings.ToLower(query))
	if len(words) == 0 {
		return nil
	}
	var hits []Hit
	for _, k := range c.order {
		e := c.entries[k]
		total := 0
		for _, w := range words {
			s := scoreWord(e, w)
			for _, syn := range synonyms[w] {
				s = max(s, scoreWord(e, syn)-1)
			}
			if s == 0 {
				total = 0
				break
			}
			total += s
		}
		if total > 0 {
			if !e.Leaf() {
				total-- // prefer the actual settings on ties
			}
			hits = append(hits, Hit{Entry: e, Score: total})
		}
	}
	sort.SliceStable(hits, func(i, j int) bool { return hits[i].Score > hits[j].Score })
	if limit > 0 && len(hits) > limit {
		hits = hits[:limit]
	}
	return hits
}

// synonyms maps everyday words to the vocabulary of the config keys.
var synonyms = map[string][]string{
	"transparency": {"opacity", "blur"}, "transparent": {"opacity", "blur"}, "translucent": {"opacity", "blur"},
	"rounded": {"roundness", "rounding", "radius"}, "corners": {"roundness", "rounding", "corner"},
	"radius": {"roundness", "rounding"}, "round": {"roundness", "rounding"},
	"dark": {"lightmode", "oled"}, "light": {"lightmode"}, "black": {"oled"},
	"hide": {"hidden", "reveal", "keephidden"}, "autohide": {"reveal", "pinned", "keephidden"},
	"size": {"height", "width", "size", "thickness", "scale"}, "big": {"size", "height", "width"},
	"speed": {"duration", "anim"}, "animation": {"anim", "duration", "transition"},
	"colour": {"color"}, "colours": {"color"}, "colors": {"color", "palette"},
	"font": {"font", "typography"}, "gaps": {"gapsin", "gapsout"}, "gap": {"gapsin", "gapsout", "spacing"},
	"taskbar": {"bar", "dock"}, "panel": {"bar"}, "island": {"notch", "islands"},
	"clock": {"clock", "time", "12h"}, "time": {"clock", "12h"},
	"border": {"border", "frame"}, "shadow": {"shadow"}, "edge": {"position"}, "side": {"position"},
	"wallpaper": {"wallpaper"}, "terminal": {"terminal", "kitty"}, "language": {"language", "locale"},
}

func scoreWord(e *Entry, w string) int {
	key := strings.ToLower(e.Key)
	last := strings.ToLower(e.Path[len(e.Path)-1])
	switch {
	case last == w:
		return 12
	case strings.HasPrefix(last, w):
		return 9
	case strings.Contains(key, w):
		return 7
	case strings.Contains(strings.ToLower(e.Title), w):
		return 6
	}
	if e.Settings != nil && strings.Contains(strings.ToLower(e.Settings.Keywords), w) {
		return 5
	}
	for _, v := range e.Enum {
		if strings.Contains(strings.ToLower(Scalar(v)), w) {
			return 4
		}
	}
	if strings.Contains(strings.ToLower(e.Description), w) {
		return 3
	}
	if e.Settings != nil && strings.Contains(strings.ToLower(e.Settings.EntryTitle+" "+e.Settings.Category), w) {
		return 2
	}
	return 0
}

// Suggest returns up to n existing keys closest to an unknown key.
func (c *Catalog) Suggest(key string, n int) []string {
	key = strings.ToLower(key)
	type cand struct {
		key  string
		dist int
	}
	var cands []cand
	last := key[strings.LastIndex(key, ".")+1:]
	domain := strings.SplitN(key, ".", 2)[0]
	for _, k := range c.order {
		lk := strings.ToLower(k)
		d := levenshtein(lk, key)
		if !strings.HasPrefix(lk, domain+".") {
			d += 3 // prefer keys of the same domain
		}
		kl := lk[strings.LastIndex(lk, ".")+1:]
		if kl == last || strings.Contains(kl, last) && len(last) >= 4 {
			d = min(d, 2)
		}
		if d <= max(3, len(key)/4) {
			cands = append(cands, cand{k, d})
		}
	}
	sort.SliceStable(cands, func(i, j int) bool { return cands[i].dist < cands[j].dist })
	var out []string
	for _, c := range cands {
		if len(out) == n {
			break
		}
		out = append(out, c.key)
	}
	return out
}

func levenshtein(a, b string) int {
	ra, rb := []rune(a), []rune(b)
	prev := make([]int, len(rb)+1)
	for j := range prev {
		prev[j] = j
	}
	for i := 1; i <= len(ra); i++ {
		cur := make([]int, len(rb)+1)
		cur[0] = i
		for j := 1; j <= len(rb); j++ {
			cost := 1
			if ra[i-1] == rb[j-1] {
				cost = 0
			}
			cur[j] = min(prev[j]+1, cur[j-1]+1, prev[j-1]+cost)
		}
		prev = cur
	}
	return prev[len(rb)]
}
