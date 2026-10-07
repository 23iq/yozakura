pragma Singleton
import QtQuick
import Quickshell
import qs.config
import "../shell/LayoutModel.js" as Model

// The live composable layout (modules/shell/LayoutModel.js) of the current
// config: which parts are on and where re-homed content shows.
Singleton {
    id: root

    readonly property var layout: Model.fromConfig(root.config())
    readonly property var stacking: Model.stacking(root.layout)
    readonly property bool barEnabled: root.layout.bar.enabled
    readonly property bool notchEnabled: root.layout.notch.enabled
    // Bar content the notch shows ("clock", "tray") and what the corner
    // pills show ("activities", "clock", "tray")
    readonly property var notchSegments: Model.notchSegments(root.layout)
    readonly property var cornerContent: Model.cornerContent(root.layout)

    // The keys the model reads, as plain values
    function config(): var {
        const bar = Config.bar;
        const notch = Config.notch;
        const dock = Config.dock;
        return {
            "bar": bar ? {
                "position": bar.position,
                "layout": bar.layout,
                "panels": bar.panels
            } : null,
            "notch": notch ? {
                "enabled": notch.enabled,
                "position": notch.position,
                "style": notch.style,
                "align": notch.align
            } : null,
            "dock": dock ? {
                "enabled": dock.enabled,
                "position": dock.position,
                "theme": dock.theme
            } : null
        };
    }

    function homeOf(contentId: string): string {
        return Model.homeOf(contentId, root.layout);
    }

    // Effective bar.activities.presentation for the configured one; "bar"
    // = chips in the bar (notch.activitiesIn, LayoutModel.js)
    function activityPresentation(configured: string): string {
        return Model.activityPresentation(root.layout, configured, Config.notch ? Config.notch.activitiesIn : "auto");
    }

    // Config writes [{key, value}] setting `field` of `part` (LayoutModel.edit)
    function edit(part: string, field: string, value: var): var {
        return Model.edit(root.config(), part, field, value);
    }
}
