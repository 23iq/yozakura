package tasks

import (
	"path/filepath"
	"regexp"
	"strings"
	"sync"

	"yozakura/backend/pkg/svc/agents"
)

// sessionScope is what the permission hook knows about a task session.
type sessionScope struct {
	worktree string
	inPlace  bool
	planning bool
}

// scopes maps agent session ids to their task scope. It has its own lock
// because the hook runs under the agents manager lock.
type scopes struct {
	mu sync.RWMutex
	m  map[string]sessionScope
}

func (s *scopes) set(id string, sc sessionScope) {
	s.mu.Lock()
	if s.m == nil {
		s.m = map[string]sessionScope{}
	}
	s.m[id] = sc
	s.mu.Unlock()
}

func (s *scopes) drop(id string) {
	s.mu.Lock()
	delete(s.m, id)
	s.mu.Unlock()
}

func (s *scopes) get(id string) (sessionScope, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	sc, ok := s.m[id]
	return sc, ok
}

// decide is the agents.PermissionHook for task sessions:
//   - planning: file writes are refused (the agent only plans);
//   - worktree runs: reads, web reads, edits inside the worktree and
//     commands are approved without asking, except the deny list
//     (DeniedCommand) and edits outside the worktree, which ask;
//   - in-place runs and other sessions: "" (the normal policy asks).
func (s *scopes) decide(meta agents.SessionMeta, req agents.PermissionRequest) string {
	sc, ok := s.get(meta.ID)
	if !ok {
		return ""
	}
	if sc.planning {
		if req.Category == agents.CatWrite {
			return agents.DecisionDeny
		}
		return ""
	}
	if sc.inPlace {
		return ""
	}
	in, _ := req.Input.(map[string]any)
	switch req.Category {
	case agents.CatRead, agents.CatNetwork:
		return agents.DecisionAllow
	case agents.CatWrite:
		p := req.Path
		for _, k := range []string{"file_path", "path", "notebook_path"} {
			if v, _ := in[k].(string); p == "" && v != "" {
				p = v
			}
		}
		if p != "" && insideDir(sc.worktree, p) {
			return agents.DecisionAllow
		}
	case agents.CatExec:
		cmd, _ := in["command"].(string)
		if cmd == "" {
			if argv, ok := in["command"].([]any); ok {
				parts := make([]string, 0, len(argv))
				for _, a := range argv {
					if s, ok := a.(string); ok {
						parts = append(parts, s)
					}
				}
				cmd = strings.Join(parts, " ")
			}
		}
		if cmd != "" && DeniedCommand(cmd, sc.worktree) == "" {
			return agents.DecisionAllow
		}
	}
	return ""
}

// insideDir reports whether p (absolute, or relative to dir) stays in dir.
func insideDir(dir, p string) bool {
	if !filepath.IsAbs(p) {
		p = filepath.Join(dir, p)
	}
	p = filepath.Clean(p)
	dir = filepath.Clean(dir)
	return p == dir || strings.HasPrefix(p, dir+string(filepath.Separator))
}

var (
	segmentSplit = regexp.MustCompile(`\|\||&&|[;|&\n]`)
	redirectOut  = regexp.MustCompile(`\d*>>?\s*([^\s;|&]+)`)
	networkTools = map[string]bool{"scp": true, "sftp": true, "ssh": true, "ftp": true, "nc": true, "ncat": true,
		"netcat": true, "socat": true, "telnet": true, "rsh": true}
	privTools = map[string]bool{"sudo": true, "doas": true, "su": true, "pkexec": true, "run0": true}
	sysTools  = map[string]bool{"dd": true, "shutdown": true, "reboot": true, "poweroff": true, "systemctl": true,
		"mount": true, "umount": true, "crontab": true}
	fileTools = map[string]bool{"rm": true, "rmdir": true, "mv": true, "cp": true, "install": true, "ln": true,
		"chmod": true, "chown": true, "truncate": true, "touch": true, "mkdir": true, "tee": true, "shred": true}
)

// DeniedCommand returns why a shell command inside a task worktree must
// still ask the user, or "" when it may run unattended. It is a guard
// against accidents (pushing, publishing, network writes, privileged or
// destructive commands outside the worktree), not a sandbox.
func DeniedCommand(cmd, worktree string) string {
	c := unwrapShell(cmd)
	if strings.Contains(c, "`") || strings.Contains(c, "$(") || strings.Contains(c, "<(") {
		return "command substitution"
	}
	for _, m := range redirectOut.FindAllStringSubmatch(c, -1) {
		target := strings.Trim(m[1], `"'`)
		if target != "/dev/null" && !strings.HasPrefix(target, "&") && !safePath(target, worktree) {
			return "writes outside the worktree"
		}
	}
	for _, seg := range segmentSplit.Split(c, -1) {
		argv := strings.Fields(seg)
		for len(argv) > 0 && strings.Contains(argv[0], "=") && !strings.HasPrefix(argv[0], "-") {
			argv = argv[1:] // VAR=value prefixes
		}
		if len(argv) == 0 {
			continue
		}
		if why := deniedArgv(argv, worktree); why != "" {
			return why
		}
	}
	return ""
}

func deniedArgv(argv []string, worktree string) string {
	name := filepath.Base(argv[0])
	args := argv[1:]
	has := func(flags ...string) bool {
		for _, a := range args {
			for _, f := range flags {
				if a == f || (strings.HasPrefix(f, "--") && strings.HasPrefix(a, f+"=")) ||
					(len(f) == 2 && f[0] == '-' && f[1] != '-' && strings.HasPrefix(a, f) && !strings.HasPrefix(a, "--")) {
					return true
				}
			}
		}
		return false
	}
	switch {
	case privTools[name]:
		return "privileged command"
	case networkTools[name]:
		return "remote access"
	case sysTools[name] || strings.HasPrefix(name, "mkfs"):
		return "system command"
	case name == "git" && len(args) > 0:
		switch sub := gitSubcommand(args); sub {
		case "push", "send-email", "request-pull":
			return "git " + sub
		case "remote":
			return "git remote"
		case "config":
			if has("--global", "--system") {
				return "git config --global"
			}
		}
	case name == "gh" || name == "glab":
		return name + " (forge write)"
	case name == "curl":
		if has("-X", "--request", "-d", "--data", "--data-raw", "--data-binary", "--data-urlencode", "-F", "--form",
			"-T", "--upload-file", "--json") {
			return "network write (curl)"
		}
	case name == "wget":
		if has("--post-data", "--post-file", "--method", "--body-data", "--body-file") {
			return "network write (wget)"
		}
	case name == "rsync":
		for _, a := range args {
			if !strings.HasPrefix(a, "-") && strings.Contains(a, ":") {
				return "remote copy (rsync)"
			}
		}
	case fileTools[name]:
		targets := nonFlags(args)
		if name == "cp" || name == "install" {
			targets = targets[max(len(targets)-1, 0):] // only the destination is written
		}
		for _, a := range targets {
			if !safePath(a, worktree) {
				return name + " outside the worktree"
			}
		}
	case (name == "npm" || name == "pnpm" || name == "yarn" || name == "cargo" || name == "twine" ||
		name == "docker" || name == "podman") && firstNonFlag(args) == "publish",
		(name == "docker" || name == "podman") && firstNonFlag(args) == "push":
		return name + " " + firstNonFlag(args)
	}
	return ""
}

func nonFlags(args []string) []string {
	var out []string
	for _, a := range args {
		if !strings.HasPrefix(a, "-") {
			out = append(out, a)
		}
	}
	return out
}

// gitSubcommand skips git's global options (-C dir, -c k=v, ...).
func gitSubcommand(args []string) string {
	for i := 0; i < len(args); i++ {
		switch a := args[i]; {
		case a == "-C" || a == "-c" || a == "--git-dir" || a == "--work-tree" || a == "--namespace":
			i++
		case strings.HasPrefix(a, "-"):
		default:
			return a
		}
	}
	return ""
}

func firstNonFlag(args []string) string {
	for _, a := range args {
		if !strings.HasPrefix(a, "-") {
			return a
		}
	}
	return ""
}

// safePath reports whether a command argument names a path in the worktree.
func safePath(p, worktree string) bool {
	p = strings.Trim(p, `"'`)
	if p == "" || strings.HasPrefix(p, "~") || strings.Contains(p, "$") {
		return false
	}
	return insideDir(worktree, p)
}

// unwrapShell turns `bash -lc "script"` into script.
func unwrapShell(cmd string) string {
	c := strings.TrimSpace(cmd)
	for _, sh := range []string{"/usr/bin/bash", "/bin/bash", "bash", "/usr/bin/sh", "/bin/sh", "sh", "/usr/bin/zsh", "zsh"} {
		for _, flag := range []string{" -lc ", " -c "} {
			if rest, ok := strings.CutPrefix(c, sh+flag); ok {
				rest = strings.TrimSpace(rest)
				if len(rest) >= 2 && (rest[0] == '"' || rest[0] == '\'') && rest[len(rest)-1] == rest[0] {
					rest = rest[1 : len(rest)-1]
				}
				return rest
			}
		}
	}
	return c
}
