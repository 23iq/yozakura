package agents

import (
	"net/url"
	"regexp"
	"strconv"
	"strings"
)

// Policy decides which permission requests are answered automatically.
// Default ("safe auto, ask the rest"): only CatRead is auto-approved.
type Policy struct {
	AutoApprove []string `json:"autoApprove"`
}

// DefaultPolicy is used until the shell configures one.
func DefaultPolicy() Policy { return Policy{AutoApprove: []string{CatRead}} }

func (p Policy) auto(category string) bool {
	for _, c := range p.AutoApprove {
		if c == category {
			return true
		}
	}
	return false
}

// Decide returns the automatic decision for a request, or "" when the
// user has to be asked. rules holds "allow for this session" keys.
func (p Policy) Decide(req PermissionRequest, yolo bool, rules map[string]bool) string {
	if yolo {
		return DecisionAllow
	}
	if IsConfirmTool(req.Tool) {
		return ""
	}
	if req.RuleKey != "" && rules[req.RuleKey] {
		return DecisionAllow
	}
	if p.auto(req.Category) {
		return DecisionAllow
	}
	return ""
}

// ruleKey is what "allow for this session" remembers. For shell commands it
// is the whole parsed command (every segment and operator), so allowing
// `git status` does not allow `git push`. It is "" — no session rule is
// offered — when the command cannot be parsed exactly or runs a shell,
// interpreter, wrapper, script path or cd, whose effect is not fixed by the
// command line.
func ruleKey(tool, category string, input map[string]any) string {
	if IsConfirmTool(tool) {
		return ""
	}
	cmd, hasCmd := input["command"].(string)
	if !hasCmd && category != CatExec {
		return tool
	}
	segs, ok := parseScript(strings.TrimSpace(cmd))
	if !ok {
		return ""
	}
	var b strings.Builder
	for _, seg := range segs {
		if !sessionRuleAllowed(seg.argv[0]) {
			return ""
		}
		for _, a := range seg.argv {
			b.WriteString(strconv.Quote(a))
			b.WriteByte(' ')
		}
		b.WriteString(seg.op)
		b.WriteByte(' ')
	}
	return tool + ":" + strings.TrimSpace(b.String())
}

var noSessionRule = map[string]bool{
	"cd": true, "pushd": true, "popd": true, "sh": true, "bash": true, "zsh": true, "fish": true, "dash": true,
	"ksh": true, "mksh": true, "csh": true, "tcsh": true, "ash": true, "busybox": true, "nu": true, "xonsh": true,
	"env": true, "sudo": true, "doas": true, "su": true, "pkexec": true, "run0": true, "runuser": true,
	"xargs": true, "nice": true, "ionice": true, "nohup": true, "setsid": true, "timeout": true, "stdbuf": true,
	"time": true, "watch": true, "exec": true, "eval": true, "source": true, ".": true, "command": true,
	"builtin": true, "chroot": true, "unshare": true, "nsenter": true, "systemd-run": true, "flatpak-spawn": true,
	"node": true, "nodejs": true, "deno": true, "bun": true, "npx": true, "bunx": true, "pnpx": true, "uvx": true,
	"pipx": true, "osascript": true, "pwsh": true, "powershell": true, "tclsh": true, "wish": true, "awk": true,
	"gawk": true, "mawk": true, "expect": true, "Rscript": true, "julia": true, "ghci": true, "runghc": true,
}

var interpreterName = regexp.MustCompile(`^(python|pypy|perl|ruby|php|lua|luajit|node)[0-9.]*$`)

func sessionRuleAllowed(arg0 string) bool {
	if strings.ContainsAny(arg0, "/=") {
		return false // script path or env assignment
	}
	return !noSessionRule[arg0] && !interpreterName.MatchString(arg0)
}

// Yozakura MCP tools that only read state. Clipboard and notification
// readers are read-only too but expose private data (passwords, messages),
// so they are deliberately absent: they always ask.
var yozakuraReadOnly = map[string]bool{
	"config_schema": true, "config_get": true, "config_search": true, "config_describe": true, "presets_list": true,
	"preset_diff": true, "wallpapers_list": true,
	"windows_list": true, "workspaces_list": true, "media_status": true, "volume_get": true,
	"specials_list": true, "task_list": true, "task_status": true,
	"timer_list": true, "reminder_list": true, "binds_search": true, "binds_list": true, "binds_check": true,
	"binds_suggest": true, "routines_list": true, "notes_search": true, "notes_read": true, "apps_find": true,
	"system_info": true, "network_status": true, "bluetooth_status": true, "brightness_get": true,
}

// Yozakura MCP tools that always ask, even with "allow for this session"
// or an auto-approved MCP category: they change the user's keybinds,
// close windows or delete routines.
var yozakuraConfirm = map[string]bool{
	"binds_set": true, "binds_remove": true, "app_close": true, "routine_delete": true,
}

// IsConfirmTool reports a tool that must always be confirmed.
func IsConfirmTool(tool string) bool {
	parts := strings.SplitN(tool, "__", 3)
	return len(parts) == 3 && parts[0] == "mcp" && parts[1] == YozakuraMCPName && yozakuraConfirm[parts[2]]
}

var claudeReadTools = map[string]bool{
	"Read": true, "Glob": true, "Grep": true, "LS": true, "NotebookRead": true, "TodoWrite": true,
	"TodoRead": true, "ToolSearch": true, "Task": true, "Agent": true, "TaskCreate": true, "TaskGet": true,
	"TaskList": true, "TaskUpdate": true, "TaskOutput": true, "BashOutput": true, "Skill": true,
	"ListMcpResourcesTool": true, "ReadMcpResourceTool": true,
}

var claudeWriteTools = map[string]bool{"Edit": true, "MultiEdit": true, "Write": true, "NotebookEdit": true}

// Classify maps a tool invocation to a permission category. It knows the
// Claude Code tool names, Codex/ACP kinds and MCP tool names.
func Classify(tool string, input map[string]any) string {
	if strings.HasPrefix(tool, "mcp__") {
		parts := strings.SplitN(tool, "__", 3)
		if len(parts) == 3 && parts[1] == YozakuraMCPName && yozakuraReadOnly[parts[2]] {
			return CatRead
		}
		return CatMCP
	}
	switch {
	case claudeReadTools[tool]:
		return CatRead
	case claudeWriteTools[tool]:
		return CatWrite
	case tool == "WebFetch" || tool == "WebSearch":
		return CatNetwork
	case tool == "Bash" || tool == "shell":
		cmd, _ := input["command"].(string)
		if IsSafeCommand(cmd) {
			return CatRead
		}
		return CatExec
	}
	// ACP tool kinds.
	switch tool {
	case "read", "search", "think":
		return CatRead
	case "edit", "delete", "move", "apply_patch":
		return CatWrite
	case "execute":
		cmd, _ := input["command"].(string)
		if IsSafeCommand(cmd) {
			return CatRead
		}
		return CatExec
	case "fetch":
		return CatNetwork
	}
	return CatOther
}

// unwrapShell turns `/usr/bin/bash -lc "script"` (Codex) into `script`.
func unwrapShell(cmd string) string {
	c := strings.TrimSpace(cmd)
	for _, sh := range []string{"bash", "sh", "zsh"} {
		for _, flag := range []string{" -lc ", " -c "} {
			for _, prefix := range []string{"/usr/bin/" + sh, "/bin/" + sh, sh} {
				if strings.HasPrefix(c, prefix+flag) {
					rest := strings.TrimSpace(c[len(prefix+flag):])
					if len(rest) >= 2 && (rest[0] == '"' || rest[0] == '\'') && rest[len(rest)-1] == rest[0] {
						rest = rest[1 : len(rest)-1]
						if c[len(prefix+flag)] == '"' {
							rest = strings.ReplaceAll(rest, `\"`, `"`)
							rest = strings.ReplaceAll(rest, `\\`, `\`)
						}
					}
					return rest
				}
			}
		}
	}
	return c
}

// toolTitle builds the short human summary shown on tool cards.
func toolTitle(tool string, input map[string]any, cwd string) string {
	str := func(k string) string { v, _ := input[k].(string); return v }
	rel := func(p string) string {
		if cwd != "" && strings.HasPrefix(p, cwd+"/") {
			return strings.TrimPrefix(p, cwd+"/")
		}
		return p
	}
	if strings.HasPrefix(tool, "mcp__") {
		parts := strings.SplitN(tool, "__", 3)
		if len(parts) == 3 {
			return parts[1] + ": " + parts[2]
		}
	}
	switch tool {
	case "Bash", "shell", "execute":
		if c := str("command"); c != "" {
			return "$ " + oneLine(unwrapShell(c), 120)
		}
	case "Read", "read":
		if p := str("file_path") + str("path"); p != "" {
			return "Read " + rel(p)
		}
	case "Edit", "MultiEdit", "edit", "apply_patch":
		if p := str("file_path") + str("path"); p != "" {
			return "Edit " + rel(p)
		}
	case "Write":
		if p := str("file_path"); p != "" {
			return "Write " + rel(p)
		}
	case "Grep", "Glob":
		if p := str("pattern"); p != "" {
			return tool + " " + oneLine(p, 80)
		}
	case "WebFetch", "fetch":
		if u, err := url.Parse(str("url")); err == nil && u.Host != "" {
			return "Fetch " + u.Host
		}
	case "WebSearch":
		if q := str("query"); q != "" {
			return "Search " + oneLine(q, 80)
		}
	}
	return tool
}

func oneLine(s string, max int) string {
	s = strings.Join(strings.Fields(s), " ")
	if len([]rune(s)) > max {
		r := []rune(s)
		return string(r[:max-1]) + "…"
	}
	return s
}
