pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import "../../services/KeyboardModel.js" as KeyboardModel

// Search over the XKB layout catalog; picking one emits picked(code).
// `skip` lists the codes already configured.
Item {
    id: root

    property var catalog: null
    property var skip: []
    readonly property var results: KeyboardModel.searchLayouts(catalog, search.text, skip)

    signal picked(string code)

    // Search field, a gap, up to six rows of results (one row of room
    // for the empty / loading note), and the bottom padding.
    readonly property int listTop: Space.controlM + Space.l
    implicitHeight: root.listTop + Math.min(Math.max(results.length, 1), 6) * Space.rowHeight + Space.l

    function focusSearch() {
        search.focusInput();
    }

    SearchField {
        id: search
        objectName: "pickerSearch"
        x: Space.l
        width: parent.width - Space.l * 2
        boxed: true
        placeholderText: I18n.t("prefs.keyboard.search")
    }

    KitText {
        role: "secondary"
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.listTop + (Space.rowHeight - height) / 2
        visible: root.results.length === 0
        text: root.catalog ? I18n.t("prefs.keyboard.no_results") : I18n.t("prefs.keyboard.loading")
    }

    ListView {
        id: list
        objectName: "pickerList"
        x: Space.l
        y: root.listTop
        width: parent.width - Space.l * 2
        height: Math.min(root.results.length, 6) * Space.rowHeight
        clip: true
        model: root.results
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: ListRow {
            id: layoutRow
            required property var modelData
            width: ListView.view.width
            title: layoutRow.modelData.description
            leading: Component {
                LayoutBadge {
                    width: Space.controlS
                    height: Space.controlXS
                    radius: Look.radius("small")
                    code: layoutRow.modelData.name
                }
            }
            onClicked: root.picked(layoutRow.modelData.name)
        }
    }
}
