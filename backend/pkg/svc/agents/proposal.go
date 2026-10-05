package agents

import (
	"os"
	"path/filepath"
	"strings"
)

// maxProposalBytes caps files read to preview an edit in a permission card.
const maxProposalBytes = 512 * 1024

// proposedEdit previews what a Claude Code Write/Edit/MultiEdit call would
// change, as a unified diff, so the permission card can show it before the
// user allows it. Returns empty strings when it cannot tell.
func proposedEdit(tool string, in map[string]any, cwd string) (string, string) {
	path, _ := in["file_path"].(string)
	if path == "" {
		return "", ""
	}
	abs := path
	if !filepath.IsAbs(abs) && cwd != "" {
		abs = filepath.Join(cwd, abs)
	}
	rel := path
	if cwd != "" && strings.HasPrefix(abs, cwd+string(filepath.Separator)) {
		rel = strings.TrimPrefix(abs, cwd+string(filepath.Separator))
	}
	old := ""
	if st, err := os.Stat(abs); err == nil {
		if st.IsDir() || st.Size() > maxProposalBytes {
			return rel, ""
		}
		data, err := os.ReadFile(abs)
		if err != nil {
			return rel, ""
		}
		old = string(data)
	}
	var updated string
	switch tool {
	case "Write":
		content, ok := in["content"].(string)
		if !ok {
			return rel, ""
		}
		updated = content
	case "Edit":
		next, ok := applyEdit(old, in)
		if !ok {
			return rel, ""
		}
		updated = next
	case "MultiEdit":
		updated = old
		for _, e := range asSlice(in["edits"]) {
			next, ok := applyEdit(updated, asMap(e))
			if !ok {
				return rel, ""
			}
			updated = next
		}
	default:
		return "", ""
	}
	if updated == old {
		return rel, ""
	}
	return rel, unifiedDiff(rel, old, updated)
}

func applyEdit(text string, e map[string]any) (string, bool) {
	oldStr, _ := e["old_string"].(string)
	newStr, _ := e["new_string"].(string)
	all, _ := e["replace_all"].(bool)
	if oldStr == "" || !strings.Contains(text, oldStr) {
		return "", false
	}
	if all {
		return strings.ReplaceAll(text, oldStr, newStr), true
	}
	return strings.Replace(text, oldStr, newStr, 1), true
}
