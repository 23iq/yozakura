package termlook

import "strings"

// FishHook returns the content of the owned fish conf.d file. It is built
// from constants and the validated config path only.
func FishHook(cfg Config, configFile string) string {
	q := fishQuote(configFile)
	var b strings.Builder
	b.WriteString("# Managed by Yozakura. Remove this file or turn the prompt off in Settings.\n")
	b.WriteString("if status is-interactive\n")
	if cfg.Engine == EngineOMP {
		b.WriteString("    oh-my-posh init fish --config " + q + " | source\n")
	} else {
		b.WriteString("    set -gx STARSHIP_CONFIG " + q + "\n")
		b.WriteString("    starship init fish | source\n")
	}
	b.WriteString("end\n")
	if cfg.Greeting == "fastfetch" {
		b.WriteString("function fish_greeting\n    fastfetch\nend\n")
	} else {
		b.WriteString("set -g fish_greeting\n")
	}
	return b.String()
}

// fishQuote single-quotes s for fish; inside single quotes only \ and '
// are special.
func fishQuote(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	s = strings.ReplaceAll(s, `'`, `\'`)
	return "'" + s + "'"
}
