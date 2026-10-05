import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.services
import qs.config
import "Ui.js" as Ui

// One small legal row ("AGPL-3.0 · Licenses & credits"). Clicking it shows
// NOTICE inline; the full license text opens in the default viewer.
Column {
    id: root
    objectName: "aboutLegalNotice"

    property bool expanded: false
    property string notice: ""
    readonly property string noticePath: decodeURIComponent(Qt.resolvedUrl("../../NOTICE").toString().replace("file://", ""))
    readonly property string licensePath: decodeURIComponent(Qt.resolvedUrl("../../LICENSE").toString().replace("file://", ""))

    spacing: 10

    FileView {
        path: root.expanded ? root.noticePath : ""
        onLoaded: root.notice = text()
    }

    Text {
        objectName: "aboutLegal"
        anchors.horizontalCenter: parent.horizontalCenter
        text: I18n.t("prefs.about.legal")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        font.underline: legalArea.containsMouse
        color: legalArea.containsMouse ? Colors.primary : Colors.overSurfaceVariant
        activeFocusOnTab: true
        Keys.onReturnPressed: root.expanded = !root.expanded
        Keys.onSpacePressed: root.expanded = !root.expanded

        MouseArea {
            id: legalArea
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    Rectangle {
        visible: root.expanded
        width: parent.width
        height: Math.min(noticeText.implicitHeight + 24, 220)
        radius: Styling.radius(4)
        color: Ui.alpha(Colors.overBackground, 0.05)

        Flickable {
            anchors.fill: parent
            anchors.margins: 12
            clip: true
            contentHeight: noticeText.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Text {
                id: noticeText
                objectName: "aboutNoticeText"
                width: parent.width
                wrapMode: Text.WordWrap
                text: root.notice
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                color: Colors.overSurfaceVariant
            }
        }
    }

    PillButton {
        visible: root.expanded
        anchors.horizontalCenter: parent.horizontalCenter
        kind: "ghost"
        icon: "fileText"
        text: I18n.t("prefs.about.full_license")
        onClicked: Quickshell.execDetached(["xdg-open", root.licensePath])
    }
}
