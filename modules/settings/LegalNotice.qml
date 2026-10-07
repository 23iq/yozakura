import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services
import qs.modules.components.kit

// One small legal row ("AGPL-3.0 · Licenses & credits"). Clicking it shows
// NOTICE inline (in the language's control box); the full license text
// opens in the default viewer.
Column {
    id: root
    objectName: "aboutLegalNotice"

    property bool expanded: false
    property string notice: ""
    readonly property string noticePath: decodeURIComponent(Qt.resolvedUrl("../../NOTICE").toString().replace("file://", ""))
    readonly property string licensePath: decodeURIComponent(Qt.resolvedUrl("../../LICENSE").toString().replace("file://", ""))

    spacing: Space.m

    FileView {
        path: root.expanded ? root.noticePath : ""
        onLoaded: root.notice = text()
    }

    KitText {
        objectName: "aboutLegal"
        anchors.horizontalCenter: parent.horizontalCenter
        role: "caption"
        text: I18n.t("prefs.about.legal")
        font.underline: legalArea.containsMouse
        color: legalArea.containsMouse || activeFocus ? Type.text : Type.muted
        activeFocusOnTab: true
        Keys.onReturnPressed: root.expanded = !root.expanded
        Keys.onSpacePressed: root.expanded = !root.expanded

        MouseArea {
            id: legalArea
            anchors.fill: parent
            anchors.margins: -Space.s
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    Item {
        visible: root.expanded
        width: parent.width
        height: Math.min(noticeText.implicitHeight + Space.m * 2, Space.px(220))

        ControlBox {
            radius: Look.chipRadius(Space.chip)
        }
        Flickable {
            anchors.fill: parent
            anchors.margins: Space.m
            clip: true
            contentHeight: noticeText.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            KitText {
                id: noticeText
                objectName: "aboutNoticeText"
                width: parent.width
                role: "caption"
                wrapMode: Text.WordWrap
                text: root.notice
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
