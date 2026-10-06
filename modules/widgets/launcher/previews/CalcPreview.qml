import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

// Calculator / unit conversion preview: the full result, its expression and
// a copy button.
ColumnLayout {
    id: preview

    property var result: null
    readonly property string value: result && result.data ? String(result.data.value) : ""

    spacing: Metrics.spacing

    Item {
        Layout.fillHeight: true
    }

    Text {
        Layout.fillWidth: true
        text: preview.result ? preview.result.subtitle || "" : ""
        color: Colors.outline
        font.family: Config.theme.monoFont
        font.pixelSize: Styling.fontSize(-1)
        wrapMode: Text.WrapAnywhere
        maximumLineCount: 3
        elide: Text.ElideRight
    }

    Text {
        Layout.fillWidth: true
        text: preview.result ? preview.result.title || "" : ""
        color: Colors.primary
        font.family: Config.theme.monoFont
        font.pixelSize: Styling.fontSize(6)
        font.weight: Font.Bold
        wrapMode: Text.WrapAnywhere
        maximumLineCount: 4
        elide: Text.ElideRight
    }

    StyledRect {
        Layout.topMargin: Metrics.spacing
        implicitWidth: label.implicitWidth + Metrics.padding * 2
        implicitHeight: Metrics.menuItemH
        variant: copyArea.containsMouse ? "primary" : "common"
        radius: Styling.radius(-2)

        Text {
            id: label
            anchors.centerIn: parent
            text: I18n.t("launcher.copy")
            color: copyArea.containsMouse ? Styling.srItem("primary") : Colors.overBackground
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.Medium
        }
        MouseArea {
            id: copyArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["wl-copy", "--", preview.value])
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
