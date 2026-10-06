pragma Singleton
import QtQuick
import qs.modules.theme

// Spacing, radii and control sizes of the shared kit, scaled by the theme
// density (Metrics: compact / cozy / roomy). Radii follow the theme
// roundness: surface = the theme radius, control = -4, small = -8.
QtObject {
    id: root

    readonly property real factor: Metrics.spacing / 8

    function px(v: real): int {
        return Math.round(v * root.factor);
    }

    readonly property int xs: px(4)
    readonly property int s: px(8)
    readonly property int m: px(12)
    readonly property int l: px(16)
    readonly property int xl: px(24)
    readonly property int xxl: px(32)

    readonly property int surfaceRadius: Styling.radius(0)
    readonly property int controlRadius: Styling.radius(-4)
    readonly property int smallRadius: Styling.radius(-8)

    // Fully round when the theme is rounded at all (square themes stay square).
    function round(h: real): real {
        return Styling.radius(0) > 0 ? h / 2 : 0;
    }

    function clampRadius(r: real, h: real): real {
        return Math.min(r, h / 2);
    }

    readonly property int controlS: px(36)
    readonly property int controlM: px(40)
    readonly property int controlL: px(64)
    readonly property int chip: px(32)
    readonly property int keyHint: px(20)
    readonly property int rowHeight: Metrics.rowHeight
    readonly property int stroke: 3
    readonly property int hairline: 1
}
