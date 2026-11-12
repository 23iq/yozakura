package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"text/tabwriter"

	"yozakura/backend/pkg/termlook"
)

const termGreetingHelp = `Usage: {bin} term greeting [--json]
       {bin} term greeting on|off
       {bin} term greeting preset <id>
       {bin} term greeting logo distro|sakura|none
       {bin} term greeting logo <file>
       {bin} term greeting presets [--json]
       {bin} term greeting preview [<preset>] [--logo distro|sakura|none|custom]

fastfetch when a terminal opens, in fish, bash and zsh (with or without the
prompt). Without arguments it shows the greeting: on or off, the look, the
logo and where it runs. A preset is a look (presets lists them; "own" runs
plain fastfetch with your own ~/.config/fastfetch config). The logo is the
distribution's, the sakura of the shell, none, or a file of yours: a text
file (ASCII art, $1..$9 colour markers or ANSI escapes) or a PNG, shown in
kitty (the sakura text logo elsewhere). Install fastfetch with
"{bin} extras install fastfetch".
`

// errUsage: the arguments match no form (the caller prints the usage).
var errUsage = errors.New("unknown arguments")

type termFetchPreset struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Logo        bool   `json:"logo"`
	Own         bool   `json:"own"`
}

// runTermGreeting implements `term greeting ...` (pos: the words after
// "greeting").
func runTermGreeting(env termEnv, pos []string, asJSON bool, logo string, out io.Writer) error {
	sub := ""
	if len(pos) > 0 {
		sub, pos = pos[0], pos[1:]
	}
	switch {
	case sub == "" && len(pos) == 0:
		return termGreetingShow(env, asJSON, out)
	case sub == "on" && len(pos) == 0:
		// switched on by the user: bash and zsh too (term.fetch.allow)
		if _, err := env.Call("term.fetch.allow", nil); err != nil {
			return err
		}
		return termGreetingSet(env, out, "greeting on", kv{"terminal.greeting", "fastfetch"})
	case sub == "off" && len(pos) == 0:
		return termGreetingSet(env, out, "greeting off", kv{"terminal.greeting", "none"})
	case sub == "preset" && len(pos) == 1:
		if _, err := termFetchPresetByID(env, pos[0]); err != nil {
			return err
		}
		return termGreetingSet(env, out, "greeting look set to "+pos[0], kv{"terminal.fastfetchPreset", pos[0]})
	case sub == "logo" && len(pos) == 1:
		return termGreetingLogo(env, pos[0], out)
	case sub == "presets" && len(pos) == 0:
		return termFetchPresetList(env, asJSON, out)
	case sub == "preview" && len(pos) <= 1:
		params := map[string]any{}
		if len(pos) == 1 {
			if !termPresetID.MatchString(pos[0]) {
				return fmt.Errorf("invalid preset id %q", pos[0])
			}
			params["preset"] = pos[0]
		}
		if logo != "" {
			params["logo"] = logo
		}
		return termGreetingPreview(env, params, out)
	}
	return errUsage
}

type kv struct {
	k string
	v any
}

// termGreetingSet writes config keys (validated by the catalog) and applies.
func termGreetingSet(env termEnv, out io.Writer, msg string, kvs ...kv) error {
	for _, p := range kvs {
		if err := env.SetConfig(p.k, p.v); err != nil {
			return err
		}
	}
	raw, err := env.Call("term.apply", nil)
	if err != nil {
		return fmt.Errorf("saved, but writing the greeting failed: %v", err)
	}
	fmt.Fprintln(out, msg)
	var st struct {
		Greeting termlook.GreetingStatus `json:"greeting"`
	}
	if json.Unmarshal(raw, &st) == nil && st.Greeting.On {
		greetingNotes(st.Greeting, out)
	}
	return nil
}

func termGreetingLogo(env termEnv, arg string, out io.Writer) error {
	switch arg {
	case termlook.LogoDistro, termlook.LogoSakura, termlook.LogoNone:
		return termGreetingSet(env, out, "greeting logo set to "+arg, kv{"terminal.fastfetchLogo", arg})
	case termlook.LogoCustom:
		return fmt.Errorf("give the logo file instead: term greeting logo <file>")
	}
	path, err := filepath.Abs(expandHome(arg))
	if err != nil {
		return err
	}
	logo, err := termlook.CheckLogoPath(path)
	if err != nil {
		return fmt.Errorf("%s: %s", arg, logoProblem(termlook.LogoError(err)))
	}
	msg := "greeting logo set to " + path
	if logo.Kind == termlook.LogoImage {
		msg += " (a picture: shown in kitty, the sakura text logo elsewhere)"
	}
	return termGreetingSet(env, out, msg, kv{"terminal.fastfetchLogoPath", path}, kv{"terminal.fastfetchLogo", termlook.LogoCustom})
}

func expandHome(p string) string {
	if p == "~" || strings.HasPrefix(p, "~/") {
		if home, err := os.UserHomeDir(); err == nil && home != "" {
			return home + p[1:]
		}
	}
	return p
}

// logoProblem says a logo check error key in words.
func logoProblem(key string) string {
	switch key {
	case "logo_path":
		return "not a usable path (absolute, no control characters)"
	case "logo_missing":
		return "cannot be read"
	case "logo_not_file":
		return "is not a regular file"
	case "logo_too_large":
		return fmt.Sprintf("is too large (text up to %d KiB, PNG up to %d MiB)", termlook.MaxTextLogo>>10, termlook.MaxImageLogo>>20)
	case "logo_format":
		return "is neither UTF-8 text nor a PNG image"
	}
	return key
}

func termFetchPresets(env usageCaller) ([]termFetchPreset, error) {
	raw, err := env.Call("term.fetch.presets", nil)
	if err != nil {
		return nil, err
	}
	var list []termFetchPreset
	return list, json.Unmarshal(raw, &list)
}

func termFetchPresetByID(env usageCaller, id string) (termFetchPreset, error) {
	if !termPresetID.MatchString(id) {
		return termFetchPreset{}, fmt.Errorf("invalid preset id %q (lowercase letters, digits and dashes)", id)
	}
	list, err := termFetchPresets(env)
	if err != nil {
		return termFetchPreset{}, err
	}
	ids := make([]string, 0, len(list))
	for _, p := range list {
		if p.ID == id {
			return p, nil
		}
		ids = append(ids, p.ID)
	}
	return termFetchPreset{}, fmt.Errorf("unknown preset %q (presets: %s)", id, strings.Join(ids, ", "))
}

func termFetchPresetList(env usageCaller, asJSON bool, out io.Writer) error {
	list, err := termFetchPresets(env)
	if err != nil {
		return err
	}
	if asJSON {
		return writeJSON(out, list)
	}
	tw := tabwriter.NewWriter(out, 0, 4, 2, ' ', 0)
	fmt.Fprintln(tw, "ID\tNAME\tLOGO")
	for _, p := range list {
		name := p.Name
		if p.Own {
			name = "your own fastfetch config"
		}
		fmt.Fprintf(tw, "%s\t%s\t%v\n", p.ID, name, p.Logo)
	}
	return tw.Flush()
}

func termGreetingShow(env termEnv, asJSON bool, out io.Writer) error {
	raw, err := env.Call("term.status", nil)
	if err != nil {
		return err
	}
	var st struct {
		Greeting termlook.GreetingStatus `json:"greeting"`
	}
	if err := json.Unmarshal(raw, &st); err != nil {
		return err
	}
	var term struct{ Preset, Logo, LogoPath string }
	for key, dst := range map[string]*string{"terminal.fastfetchPreset": &term.Preset,
		"terminal.fastfetchLogo": &term.Logo, "terminal.fastfetchLogoPath": &term.LogoPath} {
		if v, err := env.GetConfig(key); err == nil {
			*dst, _ = v.(string)
		}
	}
	if asJSON {
		return writeJSON(out, map[string]any{"greeting": st.Greeting, "preset": term.Preset, "logo": term.Logo, "logoPath": term.LogoPath})
	}
	g := st.Greeting
	fmt.Fprintf(out, "greeting: %s\n", map[bool]string{true: "on (fastfetch)", false: "off"}[g.On])
	if term.Preset != "" {
		fmt.Fprintf(out, "look: %s\n", term.Preset)
	}
	if term.Logo != "" && term.Preset != termlook.FetchOwn {
		logo := term.Logo
		if logo == termlook.LogoCustom {
			logo += " (" + term.LogoPath + ")"
		}
		fmt.Fprintf(out, "logo: %s\n", logo)
	}
	fmt.Fprintf(out, "fastfetch installed: %v\n", g.FastfetchInstalled)
	for _, sh := range g.Shells {
		fmt.Fprintf(out, "%s: %s\n", sh.Shell, shellNote(sh))
	}
	if g.On {
		greetingNotes(g, out)
	}
	return nil
}

func shellNote(sh termlook.ShellGreeting) string {
	switch sh.State {
	case termlook.ShellForeign:
		return "your " + sh.File + " runs a fetch tool itself (left alone)"
	case termlook.ShellManaged:
		return sh.File + " is read-only: add the line of greeting.sh yourself"
	case termlook.ShellAbsent:
		return "not installed (or no rc file)"
	case termlook.ShellBroken:
		return "the greeting's marker lines in " + sh.File + " were edited: fix or remove them by hand (left alone)"
	case termlook.ShellHeld:
		return "off (on from before the update, fish only: `" + branded("{bin}") + " term greeting on` adds the line to " + sh.File + ")"
	}
	return sh.State
}

// greetingNotes says what keeps the greeting from showing.
func greetingNotes(g termlook.GreetingStatus, out io.Writer) {
	if !g.FastfetchInstalled {
		fmt.Fprint(out, branded("note: fastfetch is not installed: run `{bin} extras install fastfetch`\n"))
	}
	if g.LogoError != "" {
		fmt.Fprintln(out, "note: the logo file "+logoProblem(g.LogoError)+"; the sakura logo is shown instead")
	}
}

func termGreetingPreview(env usageCaller, params map[string]any, out io.Writer) error {
	raw, err := env.Call("term.fetch.preview", params)
	if err != nil {
		return err
	}
	var pv struct {
		Lines     [][]termSpan `json:"lines"`
		Exact     bool         `json:"exact"`
		Reason    string       `json:"reason"`
		ImageLogo bool         `json:"imageLogo"`
	}
	if err := json.Unmarshal(raw, &pv); err != nil {
		return err
	}
	if !pv.Exact {
		if pv.Reason == "fastfetch_missing" {
			fmt.Fprint(out, branded("fastfetch is not installed: run `{bin} extras install fastfetch`\n"))
			return nil
		}
		return fmt.Errorf("fastfetch did not run (%s)", pv.Reason)
	}
	for _, line := range pv.Lines {
		fmt.Fprintln(out, termANSI(line))
	}
	if pv.ImageLogo {
		fmt.Fprintln(out, "(the picture logo shows in kitty; this is the text logo of other terminals)")
	}
	return nil
}
