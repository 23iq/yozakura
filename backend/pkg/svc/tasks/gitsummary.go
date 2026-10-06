package tasks

import (
	"strconv"
	"strings"
)

// GitSummary is tasks.git: the state of a project checkout for the
// project bar (branch, ahead/behind its upstream, changed files).
type GitSummary struct {
	Dir       string `json:"dir"`
	IsRepo    bool   `json:"isRepo"`
	Root      string `json:"root,omitempty"`
	Branch    string `json:"branch"`
	Head      string `json:"head"`
	Detached  bool   `json:"detached"`
	Upstream  string `json:"upstream,omitempty"`
	Ahead     int    `json:"ahead"`
	Behind    int    `json:"behind"`
	Changed   int    `json:"changed"` // files with any change (incl. untracked)
	Staged    int    `json:"staged"`
	Unstaged  int    `json:"unstaged"`
	Untracked int    `json:"untracked"`
	Conflicts int    `json:"conflicts"`
}

// Summarize reads `git status --porcelain=v2 --branch` of dir.
func Summarize(dir string) GitSummary {
	s := GitSummary{Dir: dir}
	out, err := gitRaw(dir, nil, "status", "--porcelain=v2", "--branch", "-z", "--untracked-files=normal")
	if err != nil {
		return s
	}
	s.IsRepo = true
	s.Root, _ = repoRoot(dir)
	parseStatusV2(string(out), &s)
	return s
}

func parseStatusV2(out string, s *GitSummary) {
	entries := strings.Split(out, "\x00")
	for i := 0; i < len(entries); i++ {
		e := entries[i]
		switch {
		case strings.HasPrefix(e, "# branch.oid "):
			s.Head = strings.TrimPrefix(e, "# branch.oid ")
		case strings.HasPrefix(e, "# branch.head "):
			s.Branch = strings.TrimPrefix(e, "# branch.head ")
			s.Detached = s.Branch == "(detached)"
		case strings.HasPrefix(e, "# branch.upstream "):
			s.Upstream = strings.TrimPrefix(e, "# branch.upstream ")
		case strings.HasPrefix(e, "# branch.ab "):
			f := strings.Fields(strings.TrimPrefix(e, "# branch.ab "))
			if len(f) == 2 {
				s.Ahead, _ = strconv.Atoi(strings.TrimPrefix(f[0], "+"))
				s.Behind, _ = strconv.Atoi(strings.TrimPrefix(f[1], "-"))
			}
		case strings.HasPrefix(e, "1 "), strings.HasPrefix(e, "2 "):
			s.Changed++
			if len(e) > 3 {
				if e[2] != '.' {
					s.Staged++
				}
				if e[3] != '.' {
					s.Unstaged++
				}
			}
			if e[0] == '2' {
				i++ // rename source path
			}
		case strings.HasPrefix(e, "u "):
			s.Changed++
			s.Conflicts++
		case strings.HasPrefix(e, "? "):
			s.Changed++
			s.Untracked++
		}
	}
	if s.Detached {
		s.Branch = ""
	}
}
