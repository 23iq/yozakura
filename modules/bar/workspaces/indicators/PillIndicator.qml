import QtQuick
import qs.modules.components

// "pill": a filled rounded highlight (the classic look); round when the
// workspace is empty, following the bar roundness when it has windows.
StyledRect {
    id: root

    property var indicator: null
    readonly property real margin: 4
    readonly property real thickness: indicator ? indicator.slotSize - margin * 2 : 0

    variant: "primary"
    x: margin
    y: margin
    width: indicator ? Math.max(0, indicator.width - margin * 2) : 0
    height: indicator ? Math.max(0, indicator.height - margin * 2) : 0
    radius: {
        if (!indicator || indicator.baseRadius === 0)
            return 0;
        return indicator.occupied ? Math.max(indicator.baseRadius - indicator.padding - margin, 0) : thickness / 2;
    }
}
