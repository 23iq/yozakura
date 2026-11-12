package termlook

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"yozakura/backend/pkg/apphooks"
)

// fetchRun matches a line that runs a system-info tool as a command (not
// `command -v fastfetch`, not an alias definition).
var fetchRun = regexp.MustCompile(`(^|[;&|({]\s*|\b(then|do|else|and|or|exec|command)\s+)(fastfetch|neofetch|hyfetch|pfetch)(\s|;|&|\||\)|$)`)

// runsFetch reports an uncommented line of shell code that runs fastfetch
// (or another fetch tool) itself.
func runsFetch(content string) bool {
	for _, line := range strings.Split(content, "\n") {
		t := strings.TrimSpace(line)
		if t == "" || strings.HasPrefix(t, "#") {
			continue
		}
		if fetchRun.MatchString(t) {
			return true
		}
	}
	return false
}

// foreignFetch returns the first file of the user's that runs a fetch tool
// when the shell starts ("" none); our own block and files do not count.
func foreignFetch(shell string, env Env) string {
	var files []string
	switch shell {
	case "fish":
		dir := filepath.Join(env.ConfigHome, "fish")
		files = append(files, filepath.Join(dir, "config.fish"), filepath.Join(dir, "functions", "fish_greeting.fish"))
		more, _ := filepath.Glob(filepath.Join(dir, "conf.d", "*.fish"))
		for _, f := range more {
			if f != FishGreetingFile(env) && f != HookFile(env) {
				files = append(files, f)
			}
		}
	default:
		rc, others := rcFiles(shell, env)
		files = append([]string{rc}, others...)
	}
	for _, f := range files {
		data, err := os.ReadFile(f)
		if err != nil {
			continue
		}
		content, _ := apphooks.RemoveBlock(string(data), rcMarker(env))
		if runsFetch(content) {
			return f
		}
	}
	return ""
}
