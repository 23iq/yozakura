package server

import (
	"errors"
	"reflect"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
	"yozakura/backend/pkg/yozd/ipc/mock"
)

// warpComp records the order of the calls switchWorkspace makes.
type warpComp struct {
	*mock.Compositor
	calls     []string
	posErr    error
	switchErr error
}

func (w *warpComp) GetCursorPosition() (int, int, error) {
	w.calls = append(w.calls, "pos")
	return 1190, 321, w.posErr
}

func (w *warpComp) SwitchWorkspace(id string) error {
	w.calls = append(w.calls, "switch "+id)
	return w.switchErr
}

func (w *warpComp) WarpCursor(x, y int) error {
	if x != 1190 || y != 321 {
		w.calls = append(w.calls, "warp elsewhere")
	} else {
		w.calls = append(w.calls, "warp back")
	}
	return nil
}

func TestSwitchWorkspaceKeepCursor(t *testing.T) {
	tests := []struct {
		name       string
		keep       bool
		posErr     error
		switchErr  error
		want       []string
		wantErrSet bool
	}{
		{name: "plain switch never touches the pointer", want: []string{"switch 4"}},
		{name: "keep cursor reads, switches, warps back", keep: true, want: []string{"pos", "switch 4", "warp back"}},
		{name: "unreadable position is a plain switch", keep: true, posErr: errors.New("x"), want: []string{"pos", "switch 4"}},
		{name: "failed switch does not warp", keep: true, switchErr: errors.New("x"), want: []string{"pos", "switch 4"}, wantErrSet: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			c := &warpComp{Compositor: mock.NewCompositor(), posErr: tt.posErr, switchErr: tt.switchErr}
			err := switchWorkspace(c, "4", tt.keep)
			if (err != nil) != tt.wantErrSet {
				t.Fatalf("err = %v", err)
			}
			if !reflect.DeepEqual(c.calls, tt.want) {
				t.Fatalf("calls = %v, want %v", c.calls, tt.want)
			}
		})
	}
}

// A compositor that cannot warp gets a plain switch even with keep_cursor.
func TestSwitchWorkspaceKeepCursorWithoutWarper(t *testing.T) {
	c := mock.NewCompositor()
	c.AddWorkspace(ipc.Workspace{ID: "2"})
	if err := switchWorkspace(c, "2", true); err != nil {
		t.Fatal(err)
	}
	if got := c.SwitchWorkspaceCalls(); !reflect.DeepEqual(got, []string{"2"}) {
		t.Fatalf("switch calls = %v", got)
	}
}
