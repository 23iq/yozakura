package server

import (
	"errors"
	"reflect"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
	"yozakura/backend/pkg/yozd/ipc/mock"
)

// keepComp records the calls switchWorkspace makes.
type keepComp struct {
	*mock.Compositor
	calls     []string
	posErr    error
	switchErr error
}

func (k *keepComp) GetCursorPosition() (int, int, error) {
	k.calls = append(k.calls, "pos")
	return 1190, 321, k.posErr
}

func (k *keepComp) SwitchWorkspace(id string) error {
	k.calls = append(k.calls, "switch "+id)
	return k.switchErr
}

func (k *keepComp) SwitchWorkspaceKeepCursor(id string, x, y int) error {
	if x != 1190 || y != 321 {
		k.calls = append(k.calls, "keep elsewhere")
	} else {
		k.calls = append(k.calls, "keep "+id)
	}
	return k.switchErr
}

func TestSwitchWorkspaceKeepCursor(t *testing.T) {
	tests := []struct {
		name      string
		keep      bool
		posErr    error
		switchErr error
		want      []string
		wantErr   bool
	}{
		{name: "plain switch never reads the pointer", want: []string{"switch 4"}},
		{name: "keep cursor is one atomic call at the read position", keep: true, want: []string{"pos", "keep 4"}},
		{name: "unreadable position is a plain switch", keep: true, posErr: errors.New("x"), want: []string{"pos", "switch 4"}},
		{name: "switch error is returned", keep: true, switchErr: errors.New("x"), want: []string{"pos", "keep 4"}, wantErr: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			c := &keepComp{Compositor: mock.NewCompositor(), posErr: tt.posErr, switchErr: tt.switchErr}
			err := switchWorkspace(c, "4", tt.keep)
			if (err != nil) != tt.wantErr {
				t.Fatalf("err = %v", err)
			}
			if !reflect.DeepEqual(c.calls, tt.want) {
				t.Fatalf("calls = %v, want %v", c.calls, tt.want)
			}
		})
	}
}

// A compositor that cannot keep the pointer gets a plain switch.
func TestSwitchWorkspaceKeepCursorWithoutSupport(t *testing.T) {
	c := mock.NewCompositor()
	c.AddWorkspace(ipc.Workspace{ID: "2"})
	if err := switchWorkspace(c, "2", true); err != nil {
		t.Fatal(err)
	}
	if got := c.SwitchWorkspaceCalls(); !reflect.DeepEqual(got, []string{"2"}) {
		t.Fatalf("switch calls = %v", got)
	}
}
