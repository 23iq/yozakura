package yozakura

import (
	"encoding/json"
	"regexp"
	"testing"

	"yozakura/backend/pkg/routinetools"
)

// Every tool of the server is either a routine step, read-only, or listed
// as excluded with a reason: a new tool must pick a side.
func TestRoutineToolsCoverTheServer(t *testing.T) {
	blocked := map[string]bool{"routine_run": true, "routine_save": true, "routine_delete": true, "routines_list": true}
	seen := map[string]bool{}
	for _, d := range Tools(Deps{}) {
		name := d.Tool.Name
		seen[name] = true
		_, usable := routinetools.Tools[name]
		_, excluded := routinetools.Excluded[name]
		switch {
		case usable && d.Tool.ReadOnly():
			t.Errorf("%s is read-only and cannot be a routine step", name)
		case usable && blocked[name]:
			t.Errorf("%s is blocked inside routines", name)
		case usable || excluded || d.Tool.ReadOnly() || blocked[name]:
		default:
			t.Errorf("tool %s is neither in routinetools.Tools nor routinetools.Excluded", name)
		}
	}
	for name := range routinetools.Tools {
		if !seen[name] {
			t.Errorf("routinetools.Tools lists %s, which no MCP tool defines", name)
		}
	}
	for name := range routinetools.Excluded {
		if !seen[name] {
			t.Errorf("routinetools.Excluded lists %s, which no MCP tool defines", name)
		}
	}
}

var placeholderRe = regexp.MustCompile(`\{([A-Za-z0-9_]+)[|}]`)

func TestRoutineToolsCatalog(t *testing.T) {
	list := RoutineTools()
	if len(list) != len(routinetools.Tools) {
		t.Fatalf("%d tools, want %d", len(list), len(routinetools.Tools))
	}
	for _, rt := range list {
		var schema struct {
			Type       string                    `json:"type"`
			Properties map[string]map[string]any `json:"properties"`
		}
		if err := json.Unmarshal(rt.Schema, &schema); err != nil || schema.Type != "object" {
			t.Errorf("%s: schema: %v", rt.Name, err)
			continue
		}
		if rt.Title == "" || rt.Description == "" {
			t.Errorf("%s: title/description missing", rt.Name)
		}
		for _, m := range placeholderRe.FindAllStringSubmatch(rt.Summary, -1) {
			if _, ok := schema.Properties[m[1]]; !ok {
				t.Errorf("%s: summary uses {%s}, not an argument of the tool", rt.Name, m[1])
			}
		}
	}
	if list[0].Category != "media" {
		t.Errorf("first tool category %q, want media", list[0].Category)
	}
}
