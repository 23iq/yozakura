package catalog

import "strings"

// Machine-local keys hold values that belong to this machine or person,
// never to a look: credentials (x-secret), commands the shell runs
// (format "command"), endpoints and personal paths (x-local, config/meta
// `local: true`) and whole private domains (LocalDomains). Presets never
// save, export, show or diff them, and applying a preset keeps the live
// ones (backend/pkg/presets).

// LocalDomains are config domains that are machine specific or private as
// a whole (general holds the terminal command the shell executes; specials,
// the special workspaces, are global like binds.json: switching presets
// never touches them; displays, the saved monitor layout, is specific to
// the machine and keyboard to the person).
var LocalDomains = map[string]bool{
	"system": true, "ai": true, "prefix": true, "weather": true, "notifications": true, "apps": true,
	"general": true, "specials": true, "displays": true, "keyboard": true,
}

// localSelf reports whether the entry itself is machine-local.
func localSelf(e *Entry) bool {
	return e.Secret || e.Local || e.Format == "command"
}

// ancestors calls fn for key and each enclosing object key, innermost first.
func (c *Catalog) ancestors(key string, fn func(*Entry) bool) bool {
	for k := key; strings.Contains(k, "."); k = k[:strings.LastIndex(k, ".")] {
		if e, ok := c.entries[k]; ok && fn(e) {
			return true
		}
	}
	return false
}

// MachineLocal reports whether a key (domain.path) is machine-local: in a
// local domain, or it or an enclosing object is a secret, a command or
// marked local.
func (c *Catalog) MachineLocal(key string) bool {
	if LocalDomains[strings.SplitN(key, ".", 2)[0]] {
		return true
	}
	return c.ancestors(key, localSelf)
}

// Secret reports whether a key is (or lies inside) a credential.
func (c *Catalog) Secret(key string) bool {
	return c.ancestors(key, func(e *Entry) bool { return e.Secret })
}

// LocalEntries lists the outermost machine-local entries of a domain
// (children of a listed object are not listed again).
func (c *Catalog) LocalEntries(domain string) []*Entry {
	var out []*Entry
	for _, k := range c.order {
		e := c.entries[k]
		if e.Domain != domain || !localSelf(e) {
			continue
		}
		if n := len(out); n > 0 && strings.HasPrefix(k, out[n-1].Key+".") {
			continue
		}
		out = append(out, e)
	}
	return out
}
