package yozakura

import (
	"encoding/json"
	"sort"

	"yozakura/backend/pkg/routinetools"
)

// RoutineTool is one tool a routine step may call, as the settings editor
// shows it: the MCP definition (the single source of the argument schema)
// joined with the routine metadata of pkg/routinetools.
type RoutineTool struct {
	Name        string          `json:"name"`
	Title       string          `json:"title"`
	Description string          `json:"description"`
	Category    string          `json:"category"`
	Summary     string          `json:"summary"`
	Schema      json.RawMessage `json:"schema"`
}

// RoutineTools lists the routine-usable tools by category order, then name.
func RoutineTools() []RoutineTool {
	order := map[string]int{}
	for i, c := range routinetools.Categories {
		order[c] = i
	}
	var out []RoutineTool
	for _, d := range Tools(Deps{}) {
		m, ok := routinetools.Lookup(d.Tool.Name)
		if !ok || d.Tool.ReadOnly() {
			continue
		}
		out = append(out, RoutineTool{Name: d.Tool.Name, Title: d.Tool.Title, Description: d.Tool.Description,
			Category: m.Category, Summary: m.Summary, Schema: d.Tool.InputSchema})
	}
	sort.SliceStable(out, func(i, j int) bool {
		if a, b := order[out[i].Category], order[out[j].Category]; a != b {
			return a < b
		}
		return out[i].Name < out[j].Name
	})
	return out
}
