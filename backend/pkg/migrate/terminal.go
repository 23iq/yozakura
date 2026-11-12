package migrate

import (
	"encoding/json"
	"os"

	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/fsutil"
	"yozakura/backend/pkg/paths"
)

// Before the fastfetch greeting had its own files, terminal.greeting
// "fastfetch" only did something inside the fish prompt hook: with the
// prompt off it showed nothing. Now it runs in every terminal whether or
// not the prompt is on, so an update must not start showing it: once, a
// terminal.json from before (no fastfetchPreset key) with the greeting on
// and the prompt off gets greeting "none". fastfetchPreset is set to its
// default ("own", plain fastfetch: what fish showed) as the mark that the
// file was seen. Whether bash and zsh get the greeting is the term
// service's own record (termlook.GreetingAllShells), not a config key.

// EnsureTerminalGreeting runs on every start before the shell. A missing
// or unreadable file is left alone.
func EnsureTerminalGreeting(p paths.Paths) (bool, error) {
	if p.ConfigDir == "" {
		return false, nil
	}
	path := p.Config("terminal")
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, err
	}
	v, err := catalog.DecodeOrdered(data)
	if err != nil {
		return false, nil // malformed: the shell backs it up
	}
	doc, ok := v.(*catalog.Object)
	if !ok {
		return false, nil
	}
	if _, has := doc.Get("fastfetchPreset"); has {
		return false, nil
	}
	greeting, _ := doc.Get("greeting")
	enabled, _ := doc.Get("enabled")
	if greeting == "fastfetch" && enabled != true {
		doc.Set("greeting", "none")
	}
	doc.Set("fastfetchPreset", "own")
	out, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return false, err
	}
	return true, fsutil.WriteFile(path, out, 0o644)
}
