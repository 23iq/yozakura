import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.components.kit

// Divider between modules of strip styles (BarModuleGroup `separator`):
// "line" hairline, "dot" bullet, "slash" a thin diagonal (statusline).
Item {
    id: sep

    property bool vertical: false
    property string style: "line"
    property int moduleSize: BarMetrics.moduleSize

    readonly property real crossLength: Math.round(moduleSize * 0.42)

    implicitWidth: vertical ? moduleSize : (style === "line" ? Space.s + Space.hairline : Space.m)
    implicitHeight: vertical ? (style === "line" ? Space.s + Space.hairline : Space.m) : moduleSize
    Layout.alignment: Qt.AlignCenter

    Rectangle {
        visible: sep.style === "line"
        anchors.centerIn: parent
        width: sep.vertical ? sep.crossLength : Space.hairline
        height: sep.vertical ? Space.hairline : sep.crossLength
        color: Colors.outlineVariant
        opacity: 0.9
    }

    Rectangle {
        visible: sep.style === "dot"
        anchors.centerIn: parent
        width: Space.xs
        height: Space.xs
        radius: Look.radius("round", height)
        color: Type.secondary
        opacity: 0.55
    }

    // A mono rule glyph sized to the module.
    KitText {
        visible: sep.style === "slash"
        anchors.centerIn: parent
        text: sep.vertical ? "—" : "│"
        font.family: Type.monoFont !== undefined && Type.monoFont !== "" ? Type.monoFont : Type.bodyFont
        font.pixelSize: Math.round(sep.moduleSize * 0.6)
        color: Type.muted
    }
}
