pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.stages

// Home tile scene of Displays: the monitor arrangement (DisplaysService),
// each screen showing the wallpaper; one screen when none is known.
Item {
    id: scene

    required property Card tile
    readonly property var monitors: {
        const list = (DisplaysService.outputs || []).filter(m => m && m.enabled !== false && m.width > 0);
        return list.length > 0 ? list : [
            {
                "x": 0,
                "y": 0,
                "width": 2560,
                "height": 1440
            }
        ];
    }
    readonly property var box: {
        let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
        for (const m of scene.monitors) {
            x0 = Math.min(x0, m.x || 0);
            y0 = Math.min(y0, m.y || 0);
            x1 = Math.max(x1, (m.x || 0) + m.width);
            y1 = Math.max(y1, (m.y || 0) + m.height);
        }
        return {
            "x": x0,
            "y": y0,
            "w": x1 - x0,
            "h": y1 - y0
        };
    }
    readonly property real k: Math.min(scene.width / scene.box.w, scene.height / scene.box.h)

    Repeater {
        model: scene.monitors
        delegate: Stage {
            required property var modelData
            x: scene.width - scene.box.w * scene.k + ((modelData.x || 0) - scene.box.x) * scene.k
            y: (scene.height - scene.box.h * scene.k) / 2 + ((modelData.y || 0) - scene.box.y) * scene.k
            width: modelData.width * scene.k - Space.xs
            height: modelData.height * scene.k - Space.xs
            stageHeight: height
            radius: Look.radius("small", height)
        }
    }
}
