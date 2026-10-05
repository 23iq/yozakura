package main

import (
	"fmt"
	"os"
	"yozakura/backend/pkg/brand"
)

// runVoice forwards voice input commands to the daemon's voice service.
// Keybinds call `yozakura voice press <ai|dictation>` on key press and
// `yozakura voice release` on key release (push-to-talk).
//
//	yozakura voice press|start <ai|dictation>
//	yozakura voice release|stop|cancel|status|warm|unload
func runVoice(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Usage: "+brand.AppID+" voice <press|start> <ai|dictation> | <release|stop|cancel|status|warm|unload>")
		return 2
	}
	params := map[string]any{}
	switch args[0] {
	case "press", "start":
		target := "ai"
		if len(args) > 1 {
			target = args[1]
		}
		if target != "ai" && target != "dictation" {
			fmt.Fprintf(os.Stderr, "Error: unknown voice target %q (ai|dictation)\n", target)
			return 2
		}
		params["target"] = target
	case "release", "stop", "cancel", "status", "warm", "unload":
	default:
		fmt.Fprintf(os.Stderr, "Error: unknown voice command %q\n", args[0])
		return 2
	}
	res := mustCall("voice."+args[0], params)
	if args[0] == "status" {
		fmt.Println(string(res))
	}
	return 0
}
