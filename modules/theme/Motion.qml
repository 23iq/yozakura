pragma Singleton

import QtQuick
import Quickshell
import qs.config
import "../../config/motion/MotionBudget.js" as MotionBudget

// Shell motion tokens. Durations come from Config.animDuration (theme base x
// motion profile scale, already compressed and capped by the budget) and are
// 0 when it is 0 (game mode, motion off). Enter and morph decelerate (soft
// profile curves become OutCubic, a bouncy one OutQuart: panels never
// overshoot); exit accelerates away and is shorter than enter. Only emphasis
// and spring keep a bouncy profile's OutBack. Budget: config/motion/MotionBudget.js.
Singleton {
    id: root

    readonly property string easingName: Config.motionDrivesShell && Config.motionProfile ? Config.motionProfile.shell.easing : "OutCubic"
    readonly property int base: Config.animDuration
    readonly property int enterEasing: root.easingOf(MotionBudget.panelEasing(root.easingName))
    readonly property int emphasisEasing: root.easingOf(MotionBudget.enterEasing(root.easingName))
    readonly property int exitEasing: root.easingOf(MotionBudget.exitEasing(root.easingName))
    readonly property real _overshoot: 1.2

    // Typed token so consumers (and qmllint) see duration/easing/overshoot.
    component Token: QtObject {
        property int duration: 0
        property int easing: Easing.OutCubic
        property real overshoot: 1.0
    }

    readonly property Token enter: Token {
        duration: MotionBudget.token("enter", root.base)
        easing: root.enterEasing
    }
    readonly property Token exit: Token {
        duration: MotionBudget.token("exit", root.base)
        easing: root.exitEasing
    }
    readonly property Token morph: Token {
        duration: MotionBudget.token("morph", root.base)
        easing: root.enterEasing
    }
    readonly property Token emphasis: Token {
        duration: MotionBudget.token("emphasis", root.base)
        easing: root.emphasisEasing
        overshoot: root.emphasisEasing === Easing.OutBack ? root._overshoot : 1.0
    }

    // State changes inside a surface (colour fills, hover, focus rings,
    // icon swaps): short, decelerating, never overshooting (<= 120 ms).
    readonly property Token micro: Token {
        duration: MotionBudget.token("micro", root.base)
        easing: Easing.OutCubic
    }
    // Things that travel inside a surface (tab content, list rows, detail
    // panels, sliding indicators): decelerating, <= 220 ms.
    readonly property Token glide: Token {
        duration: MotionBudget.token("glide", root.base)
        easing: root.enterEasing
    }

    // A camera move across a whole surface (the panorama wallpaper panning
    // between workspaces): longer than a glide, <= 700 ms. Decelerating, so
    // it leaves with the workspace switch instead of lagging behind it.
    readonly property Token pan: Token {
        duration: MotionBudget.token("pan", root.base)
        easing: Easing.OutCubic
    }

    // Tactile press / release of big controls and pills that snap into place:
    // a short spring that overshoots (0 with animations off).
    readonly property Token spring: Token {
        duration: Math.round(MotionBudget.token("enter", root.base) / 2)
        easing: Easing.OutBack
        overshoot: 2.5
    }

    // Stagger step before secondary content (<= 40 ms), the delay of item `i`
    // of a staggered list (<= 120 ms in total) and palette crossfade (<= 600 ms).
    readonly property int delay: root.base > 0 ? Math.min(MotionBudget.SHELL.delay, Math.round(root.base * 0.13)) : 0
    readonly property int palette: root.base > 0 ? Math.min(MotionBudget.SHELL.palette, Math.round(root.base * 2)) : 0

    function stagger(i: int): int {
        return MotionBudget.stagger(i, root.delay);
    }

    function easingOf(name: string): int {
        const v = Easing[name];
        return v !== undefined ? v : Easing.OutCubic;
    }
}
