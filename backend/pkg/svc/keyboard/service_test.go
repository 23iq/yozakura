package keyboard

import (
	"encoding/json"
	"path/filepath"
	"reflect"
	"testing"
	"time"

	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/svc/compositor"
	yipc "yozakura/backend/pkg/yozd/ipc"
)

type fakeYozd struct {
	state   yipc.KeyboardLayoutState
	applied []yipc.KeyboardSettings
	nexts   int
}

func (f *fakeYozd) ApplyKeyboard(s yipc.KeyboardSettings) error {
	f.applied = append(f.applied, s)
	return nil
}
func (f *fakeYozd) ActiveLayout() (yipc.KeyboardLayoutState, error) { return f.state, nil }
func (f *fakeYozd) NextLayout() error                               { f.nexts++; return nil }

type fakeSource struct{ ch chan compositor.State }

func (f fakeSource) Subscribe() (<-chan compositor.State, func()) { return f.ch, func() {} }

func rules() []string { return []string{filepath.Join("testdata", "evdev.lst")} }

func TestApplyUsesSwitchBind(t *testing.T) {
	y := &fakeYozd{}
	s := newService(y, nil, rules())
	_, err := s.apply(json.RawMessage(`{"layouts":[{"layout":"us","variant":""},{"layout":"ru","variant":"phonetic"}],"switchBind":"super_space","options":["caps:escape"],"repeatRate":25,"repeatDelay":600}`))
	if err != nil {
		t.Fatal(err)
	}
	want := yipc.KeyboardSettings{
		Layouts: []string{"us", "ru"}, Variants: []string{"", "phonetic"},
		Options: []string{"grp:win_space_toggle", "caps:escape"}, RepeatRate: 25, RepeatDelay: 600,
	}
	if len(y.applied) != 1 || !reflect.DeepEqual(y.applied[0], want) {
		t.Fatalf("applied = %+v", y.applied)
	}
	if _, err := s.apply(json.RawMessage(`{"layouts":[{"layout":"us;rm"}]}`)); err == nil {
		t.Fatal("no valid layouts must fail")
	}
}

func TestActiveAndNext(t *testing.T) {
	y := &fakeYozd{state: yipc.KeyboardLayoutState{Names: []string{"us", "ru"}, Name: "Russian"}}
	s := newService(y, nil, rules())
	a, err := s.Active()
	if err != nil || a != (Active{Name: "Russian", Index: 1, Code: "ru", Short: "RU"}) {
		t.Fatalf("active = %+v, %v", a, err)
	}
	if _, err := s.next(nil); err != nil || y.nexts != 1 {
		t.Fatalf("next: %v, %d", err, y.nexts)
	}
}

func TestSubscribeForwardsLayoutEvents(t *testing.T) {
	y := &fakeYozd{state: yipc.KeyboardLayoutState{Names: []string{"us", "ru"}, Name: "English (US)"}}
	src := fakeSource{ch: make(chan compositor.State, 4)}
	s := newService(y, src, rules())
	sub := &ipc.Subscriber{Events: make(chan ipc.ServiceEvent, 16)}
	s.subscribe(sub)

	got := func() Active {
		t.Helper()
		select {
		case ev := <-sub.Events:
			if ev.Service != "keyboard.layout" {
				t.Fatalf("event %q", ev.Service)
			}
			return ev.Data.(Active)
		case <-time.After(2 * time.Second):
			t.Fatal("no event")
		}
		return Active{}
	}
	if a := got(); a.Short != "EN" {
		t.Fatalf("initial = %+v", a)
	}
	ru := compositor.State{KeyboardLayout: json.RawMessage(`{"name":"Russian"}`)}
	src.ch <- ru
	src.ch <- ru // unchanged payload: no second event
	src.ch <- compositor.State{KeyboardLayout: json.RawMessage(`{"name":"English (US)"}`)}
	if a := got(); a != (Active{Name: "Russian", Index: 1, Code: "ru", Short: "RU"}) {
		t.Fatalf("after switch = %+v", a)
	}
	if a := got(); a.Code != "us" || a.Index != 0 {
		t.Fatalf("after switch back = %+v", a)
	}
}
