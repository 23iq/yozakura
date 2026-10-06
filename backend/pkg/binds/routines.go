package binds

import "yozakura/backend/pkg/svc/routines"

// RoutinesFrom lists the saved routines of a routines.json as bind
// targets: a bind runs one through the "utilities.routine" action.
func RoutinesFrom(path string) func() []Routine {
	return func() []Routine {
		list, err := routines.Load(path)
		if err != nil {
			return nil
		}
		out := make([]Routine, 0, len(list))
		for _, r := range list {
			out = append(out, Routine{ID: r.ID, Name: r.Name, Keywords: r.Keywords + " routine",
				Action: ActionRef{ID: routines.RoutineAction, Args: map[string]any{"routine": r.ID}}})
		}
		return out
	}
}
