package tasks

import (
	"errors"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"yozakura/backend/pkg/brand"
)

// Template is a reusable task prompt: a Markdown file with an optional
// front matter block (name, description, mode, agent).
//
//	---
//	name: Review
//	description: Review the current changes
//	mode: run
//	---
//	Review this diff: {{diff}}
//
// Placeholders: {{input}} (text typed after the /command), {{selection}},
// {{file}}, {{clipboard}} (passed by the caller in vars), {{diff}} (the
// project's uncommitted diff), {{staged}} (staged diff), {{branch}},
// {{project}} (directory name), {{check}} (the effective check command).
// Unknown placeholders are left as they are.
type Template struct {
	ID          string `json:"id"` // file name without .md ("review")
	Name        string `json:"name"`
	Description string `json:"description"`
	Mode        string `json:"mode,omitempty"`
	Agent       string `json:"agent,omitempty"`
	Source      string `json:"source"` // bundled | global | project
	Path        string `json:"path"`
	Body        string `json:"body,omitempty"`
}

// TemplateDirs are the template locations, lowest precedence first.
type TemplateDirs struct {
	Bundled string // <shell source>/assets/ai/task-templates
	Global  string // ~/.config/<app>/task-templates
}

// ProjectTemplateDir is where a project keeps its own templates.
func ProjectTemplateDir(project string) string {
	return filepath.Join(project, "."+brand.AppID, "templates")
}

// ListTemplates merges bundled, global and project templates; later
// sources override earlier ones with the same id. Bodies are omitted.
func ListTemplates(d TemplateDirs, project string) []Template {
	byID := map[string]Template{}
	for _, src := range d.sources(project) {
		entries, err := os.ReadDir(src.dir)
		if err != nil {
			continue
		}
		for _, e := range entries {
			if e.IsDir() || !strings.HasSuffix(e.Name(), ".md") {
				continue
			}
			t, err := readTemplate(filepath.Join(src.dir, e.Name()), src.name)
			if err != nil {
				continue
			}
			t.Body = ""
			byID[t.ID] = t
		}
	}
	out := make([]Template, 0, len(byID))
	for _, t := range byID {
		out = append(out, t)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out
}

// GetTemplate returns the effective template with its body.
func GetTemplate(d TemplateDirs, project, id string) (Template, error) {
	if id == "" || strings.ContainsAny(id, `/\`) || strings.HasPrefix(id, ".") {
		return Template{}, errors.New("invalid template id")
	}
	srcs := d.sources(project)
	for i := len(srcs) - 1; i >= 0; i-- {
		if t, err := readTemplate(filepath.Join(srcs[i].dir, id+".md"), srcs[i].name); err == nil {
			return t, nil
		}
	}
	return Template{}, errors.New("unknown template: " + id)
}

type tmplSource struct{ name, dir string }

func (d TemplateDirs) sources(project string) []tmplSource {
	var out []tmplSource
	if d.Bundled != "" {
		out = append(out, tmplSource{"bundled", d.Bundled})
	}
	if d.Global != "" {
		out = append(out, tmplSource{"global", d.Global})
	}
	if project != "" {
		out = append(out, tmplSource{"project", ProjectTemplateDir(project)})
	}
	return out
}

func readTemplate(path, source string) (Template, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return Template{}, err
	}
	id := strings.TrimSuffix(filepath.Base(path), ".md")
	t := Template{ID: id, Name: id, Source: source, Path: path}
	body := strings.ReplaceAll(string(data), "\r\n", "\n")
	if rest, ok := strings.CutPrefix(body, "---\n"); ok {
		if head, after, found := strings.Cut(rest, "\n---"); found {
			for _, line := range strings.Split(head, "\n") {
				k, v, ok := strings.Cut(line, ":")
				if !ok {
					continue
				}
				v = strings.Trim(strings.TrimSpace(v), `"'`)
				switch strings.TrimSpace(k) {
				case "name":
					t.Name = v
				case "description":
					t.Description = v
				case "mode":
					t.Mode = v
				case "agent":
					t.Agent = v
				}
			}
			body = strings.TrimPrefix(after, "\n")
			body = strings.TrimPrefix(body, "\n")
		}
	}
	t.Body = strings.TrimSpace(body)
	return t, nil
}

var placeholder = regexp.MustCompile(`\{\{\s*([a-z_]+)\s*\}\}`)

// Render fills placeholders from vars; computed ones (diff, staged,
// branch, project, check) are only evaluated when the body uses them.
func Render(body string, vars map[string]string, project string, check func() string) string {
	cache := map[string]string{}
	return placeholder.ReplaceAllStringFunc(body, func(m string) string {
		key := placeholder.FindStringSubmatch(m)[1]
		if v, ok := vars[key]; ok {
			return v
		}
		if v, ok := cache[key]; ok {
			return v
		}
		v, ok := computed(key, project, check)
		if !ok {
			return m
		}
		cache[key] = v
		return v
	})
}

const maxDiffBytes = 48 << 10

func computed(key, project string, check func() string) (string, bool) {
	clip := func(s string) string {
		if len(s) > maxDiffBytes {
			return s[:maxDiffBytes] + "\n… (diff truncated)"
		}
		return s
	}
	switch key {
	case "diff":
		out, _ := git(project, "diff", "HEAD")
		return clip(out), true
	case "staged":
		out, _ := git(project, "diff", "--cached")
		return clip(out), true
	case "branch":
		return currentBranch(project), true
	case "project":
		return filepath.Base(project), true
	case "check":
		if check != nil {
			return check(), true
		}
		return "", true
	case "input", "selection", "file", "clipboard":
		return "", true
	}
	return "", false
}
