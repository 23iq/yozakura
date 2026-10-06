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

    readonly property QtObject enter: QtObject {
        readonly property int duration: MotionBudget.token("enter", root.base)
        readonly property int easing: root.enterEasing
        readonly property real overshoot: root.enterEasing === Easing.OutBack ? root._overshoot : 1.0
    }
    readonly property QtObject exit: QtObject {
        readonly property int duration: MotionBudget.token("exit", root.base)
        readonly property int easing: root.exitEasing
        readonly property real overshoot: root.exitEasing === Easing.OutBack ? root._overshoot : 1.0
    }
    readonly property QtObject morph: QtObject {
        readonly property int duration: MotionBudget.token("morph", root.base)
        readonly property int easing: root.enterEasing
        readonly property real overshoot: root.enterEasing === Easing.OutBack ? root._overshoot : 1.0
    }
    readonly property QtObject emphasis: QtObject {
        readonly property int duration: MotionBudget.token("emphasis", root.base)
        readonly property int easing: root.enterEasing
        readonly property real overshoot: root.enterEasing === Easing.OutBack ? root._overshoot : 1.0
    }

    // Stagger before secondary content (<= 40 ms) and palette crossfade (<= 600 ms).
    readonly property int delay: root.base > 0 ? Math.min(MotionBudget.SHELL.delay, Math.round(root.base * 0.13)) : 0
    readonly property int palette: root.base > 0 ? Math.min(MotionBudget.SHELL.palette, Math.round(root.base * 2)) : 0

    function easingOf(name: string): int {
        const v = Easing[name];
        return v !== undefined ? v : Easing.OutCubic;
    }
}
