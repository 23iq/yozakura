pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.modules.services
import "../../config/motion/MotionSpec.js" as MotionSpec

// The motion profile (compositor.motionProfile + overrides, config/motion)
// resolved for the compositor. CompositorTomlWriter persists `spec` (the
// backend renders it into hyprland.{lua,conf}); this singleton applies the
// same curves/animations live through one `hyprctl eval` when they change.
Singleton {
    id: root

    readonly property var compositor: Config.compositor || ({})
    readonly property bool verticalBar: !!Config.bar && (Config.bar.position === "left" || Config.bar.position === "right")

    readonly property var spec: {
        const c = root.compositor || {};
        return MotionSpec.resolve({
            "profile": c.motionProfile,
            "durationScale": c.motionDurationScale,
            "workspaceStyle": c.motionWorkspaceStyle,
            "vertical": root.verticalBar,
            "borderLoop": c.motionBorderLoop,
            "borderLoopSpeed": c.motionBorderLoopSpeed,
            "overrides": c.motionOverrides
        });
    }
    readonly property string chunk: MotionSpec.luaChunk(spec)

    property string _applied: ""

    onChunkChanged: applyTimer.restart()

    // Coalesces slider drags and preset loads (many keys at once).
    Timer {
        id: applyTimer
        interval: 150
        onTriggered: root.apply(false)
    }

    function apply(force) {
        if (!Config.loader.loaded || GameModeClient.toggled)
            return;
        if (!force && root.chunk === root._applied)
            return;
        root._applied = root.chunk;
        BackendService.notify("compositor.eval", {
            "expression": root.chunk
        });
    }

    // GameMode switched animations off live; restore the profile after it.
    Connections {
        target: GameModeClient
        function onToggledChanged() {
            if (!GameModeClient.toggled)
                root.apply(true);
        }
    }

    Connections {
        target: Config.loader
        function onLoaded() {
            applyTimer.restart();
        }
    }

    Component.onCompleted: applyTimer.restart()
}
