package main

import (
	"encoding/json"
	"fmt"
	"io"
	"regexp"
	"strconv"
	"strings"
	"text/tabwriter"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/termlook"
)

const termHelp = `Usage: {bin} term list [--json]
       {bin} term set <preset> [--engine starship|ohmyposh]
       {bin} term preview <preset> [--engine starship|ohmyposh] [--width <cols>]
       {bin} term status [--json]
       {bin} term off

The fish prompt (Starship or oh-my-posh) drawn with the shell palette: it
follows theme changes on its own. list shows the presets; set picks one and
turns the prompt on (it writes the engine config and a fish conf.d file,
never config.fish); preview draws one (exactly when the engine is
installed); off removes the fish file again. Install the engine with
"{bin} extras install starship" (or oh-my-posh), fish with "{bin} extras
install fish".
`

var termPresetID = regexp.MustCompile(`^[a-z0-9-]+$`)

// termEnv is the daemon and config access of `term`.
type termEnv interface {
	usageCaller
	SetConfig(key string, value any) error
}

type ipcTerm struct{ usageCaller }

func (ipcTerm) SetConfig(key string, value any) error {
	env, err := loadConfigEnv()
	if err != nil {
		return err
	}
	_, err = env.store.Set(key, value, false)
	return err
}

type termPreset struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	NerdFont    bool   `json:"nerdFont"`
	Lines       int    `json:"lines"`
}

// runTerm implements `yozakura term ...`.
func runTerm(args []string, env termEnv, out, errOut io.Writer) int {
	a := parseCLI(args, []string{"json", "help", "h"}, []string{"engine", "width"})
	sub := "list"
	if len(a.pos) > 0 {
		sub, a.pos = a.pos[0], a.pos[1:]
	}
	if sub == "help" || a.has("help") || a.has("h") {
		fmt.Fprint(out, branded(termHelp))
		return 0
	}
	engine, hasEngine := a.value("engine")
	if hasEngine && engine != termlook.EngineStarship && engine != termlook.EngineOMP {
		fmt.Fprintf(errOut, "Error: unknown engine %q (starship or ohmyposh)\n", engine)
		return 2
	}
	var err error
	switch {
	case sub == "list" && len(a.pos) == 0:
		err = termList(env, a.has("json"), out)
	case sub == "status" && len(a.pos) == 0:
		err = termStatus(env, a.has("json"), out)
	case sub == "off" && len(a.pos) == 0:
		err = termOff(env, out)
	case sub == "set" && len(a.pos) == 1:
		err = termSet(env, a.pos[0], engine, out)
	case sub == "preview" && len(a.pos) == 1:
		width := 0
		if w, ok := a.value("width"); ok {
			if width, err = strconv.Atoi(w); err != nil {
				fmt.Fprintf(errOut, "Error: --width needs a number\n")
				return 2
			}
		}
		err = termPreview(env, a.pos[0], engine, width, out)
	default:
		fmt.Fprint(errOut, "Error: unknown arguments\n"+branded(termHelp))
		return 2
	}
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	return 0
}

func termPresets(env usageCaller) ([]termPreset, error) {
	raw, err := env.Call("term.presets", nil)
	if err != nil {
		return nil, err
	}
	var list []termPreset
	return list, json.Unmarshal(raw, &list)
}

func termList(env usageCaller, asJSON bool, out io.Writer) error {
	list, err := termPresets(env)
	if err != nil {
		return err
	}
	if asJSON {
		return writeJSON(out, list)
	}
	tw := tabwriter.NewWriter(out, 0, 4, 2, ' ', 0)
	fmt.Fprintln(tw, "ID\tNAME\tLINES\tNERD FONT")
	for _, p := range list {
		fmt.Fprintf(tw, "%s\t%s\t%d\t%v\n", p.ID, p.Name, p.Lines, p.NerdFont)
	}
	return tw.Flush()
}

func termStatus(env usageCaller, asJSON bool, out io.Writer) error {
	raw, err := env.Call("term.status", nil)
	if err != nil {
		return err
	}
	if asJSON {
		_, err = fmt.Fprintln(out, string(raw))
		return err
	}
	var st struct {
		Enabled, FishInstalled, FishIsLoginShell, ForeignPromptInit bool
		EngineInstalled                                             map[string]bool
		ForeignFile                                                 string
	}
	if err := json.Unmarshal(raw, &st); err != nil {
		return err
	}
	fmt.Fprintf(out, "prompt enabled: %v\nfish installed: %v\nfish is your login shell: %v\n", st.Enabled, st.FishInstalled, st.FishIsLoginShell)
	fmt.Fprintf(out, "starship installed: %v\noh-my-posh installed: %v\n", st.EngineInstalled["starship"], st.EngineInstalled["ohmyposh"])
	if st.ForeignPromptInit {
		fmt.Fprintln(out, foreignPromptNote(st.ForeignFile))
	}
	return nil
}

func termSet(env termEnv, preset, engine string, out io.Writer) error {
	if !termPresetID.MatchString(preset) {
		return fmt.Errorf("invalid preset id %q (lowercase letters, digits and dashes)", preset)
	}
	list, err := termPresets(env)
	if err != nil {
		return err
	}
	ids := make([]string, 0, len(list))
	found := false
	for _, p := range list {
		ids = append(ids, p.ID)
		found = found || p.ID == preset
	}
	if !found {
		return fmt.Errorf("unknown preset %q (presets: %s)", preset, strings.Join(ids, ", "))
	}
	if engine != "" {
		if err := env.SetConfig("terminal.engine", engine); err != nil {
			return err
		}
	}
	for _, kv := range []struct {
		k string
		v any
	}{{"terminal.prompt", preset}, {"terminal.enabled", true}} {
		if err := env.SetConfig(kv.k, kv.v); err != nil {
			return err
		}
	}
	return termApplied(env, out, "prompt set to "+preset)
}

func termOff(env termEnv, out io.Writer) error {
	if err := env.SetConfig("terminal.enabled", false); err != nil {
		return err
	}
	return termApplied(env, out, "prompt off, fish file removed")
}

// termApplied runs the writer and reports missing pieces the user must install.
func termApplied(env usageCaller, out io.Writer, msg string) error {
	raw, err := env.Call("term.apply", nil)
	if err != nil {
		return fmt.Errorf("saved, but writing the prompt failed: %v", err)
	}
	fmt.Fprintln(out, msg)
	var st struct {
		Enabled, FishInstalled, FishIsLoginShell, ForeignPromptInit bool
		Engine, ForeignFile                                         string
		EngineInstalled                                             map[string]bool
	}
	if json.Unmarshal(raw, &st) != nil || !st.Enabled {
		return nil
	}
	engine, id := "starship", "starship"
	if st.Engine == termlook.EngineOMP {
		engine, id = "ohmyposh", "oh-my-posh"
	}
	if !st.EngineInstalled[engine] {
		fmt.Fprint(out, branded("note: "+id+" is not installed: run `{bin} extras install "+id+"`\n"))
	}
	if !st.FishInstalled {
		fmt.Fprint(out, branded("note: fish is not installed: run `{bin} extras install fish`\n"))
	} else if !st.FishIsLoginShell {
		fmt.Fprintln(out, "note: fish is not your login shell; the prompt shows in fish only (make it the default in Settings > Terminal)")
	}
	if st.ForeignPromptInit {
		fmt.Fprintln(out, foreignPromptNote(st.ForeignFile))
	}
	return nil
}

// foreignPromptNote says why the prompt is not installed: file (the
// user's own fish file) starts a prompt engine itself.
func foreignPromptNote(file string) string {
	if file == "" {
		file = "your fish config"
	}
	return "note: " + file + " starts starship or oh-my-posh itself, so " + brand.DisplayName +
		"'s prompt is not installed; remove that line to use it"
}

type termSpan struct {
	Text      string `json:"text"`
	FG        string `json:"fg"`
	BG        string `json:"bg"`
	Bold      bool   `json:"bold"`
	Italic    bool   `json:"italic"`
	Underline bool   `json:"underline"`
}

func termPreview(env usageCaller, preset, engine string, width int, out io.Writer) error {
	if !termPresetID.MatchString(preset) {
		return fmt.Errorf("invalid preset id %q", preset)
	}
	params := map[string]any{"prompt": preset, "width": width}
	if engine != "" {
		params["engine"] = engine
	}
	raw, err := env.Call("term.preview", params)
	if err != nil {
		return err
	}
	var pv struct {
		Left   [][]termSpan `json:"left"`
		Right  []termSpan   `json:"right"`
		Exact  bool         `json:"exact"`
		Engine string       `json:"engine"`
		Reason string       `json:"reason"`
	}
	if err := json.Unmarshal(raw, &pv); err != nil {
		return err
	}
	for _, line := range pv.Left {
		fmt.Fprintln(out, termANSI(line))
	}
	if len(pv.Right) > 0 {
		fmt.Fprintln(out, "right: "+termANSI(pv.Right))
	}
	if !pv.Exact {
		fmt.Fprintf(out, "(approximate preview: %s; install the engine for an exact one)\n", pv.Reason)
	}
	return nil
}

// termANSI draws spans as 24-bit SGR; colors are daemon-validated #rrggbb.
func termANSI(spans []termSpan) string {
	var b strings.Builder
	for _, s := range spans {
		var codes []string
		if s.Bold {
			codes = append(codes, "1")
		}
		if s.Italic {
			codes = append(codes, "3")
		}
		if s.Underline {
			codes = append(codes, "4")
		}
		codes = appendRGB(codes, "38", s.FG)
		codes = appendRGB(codes, "48", s.BG)
		if len(codes) == 0 {
			b.WriteString(s.Text)
			continue
		}
		b.WriteString("\x1b[" + strings.Join(codes, ";") + "m" + s.Text + "\x1b[0m")
	}
	return b.String()
}

func appendRGB(codes []string, kind, hex string) []string {
	if len(hex) != 7 || hex[0] != '#' {
		return codes
	}
	var rgb [3]string
	for i := range rgb {
		v, err := strconv.ParseUint(hex[1+2*i:3+2*i], 16, 8)
		if err != nil {
			return codes
		}
		rgb[i] = strconv.FormatUint(v, 10)
	}
	return append(codes, kind+";2;"+strings.Join(rgb[:], ";"))
}
