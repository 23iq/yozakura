package compositor

import (
	"strings"
	"yozakura/backend/pkg/brand"
)

// holdReleaseArgument lists actions that act while their key is held
// (push-to-talk voice input). Besides the press bind they get a release
// bind ("r" flag) on the same key that runs this command. The actions
// themselves are in config/KeybindActions.js and catalog (actions.go).
var holdReleaseArgument = map[string]string{
	brand.Action("voice-ai"):  brand.Command("voice", "release"),
	brand.Action("dictation"): brand.Command("voice", "release"),
}

// pushHoldRelease emits the release half of a hold action. Binds that are
// already release binds (flag "r") get nothing extra.
func pushHoldRelease(b *strings.Builder, modifiers []string, key string, action Action, flags string) {
	arg, ok := holdReleaseArgument[EnsureAction(action).ID]
	if !ok || strings.Contains(flags, "r") {
		return
	}
	pushKeybind(b, modifiers, key, "exec", arg, flags+"r")
}
