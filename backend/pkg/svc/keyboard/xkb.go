package keyboard

import (
	"bufio"
	"errors"
	"io"
	"os"
	"strings"

	"yozakura/backend/pkg/yozd/ipc"
)

// Variant is one XKB layout variant.
type Variant struct {
	Name        string `json:"name"`
	Description string `json:"description"`
}

// Layout is one XKB layout with its variants.
type Layout struct {
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Variants    []Variant `json:"variants"`
}

// Option is one XKB option ("grp:alt_shift_toggle") in its Group ("grp").
type Option struct {
	Group       string `json:"group"`
	Name        string `json:"name"`
	Description string `json:"description"`
}

// Group describes an option group header ("grp" → "Switching to another
// layout").
type Group struct {
	Name        string `json:"name"`
	Description string `json:"description"`
}

// Catalog is the parsed rules list (evdev.lst).
type Catalog struct {
	Layouts []Layout `json:"layouts"`
	Options []Option `json:"options"`
	Groups  []Group  `json:"groups"`
}

// RulesPaths are the candidate rules lists, best first.
func RulesPaths() []string {
	var out []string
	if root := os.Getenv("XKB_CONFIG_ROOT"); root != "" {
		out = append(out, root+"/rules/evdev.lst", root+"/rules/base.lst")
	}
	return append(out, "/usr/share/X11/xkb/rules/evdev.lst", "/usr/share/X11/xkb/rules/base.lst")
}

// LoadCatalog parses the first readable file of paths.
func LoadCatalog(paths ...string) (*Catalog, error) {
	for _, p := range paths {
		f, err := os.Open(p)
		if err != nil {
			continue
		}
		c, err := ParseRules(f)
		f.Close()
		if err == nil {
			return c, nil
		}
	}
	return nil, errors.New("no xkb rules list found")
}

// ParseRules reads the "! layout", "! variant" and "! option" sections of
// an XKB .lst file. Variant lines are "name  layout: description"; option
// names without a colon are group headers.
func ParseRules(r io.Reader) (*Catalog, error) {
	c := &Catalog{Layouts: []Layout{}, Options: []Option{}, Groups: []Group{}}
	index := map[string]int{}
	section := ""
	sc := bufio.NewScanner(r)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		if name, ok := strings.CutPrefix(line, "!"); ok {
			section = strings.TrimSpace(name)
			continue
		}
		name, rest, _ := strings.Cut(line, " ")
		rest = strings.TrimSpace(rest)
		switch section {
		case "layout":
			index[name] = len(c.Layouts)
			c.Layouts = append(c.Layouts, Layout{Name: name, Description: rest, Variants: []Variant{}})
		case "variant":
			layout, desc, ok := strings.Cut(rest, ":")
			if i, known := index[layout]; ok && known {
				c.Layouts[i].Variants = append(c.Layouts[i].Variants, Variant{Name: name, Description: strings.TrimSpace(desc)})
			}
		case "option":
			if group, _, ok := strings.Cut(name, ":"); ok {
				c.Options = append(c.Options, Option{Group: group, Name: name, Description: rest})
			} else {
				c.Groups = append(c.Groups, Group{Name: name, Description: rest})
			}
		}
	}
	return c, sc.Err()
}

// Active is the resolved active layout: Code is the XKB layout ("ru"),
// Short the indicator label ("RU"; "EN" for us).
type Active struct {
	Name  string `json:"name"`
	Index int    `json:"index"`
	Code  string `json:"code"`
	Short string `json:"short"`
}

// layoutFor finds the layout whose description, or one of whose variant
// descriptions, is desc.
func (c *Catalog) layoutFor(desc string) (Layout, bool) {
	for _, l := range c.Layouts {
		if l.Description == desc {
			return l, true
		}
		for _, v := range l.Variants {
			if v.Description == desc {
				return l, true
			}
		}
	}
	return Layout{}, false
}

func (c *Catalog) isCode(name string) bool {
	for _, l := range c.Layouts {
		if l.Name == name {
			return true
		}
	}
	return false
}

// Resolve fills in the index and code of st. Hyprland reports layout codes
// in Names and always Index 0, so the index comes from matching Name (a
// description) against the configured codes; niri reports descriptions and
// a correct index.
func (c *Catalog) Resolve(st ipc.KeyboardLayoutState) Active {
	a := Active{Name: st.Name}
	codes := make([]string, len(st.Names))
	for i, n := range st.Names {
		if c.isCode(n) {
			codes[i] = n
		} else if l, ok := c.layoutFor(n); ok {
			codes[i] = l.Name
		}
	}
	match, found := c.layoutFor(st.Name)
	a.Index = -1
	if st.Index > 0 && st.Index < len(codes) {
		a.Index = st.Index
	} else if found {
		for i, code := range codes {
			if code == match.Name {
				a.Index = i
				break
			}
		}
	}
	switch {
	case a.Index >= 0 && codes[a.Index] != "":
		a.Code = codes[a.Index]
	case found:
		a.Code = match.Name
	}
	if a.Index < 0 {
		a.Index = 0
	}
	a.Short = ShortName(a.Code)
	return a
}

// ShortName is the indicator label for a layout code.
func ShortName(code string) string {
	if code == "us" {
		return "EN"
	}
	return strings.ToUpper(code)
}
