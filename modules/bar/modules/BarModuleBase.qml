import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme

// Common root of the file-based bar modules (BarModuleRegistry.js `file`).
// BarModuleSlot sets `bar` (the panel: orientation, moduleSize, flat,
// panelStyle, screen...) and keeps the radii / shadow / flat bindings.
Item {
    id: base

    required property var bar
    property real startRadius: 0
    property real endRadius: 0
    property bool enableShadow: false
    // Gap slots: no background whatever the panel style
    property bool forceFlat: false
    // Key in bar.moduleOptions
    property string moduleKey: ""
    // Size along the panel; the cross size is the panel's module size
    property real contentLength: moduleSize

    readonly property bool vertical: bar ? bar.orientation === "vertical" : false
    readonly property int moduleSize: bar && bar.moduleSize ? bar.moduleSize : BarMetrics.moduleSize
    readonly property bool flat: forceFlat || (bar ? bar.flat === true : false)
    readonly property string panelStyle: bar && bar.panelStyle ? bar.panelStyle : "classic"
    readonly property string edge: bar && bar.barPosition ? bar.barPosition : "top"
    readonly property var options: {
        const all = Config.bar && Config.bar.moduleOptions ? Config.bar.moduleOptions : null;
        return all && moduleKey !== "" && all[moduleKey] ? all[moduleKey] : ({});
    }
    // Text sizes that follow the module size (dense panels stay legible)
    readonly property int textSize: moduleSize >= 32 ? Styling.fontSize(0) : Styling.fontSize(-1)
    readonly property int smallTextSize: Styling.fontSize(-2)
    readonly property int iconSize: BarMetrics.iconFor(18, moduleSize)

    objectName: moduleKey
    implicitWidth: vertical ? moduleSize : contentLength
    implicitHeight: vertical ? contentLength : moduleSize
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical
}
