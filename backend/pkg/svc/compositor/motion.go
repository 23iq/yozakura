package compositor

import (
	"fmt"
	"strings"
)

// Motion profile + smart gaps, appended to the hyprland.{lua,conf} entry
// files after the appearance table. Neither fits hl.config(): curves and
// animations are builder calls (hl.curve / hl.animation) and smart gaps is
// a workspace rule. The Lua text matches what the shell evaluates live
// (config/motion/MotionSpec.js luaChunk, CompositorAppearance.js
// smartGapsLua), one statement per line here for readability.

// SmartGapsSelector is the workspace selector of the smart gaps rule: a
// workspace showing exactly one tiled window.
const SmartGapsSelector = "w[tv1]"

func renderExtrasLua(in Input, gameMode bool) string {
	var b strings.Builder
	if in.Motion != nil {
		b.WriteString("\n-- Motion profile \"" + in.Motion.Profile + "\" (config/motion).\n")
		b.WriteString(MotionLua(*in.Motion, gameMode))
	}
	b.WriteString("\n-- Smart gaps: no gaps around a lone tiled window.\n")
	b.WriteString(SmartGapsLua(in.SmartGaps))
	return b.String()
}

func renderExtrasConf(in Input, gameMode bool) string {
	var b strings.Builder
	if in.Motion != nil {
		b.WriteString("\n# Motion profile \"" + in.Motion.Profile + "\" (config/motion).\n")
		b.WriteString(MotionConf(*in.Motion, gameMode))
	}
	if in.SmartGaps {
		b.WriteString("\n# Smart gaps: no gaps around a lone tiled window.\n")
		fmt.Fprintf(&b, "workspace = %s, gapsout:0, gapsin:0\n", SmartGapsSelector)
	}
	return b.String()
}

// MotionLua renders the curves and animations as guarded Lua statements.
// GameMode keeps animations switched off (the appearance table already
// disabled them; the profile must not turn them back on).
func MotionLua(m MotionSpec, gameMode bool) string {
	var b strings.Builder
	fmt.Fprintf(&b, "pcall(hl.config, { animations = { enabled = %t } })\n", m.Enabled && !gameMode)
	for _, c := range m.Curves {
		b.WriteString("pcall(function() " + luaCurve(c) + " end)\n")
	}
	for _, a := range m.Animations {
		b.WriteString("pcall(function() " + luaAnimation(a) + " end)\n")
	}
	return b.String()
}

func luaCurve(c MotionCurve) string {
	if c.Type == "spring" {
		return fmt.Sprintf("hl.curve(%s, { type = \"spring\", mass = %s, stiffness = %s, dampening = %s })",
			luaQuote(c.Name), formatNumber(c.Mass), formatNumber(c.Stiffness), formatNumber(c.Dampening))
	}
	p := curvePoints(c)
	return fmt.Sprintf("hl.curve(%s, { type = \"bezier\", points = { {%s, %s}, {%s, %s} } })",
		luaQuote(c.Name), formatNumber(p[0]), formatNumber(p[1]), formatNumber(p[2]), formatNumber(p[3]))
}

func luaAnimation(a MotionAnimation) string {
	kind := "bezier"
	if a.Kind == "spring" {
		kind = "spring"
	}
	s := fmt.Sprintf("hl.animation({ leaf = %s, enabled = %t, speed = %s, %s = %s",
		luaQuote(a.Leaf), a.Enabled, formatNumber(a.Speed), kind, luaQuote(a.Curve))
	if a.Style != "" {
		s += ", style = " + luaQuote(a.Style)
	}
	return s + " })"
}

// curvePoints flattens the two control points (zeros when malformed).
func curvePoints(c MotionCurve) [4]float64 {
	var p [4]float64
	for i := 0; i < 2 && i < len(c.Points); i++ {
		for j := 0; j < 2 && j < len(c.Points[i]); j++ {
			p[i*2+j] = c.Points[i][j]
		}
	}
	return p
}

// MotionConf renders the hyprlang form. hyprlang has no spring curves: a
// spring is written as its bezier fallback under the same name.
func MotionConf(m MotionSpec, gameMode bool) string {
	var b strings.Builder
	b.WriteString("animations {\n")
	fmt.Fprintf(&b, "    enabled = %t\n", m.Enabled && !gameMode)
	for _, c := range m.Curves {
		p := curvePoints(c)
		fmt.Fprintf(&b, "    bezier = %s, %s, %s, %s, %s\n", c.Name,
			formatNumber(p[0]), formatNumber(p[1]), formatNumber(p[2]), formatNumber(p[3]))
	}
	for _, a := range m.Animations {
		on := 0
		if a.Enabled {
			on = 1
		}
		line := fmt.Sprintf("    animation = %s, %d, %s, %s", a.Leaf, on, formatNumber(a.Speed), a.Curve)
		if a.Style != "" {
			line += ", " + a.Style
		}
		b.WriteString(line + "\n")
	}
	b.WriteString("}\n")
	return b.String()
}

// SmartGapsLua switches the previous smart gaps rule off (its handle is
// kept in a Lua global) and adds a new one when enabled.
func SmartGapsLua(enabled bool) string {
	var b strings.Builder
	b.WriteString("if __smartGapsRule then pcall(function() __smartGapsRule:set_enabled(false) end) end\n")
	b.WriteString("__smartGapsRule = nil\n")
	if enabled {
		fmt.Fprintf(&b, "pcall(function() __smartGapsRule = hl.workspace_rule({ workspace = %s, gaps_in = 0, gaps_out = 0 }) end)\n", luaQuote(SmartGapsSelector))
	}
	return b.String()
}
