package main

import (
	"encoding/json"
	"fmt"
	"io"
	"strings"
	"text/tabwriter"

	"yozakura/backend/pkg/mcp/yozakura"
)

const providersHelp = `Usage: {bin} providers [list] [--json]
       {bin} providers test <provider> [--json]
       {bin} providers ollama [endpoint] [--json]

AI chat providers. list shows the providers with a stored key plus the
local servers (Ollama, LM Studio): whether each answers and how many models
it lists. test checks one provider and prints its models. ollama lists the
installed Ollama models with their capabilities (no model is loaded).
Only free model-listing requests are made; keys are never printed.
`

// runProviders implements `yozakura providers ...` against the daemon.
func runProviders(args []string, c usageCaller, out, errOut io.Writer) int {
	asJSON := false
	var rest []string
	for _, a := range args {
		switch a {
		case "--json":
			asJSON = true
		case "help", "-h", "--help":
			fmt.Fprint(out, branded(providersHelp))
			return 0
		default:
			rest = append(rest, a)
		}
	}
	sub := "list"
	if len(rest) > 0 {
		sub, rest = rest[0], rest[1:]
	}
	switch {
	case sub == "list" && len(rest) == 0:
		return printProviders(c, "", asJSON, out, errOut)
	case sub == "test" && len(rest) == 1:
		return printProviders(c, rest[0], asJSON, out, errOut)
	case sub == "ollama" && len(rest) <= 1:
		params := map[string]any{}
		if len(rest) == 1 {
			params["endpoint"] = rest[0]
		}
		return printOllama(c, params, asJSON, out, errOut)
	}
	fmt.Fprintf(errOut, "Error: unknown arguments %q\n", strings.Join(append([]string{sub}, rest...), " "))
	fmt.Fprint(errOut, branded(providersHelp))
	return 2
}

func printProviders(c usageCaller, only string, asJSON bool, out, errOut io.Writer) int {
	list, err := yozakura.ListProviders(c, only)
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v (is the shell running?)\n", err)
		return 1
	}
	if asJSON {
		_ = printJSON(out, list, nil)
		return 0
	}
	if len(list) == 0 {
		fmt.Fprintln(out, "No providers connected.")
		return 0
	}
	w := tabwriter.NewWriter(out, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "PROVIDER\tSTATUS\tMODELS\tNOTE")
	failed := false
	for _, p := range list {
		status, note := "ok", ""
		switch {
		case !p.OK:
			status, note, failed = "error", p.Error, failed || only != ""
		case !p.Verified:
			status, note = "saved", "checked on the first message"
		}
		if p.Local {
			note = strings.TrimSpace("local " + note)
		}
		fmt.Fprintf(w, "%s\t%s\t%d\t%s\n", p.Provider, status, len(p.Models), note)
	}
	_ = w.Flush()
	if only != "" && len(list) == 1 {
		for _, m := range list[0].Models {
			if m.Name != "" && m.Name != m.ID {
				fmt.Fprintf(out, "  %s (%s)\n", m.ID, m.Name)
			} else {
				fmt.Fprintf(out, "  %s\n", m.ID)
			}
		}
	}
	if failed {
		return 1
	}
	return 0
}

func printOllama(c usageCaller, params map[string]any, asJSON bool, out, errOut io.Writer) int {
	raw, err := c.Call("providers.ollama.probe", params)
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v (is the shell running?)\n", err)
		return 1
	}
	var probe struct {
		Endpoint  string `json:"endpoint"`
		Reachable bool   `json:"reachable"`
		Version   string `json:"version"`
		Error     string `json:"error"`
		Models    []struct {
			ID            string   `json:"id"`
			SizeLabel     string   `json:"sizeLabel"`
			ContextLength int      `json:"contextLength"`
			Capabilities  []string `json:"capabilities"`
		} `json:"models"`
	}
	if err := json.Unmarshal(raw, &probe); err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	if asJSON {
		fmt.Fprintln(out, string(raw))
		return 0
	}
	if !probe.Reachable {
		fmt.Fprintf(errOut, "Ollama at %s is not reachable: %s\n", probe.Endpoint, probe.Error)
		return 1
	}
	fmt.Fprintf(out, "Ollama %s at %s\n\n", probe.Version, probe.Endpoint)
	w := tabwriter.NewWriter(out, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "MODEL\tSIZE\tCONTEXT\tCAPABILITIES")
	for _, m := range probe.Models {
		ctx := "-"
		if m.ContextLength > 0 {
			ctx = fmt.Sprint(m.ContextLength)
		}
		fmt.Fprintf(w, "%s\t%s\t%s\t%s\n", m.ID, m.SizeLabel, ctx, strings.Join(m.Capabilities, ","))
	}
	_ = w.Flush()
	return 0
}
