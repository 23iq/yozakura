import QtQuick
import qs.modules.theme
import qs.modules.settings.controls
import qs.config
import "../settings/Ui.js" as Ui

// A selectable card row: icon chip, title, subtitle and, on the right,
// a check mark (`mode: "check"`), a switch (`"toggle"`), an arrow
// (`"link"`: opens something) or nothing (`"none"`, e.g. status-only rows). `badge` is a small status pill.
Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string badge: ""
    property bool badgeOk: true
    property bool checked: false
    property string mode: "check"
    property bool dimmed: false

    signal clicked
    signal toggled(bool value)

    implicitHeight: Math.max(Math.round(Styling.fontSize(0) * 4), col.implicitHeight + 22)
    activeFocusOnTab: mode !== "none"

    Keys.onSpacePressed: activate()
    Keys.onReturnPressed: activate()

    function activate() {
        if (!enabled)
            return;
        if (mode === "toggle")
            toggled(!checked);
        else
            clicked();
    }

    Rectangle {
        anchors.fill: parent
        radius: Styling.radius(2)
        color: root.checked && root.mode === "check" ? Ui.alpha(Colors.primary, 0.14) : (area.containsMouse ? Ui.alpha(Colors.overBackground, 0.07) : Ui.alpha(Colors.overBackground, 0.035))
        border.width: root.activeFocus ? 2 : (root.checked && root.mode === "check" ? 1 : 0)
        border.color: Colors.primary
        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Motion.exit.duration
            }
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 12
        opacity: root.dimmed ? 0.55 : 1

        Rectangle {
            id: chip
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(Styling.fontSize(0) * 2.3)
            height: width
            radius: Math.min(width / 2, Styling.radius(0))
            color: Ui.alpha(Colors.primary, 0.14)
            Text {
                anchors.centerIn: parent
                text: Icons[root.icon] ?? ""
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(1)
                color: Colors.primary
            }
        }

        Column {
            id: col
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (chip.visible ? chip.width + parent.spacing : 0) - trailing.width - parent.spacing
            spacing: 2
            Row {
                spacing: 8
                width: parent.width
                Text {
                    id: titleText
                    text: root.title
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width - (badgePill.visible ? badgePill.width + 8 : 0))
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.DemiBold
                    color: Colors.overBackground
                }
                Rectangle {
                    id: badgePill
                    visible: root.badge !== ""
                    anchors.verticalCenter: titleText.verticalCenter
                    width: badgeText.implicitWidth + 14
                    height: badgeText.implicitHeight + 4
                    radius: height / 2
                    color: Ui.alpha(root.badgeOk ? Colors.primary : Colors.outline, 0.16)
                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: root.badge
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-3)
                        font.weight: Font.Medium
                        color: root.badgeOk ? Colors.primary : Colors.outline
                    }
                }
            }
            Text {
                visible: root.subtitle !== ""
                width: parent.width
                text: root.subtitle
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overSurfaceVariant
            }
        }

        Item {
            id: trailing
            anchors.verticalCenter: parent.verticalCenter
            width: root.mode === "toggle" ? toggle.implicitWidth : (root.mode === "check" ? check.width : (root.mode === "link" ? arrow.implicitWidth : 0))
            height: Math.max(toggle.implicitHeight, check.height)

            ToggleControl {
                id: toggle
                visible: root.mode === "toggle"
                anchors.centerIn: parent
                enabled: root.enabled
                checked: root.checked
                onToggled: v => root.toggled(v)
            }
            Text {
                id: arrow
                visible: root.mode === "link"
                anchors.centerIn: parent
                text: Icons.caretRight
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overSurfaceVariant
            }
            Rectangle {
                id: check
                visible: root.mode === "check"
                anchors.centerIn: parent
                width: Math.round(Styling.fontSize(0) * 1.5)
                height: width
                radius: width / 2
                color: root.checked ? Colors.primary : "transparent"
                border.width: root.checked ? 0 : 2
                border.color: Ui.alpha(Colors.overBackground, 0.25)
                Text {
                    visible: root.checked
                    anchors.centerIn: parent
                    text: Icons.accept
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(-3)
                    color: Colors.overPrimary
                }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.mode !== "none"
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activate()
    }
}
