package termlook

import (
	"strings"

	"yozakura/backend/pkg/brand"
)

// FishHook returns the content of the owned fish conf.d file. It is built
// from constants and the validated config path only. A path with control
// characters (newline, NUL...) cannot be quoted safely: FishHook returns ""
// and Apply reports the error.
func FishHook(cfg Config, configFile string) string {
	if strings.ContainsAny(configFile, "\n\r\x00") {
		return ""
	}
	q := fishQuote(configFile)
	var b strings.Builder
	b.WriteString("# Managed by " + brand.DisplayName + ". Remove this file or turn the prompt off in Settings.\n")
	b.WriteString("if status is-interactive\n")
	if cfg.Engine == EngineOMP {
		b.WriteString("    if type -q oh-my-posh\n")
		b.WriteString("        oh-my-posh init fish --config " + q + " | source\n")
		b.WriteString("    end\n")
	} else {
		// STARSHIP_CONFIG is never exported globally (shells started from
		// fish, a starship init of the user's, would read our file): each
		// prompt function starship defines gets it for its own call only.
		b.WriteString("    if type -q starship\n")
		b.WriteString("        starship init fish | source\n")
		for _, fn := range []string{"fish_prompt", "fish_right_prompt"} {
			inner := "__" + brand.AppID + "_starship_" + strings.TrimPrefix(fn, "fish_")
			b.WriteString("        if functions -q " + fn + "\n")
			b.WriteString("            functions -e " + inner + "\n")
			b.WriteString("            functions -c " + fn + " " + inner + "\n")
			b.WriteString("            function " + fn + "\n")
			b.WriteString("                STARSHIP_CONFIG=" + q + " " + inner + "\n")
			b.WriteString("            end\n")
			b.WriteString("        end\n")
		}
		b.WriteString("    end\n")
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
