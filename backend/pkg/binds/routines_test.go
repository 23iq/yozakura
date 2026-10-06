package binds

import (
	"path/filepath"
	"testing"

	"yozakura/backend/pkg/svc/routines"

	"github.com/stretchr/testify/assert"
)

func TestRoutinesFrom(t *testing.T) {
	path := filepath.Join(t.TempDir(), "routines.json")
	assert.Empty(t, RoutinesFrom(path)())
	assert.NoError(t, routines.Save(path, []routines.Routine{{ID: "morning", Name: "Morning", Keywords: "coffee"}}))
	got := RoutinesFrom(path)()
	assert.Equal(t, []Routine{{ID: "morning", Name: "Morning", Keywords: "coffee routine",
		Action: ActionRef{ID: "utilities.routine", Args: map[string]any{"routine": "morning"}}}}, got)

	a := &Advisor{Routines: RoutinesFrom(path)}
	res := a.searchRoutines(parseQuery("morning"))
	if assert.Len(t, res, 1) {
		assert.Equal(t, KindRoutine, res[0].Kind)
		assert.Equal(t, "morning", res[0].Action.Args["routine"])
	}
}
