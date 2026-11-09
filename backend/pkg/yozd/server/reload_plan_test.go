package server

import (
	"reflect"
	"testing"
)

func baseSections() configSections {
	return configSections{
		secOutputs:    {conf: "monitor = DP-1,2560x1440@144,0x0,1\n"},
		secKeyboard:   {conf: "input {\n    kb_layout = us,ru\n}\n"},
		secAppearance: {conf: "general {\n    gaps_in = 5\n    col.active_border = rgba(ff0000ff)\n}\n\ndecoration {\n    rounding = 8\n    blur {\n        size = 4\n    }\n}\n"},
		secAnimations: {conf: "animations {\n    enabled = true\n}\n"},
		secBinds:      {conf: "bind = SUPER,Q,exec,kitty\n"},
	}
}

func with(s configSections, name, conf string) configSections {
	out := configSections{}
	for k, v := range s {
		out[k] = v
	}
	out[name] = section{conf: conf}
	return out
}

func TestPlanIdenticalDoesNothing(t *testing.T) {
	s := baseSections()
	if p := planApply(s, s, true); p.Write || p.Reload || len(p.Live) > 0 {
		t.Fatalf("identical config: plan = %+v, want no write, no reload", p)
	}
	// Unknown history but the file already holds the content: still nothing.
	if p := planApply(nil, s, true); p.Write || p.Reload {
		t.Fatalf("identical file without history: plan = %+v", p)
	}
}

func TestPlanUnknownHistoryReloads(t *testing.T) {
	p := planApply(nil, baseSections(), false)
	if !p.Write || !p.Reload {
		t.Fatalf("first apply: plan = %+v, want write + reload", p)
	}
}

func TestPlanAppearanceOnlyIsLive(t *testing.T) {
	prev := baseSections()
	next := with(prev, secAppearance, "general {\n    gaps_in = 9\n    col.active_border = rgba(00ff00ff)\n}\n\ndecoration {\n    rounding = 8\n    blur {\n        size = 6\n    }\n}\n")
	p := planApply(prev, next, false)
	if !p.Write || p.Reload {
		t.Fatalf("appearance change: plan = %+v, want write without reload", p)
	}
	if !reflect.DeepEqual(p.Live, []string{secAppearance}) {
		t.Fatalf("live = %v, want [appearance]", p.Live)
	}
	cmds, ok := liveCommands(prev, next, p.Live, false, nil)
	if !ok {
		t.Fatal("liveCommands refused a plain appearance change")
	}
	want := []string{
		"keyword general:gaps_in 9",
		"keyword general:col.active_border rgba(00ff00ff)",
		"keyword decoration:blur:size 6",
	}
	if !reflect.DeepEqual(cmds, want) {
		t.Fatalf("keywords = %q, want %q", cmds, want)
	}
}

func TestPlanKeyboardIsLive(t *testing.T) {
	prev := baseSections()
	next := with(prev, secKeyboard, "input {\n    kb_layout = us,de\n}\n")
	p := planApply(prev, next, false)
	if p.Reload || !reflect.DeepEqual(p.Live, []string{secKeyboard}) {
		t.Fatalf("keyboard change: plan = %+v", p)
	}
}

func TestPlanReloadsWhatKeywordCannotApply(t *testing.T) {
	prev := baseSections()
	cases := map[string]configSections{
		"binds":      with(prev, secBinds, "bind = SUPER,W,exec,firefox\n"),
		"monitors":   with(prev, secOutputs, "monitor = DP-1,1920x1080@60,0x0,1\n"),
		"rules":      with(prev, secRules, "windowrule = float, class:foo\n"),
		"env":        with(prev, secEnv, "env = QT_QPA_PLATFORMTHEME,qt6ct\n"),
		"animations": with(prev, secAnimations, "animations {\n    enabled = false\n}\n"),
		// A key that disappears cannot be unset by `keyword`.
		"removed key":  with(prev, secAppearance, "general {\n    gaps_in = 5\n}\n"),
		"keyboard off": with(prev, secKeyboard, ""),
	}
	for name, next := range cases {
		p := planApply(prev, next, false)
		if !p.Write || !p.Reload {
			t.Errorf("%s: plan = %+v, want write + reload", name, p)
		}
	}
}

func TestPlanMixedChangeReloadsOnce(t *testing.T) {
	prev := baseSections()
	next := with(with(prev, secAppearance, "general {\n    gaps_in = 1\n    col.active_border = rgba(ff0000ff)\n}\n\ndecoration {\n    rounding = 8\n    blur {\n        size = 4\n    }\n}\n"), secBinds, "")
	p := planApply(prev, next, false)
	if !p.Reload || len(p.Live) != 0 {
		t.Fatalf("appearance + binds: plan = %+v, want reload and no live commands", p)
	}
	if !reflect.DeepEqual(p.Changed, []string{secAppearance, secBinds}) {
		t.Fatalf("changed = %v", p.Changed)
	}
}

func TestKeywordCommandsRejectsSemicolon(t *testing.T) {
	if _, ok := keywordCommands("", "general {\n    layout = a;b\n}\n", nil); ok {
		t.Fatal("a ';' would split the batch request; must fall back to reload")
	}
}

func TestLuaEvalCommandJoinsLines(t *testing.T) {
	chunk := "hl.config({\n    general = {\n        gaps_in = 5,\n        layout = \"dwindle\",\n    },\n})\n\n"
	cmd, ok := luaEvalCommand(chunk)
	want := `eval hl.config({ general = { gaps_in = 5, layout = "dwindle", }, })`
	if !ok || cmd != want {
		t.Fatalf("eval = %q (ok=%v), want %q", cmd, ok, want)
	}
	if _, ok := luaEvalCommand("hl.config({ a = 1 }); os.exit()"); ok {
		t.Fatal("a ';' would split the batch request")
	}
}

func TestLiveCommandsLuaUsesEval(t *testing.T) {
	prev := baseSections()
	next := with(prev, secAppearance, "general {\n    gaps_in = 2\n}\n")
	next[secAppearance] = section{conf: next[secAppearance].conf, lua: "hl.config({\n    general = { gaps_in = 2 },\n})\n"}
	cmds, ok := liveCommands(prev, next, []string{secAppearance}, true, nil)
	if !ok || len(cmds) != 1 || cmds[0] != "eval hl.config({ general = { gaps_in = 2 }, })" {
		t.Fatalf("lua live commands = %q (ok=%v)", cmds, ok)
	}
}

func TestFlattenHyprlangNested(t *testing.T) {
	got := flattenHyprlang("# c\ndecoration {\n    shadow {\n        enabled = true\n    }\n    rounding = 4\n}\ninput {\n    kb_options = \n}\n")
	want := []hyprlangEntry{
		{"decoration:shadow:enabled", "true"},
		{"decoration:rounding", "4"},
		{"input:kb_options", ""},
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("flatten = %+v, want %+v", got, want)
	}
}
