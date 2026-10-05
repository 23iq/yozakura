import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme

// Divider between modules of strip styles (BarModuleGroup `separator`):
// "line" hairline, "dot" bullet, "slash" a thin diagonal (statusline).
Item {
    id: sep

    property bool vertical: false
    property string style: "line"
    property int moduleSize: BarMetrics.moduleSize

    readonly property real crossLength: Math.round(moduleSize * 0.42)

    implicitWidth: vertical ? moduleSize : (style === "line" ? 9 : 12)
    implicitHeight: vertical ? (style === "line" ? 9 : 12) : moduleSize
    Layout.alignment: Qt.AlignCenter

    Rectangle {
        visible: sep.style === "line"
        anchors.centerIn: parent
        width: sep.vertical ? sep.crossLength : 1
        height: sep.vertical ? 1 : sep.crossLength
        color: Colors.outlineVariant
        opacity: 0.9
    }

    Rectangle {
        visible: sep.style === "dot"
        anchors.centerIn: parent
        width: 4
        height: 4
        radius: 2
        color: Colors.overSurfaceVariant
        opacity: 0.55
    }

    Text {
        visible: sep.style === "slash"
        anchors.centerIn: parent
        text: sep.vertical ? "—" : "│"
        font.family: Config.theme.monoFont !== undefined && Config.theme.monoFont !== "" ? Config.theme.monoFont : Config.theme.font
        font.pixelSize: Math.round(sep.moduleSize * 0.6)
        color: Colors.outline
    }
}
