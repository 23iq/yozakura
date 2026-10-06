pragma Singleton

import QtQuick
import Quickshell
import qs.config
import "../../config/motion/MotionBudget.js" as MotionBudget

// Shell motion tokens. Durations come from Config.animDuration (theme base x
// motion profile scale, already capped by the budget) and are 0 when it is 0
// (game mode, motion off). Enter and morph decelerate; exit follows the
// profile easing as is. Budget: config/motion/MotionBudget.js.
Singleton {
    id: root

    readonly property string easingName: Config.motionDrivesShell && Config.motionProfile ? Config.motionProfile.shell.easing : "OutCubic"
    readonly property int base: Config.animDuration
    readonly property int enterEasing: root.easingOf(MotionBudget.enterEasing(root.easingName))
    readonly property int exitEasing: root.easingOf(root.easingName)
    readonly property real _overshoot: 1.2

    // Typed (not a bare QtObject) so qmllint knows duration/easing/overshoot.
    component Token: QtObject {
        property int duration
        property int easing
        property real overshoot
    }

    readonly property Token enter: Token {
        duration: MotionBudget.token("enter", root.base)
        easing: root.enterEasing
        overshoot: root.enterEasing === Easing.OutBack ? root._overshoot : 1.0
    }
    readonly property Token exit: Token {
        duration: MotionBudget.token("exit", root.base)
        easing: root.exitEasing
        overshoot: root.exitEasing === Easing.OutBack ? root._overshoot : 1.0
    }
    readonly property Token morph: Token {
        duration: MotionBudget.token("morph", root.base)
        easing: root.enterEasing
        overshoot: root.enterEasing === Easing.OutBack ? root._overshoot : 1.0
    }
    readonly property Token emphasis: Token {
        duration: MotionBudget.token("emphasis", root.base)
        easing: root.enterEasing
        overshoot: root.enterEasing === Easing.OutBack ? root._overshoot : 1.0
    }

    // Stagger before secondary content (<= 40 ms) and palette crossfade (<= 600 ms).
    readonly property int delay: root.base > 0 ? Math.min(MotionBudget.SHELL.delay, Math.round(root.base * 0.13)) : 0
    readonly property int palette: root.base > 0 ? Math.min(MotionBudget.SHELL.palette, Math.round(root.base * 2)) : 0

    function easingOf(name: string): int {
        const v = Easing[name];
        return v !== undefined ? v : Easing.OutCubic;
    }
}
