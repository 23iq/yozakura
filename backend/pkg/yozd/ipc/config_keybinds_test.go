package ipc

import (
	"encoding/json"
	"testing"

	"yozakura/backend/pkg/brand"
)

func TestConfigKeybindsShellGroup(t *testing.T) {
	bind := `{"system":{"term":{"modifiers":["SUPER"],"key":"Return","dispatcher":"exec","argument":"foot","enabled":true}},"launcher":{"key":"Super_L","dispatcher":"exec","argument":"x","enabled":true}}`
	for _, key := range []string{"shell", brand.LegacyAppID} {
		var kb ConfigKeybinds
		if err := json.Unmarshal([]byte(`{"`+key+`":`+bind+`,"custom":[{"key":"Q","dispatcher":"exec","argument":"kitty"}]}`), &kb); err != nil {
			t.Fatalf("%s: %v", key, err)
		}
		if kb.Shell == nil || kb.Shell.System["term"].Argument != "foot" || kb.Shell.Binds["launcher"].Argument != "x" {
			t.Fatalf("%s: shell group not decoded: %+v", key, kb.Shell)
		}
		if len(kb.Custom) != 1 {
			t.Fatalf("%s: custom binds lost: %+v", key, kb.Custom)
		}
	}
}
