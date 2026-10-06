pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import "../Ui.js" as Ui
import "../../services/KeyboardModel.js" as KeyboardModel

// Search over the XKB layout catalog; picking one emits picked(code).
// `skip` lists the codes already configured.
Item {
    id: root

    property var catalog: null
    property var skip: []
    readonly property var results: KeyboardModel.searchLayouts(catalog, search.text, skip)

    signal picked(string code)

    implicitHeight: 48 + 12 + Math.min(Math.max(results.length, 1), 6) * 50 + 16

    function focusSearch() {
        search.focusInput();
    }

    SearchInput {
        id: search
        objectName: "pickerSearch"
        x: 20
        width: parent.width - 40
        iconText: Icons.magnifyingGlass
        placeholderText: I18n.t("prefs.keyboard.search")
    }

    Rectangle {
        anchors.fill: search
        radius: search.radius
        color: "transparent"
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.6)
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 80
        visible: root.results.length === 0
        text: root.catalog ? I18n.t("prefs.keyboard.no_results") : I18n.t("prefs.keyboard.loading")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        color: Colors.overSurfaceVariant
    }

    ListView {
        id: list
        objectName: "pickerList"
        x: 20
        y: 60
        width: parent.width - 40
        height: Math.min(root.results.length, 6) * 50
        clip: true
        model: root.results
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: Item {
            id: item
            required property var modelData
            width: ListView.view.width - 10
            height: 50

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: Styling.radius(1)
                color: area.containsMouse ? Ui.alpha(Colors.primary, 0.14) : "transparent"
            }
            LayoutBadge {
                id: badge
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 34
                radius: 10
                code: item.modelData.name
            }
            Text {
                anchors.left: badge.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: item.modelData.description
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overBackground
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(item.modelData.name)
            }
        }
    }
}
