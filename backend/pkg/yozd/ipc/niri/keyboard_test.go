package niri

import (
	"encoding/json"
	"errors"
	"reflect"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
)

func TestParseNiriKeyboardLayouts(t *testing.T) {
	st, err := parseNiriKeyboardLayouts([]byte(`{"names":["English (US)","Russian"],"current_idx":1}`))
	if err != nil || st.Name != "Russian" || st.Index != 1 || len(st.Names) != 2 {
		t.Fatal(st, err)
	}
}

func TestNiriKeyboardEvents(t *testing.T) {
	n := &Niri{}
	ev := ipc.Event{Payload: map[string]interface{}{}}
	n.handleEvent("KeyboardLayoutsChanged", json.RawMessage(`{"keyboard_layouts":{"names":["English (US)","Russian"],"current_idx":0}}`), &ev)
	if ev.Type != ipc.EventKeyboardLayout || ev.Payload["index"] != 0 || ev.Payload["name"] != "English (US)" {
		t.Fatalf("%+v", ev)
	}
	ev = ipc.Event{Payload: map[string]interface{}{}}
	n.handleEvent("KeyboardLayoutSwitched", json.RawMessage(`{"idx":1}`), &ev)
	want := map[string]interface{}{"index": 1, "name": "Russian"}
	if ev.Type != ipc.EventKeyboardLayout || !reflect.DeepEqual(ev.Payload, want) {
		t.Fatalf("%+v", ev)
	}
}

func TestNiriApplyKeyboardUnsupported(t *testing.T) {
	if err := (&Niri{}).ApplyKeyboard(ipc.KeyboardSettings{}); !errors.Is(err, ipc.ErrNotSupported) {
		t.Fatal(err)
	}
}
