import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services

// Top of the clock panel: the time large (tabular digits), the full date
// under it and the pencil that toggles bento edit mode.
RowLayout {
    id: root

    property date now: new Date()
    property bool use12h: false
    property bool editing: false
    signal editToggled

    readonly property var dayKeys: ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
    readonly property var monthKeys: ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]

    spacing: Metrics.spacing

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            objectName: "clockPanelTime"
            text: Qt.formatDateTime(root.now, root.use12h ? "h:mm AP" : "HH:mm")
            color: Colors.overBackground
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(14)
            font.weight: Font.Black
            font.features: {
                "tnum": 1
            }
        }
        Text {
            objectName: "clockPanelDate"
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: I18n.t("calendar.day_full." + root.dayKeys[root.now.getDay()]) + ", " + I18n.t("calendar.month." + root.monthKeys[root.now.getMonth()]) + " " + root.now.getDate()
            color: Colors.outline
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
        }
    }

    StyledRect {
        objectName: "clockPanelEdit"
        Layout.alignment: Qt.AlignTop
        variant: root.editing ? "primary" : (editArea.containsMouse ? "focus" : "common")
        enableShadow: false
        implicitWidth: Metrics.badgeHeight + Metrics.spacing
        implicitHeight: implicitWidth
        radius: Styling.radius(-4)

        Text {
            anchors.centerIn: parent
            text: root.editing ? Icons.check : Icons.pencil
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(0)
            color: parent.item
        }
        MouseArea {
            id: editArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.editToggled()
        }
        StyledToolTip {
            visible: editArea.containsMouse
            tooltipText: I18n.t(root.editing ? "bento.done" : "bento.edit")
        }
    }
}
