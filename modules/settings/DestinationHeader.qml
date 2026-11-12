pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "schema/Categories.js" as Categories

// The only chrome of a destination page: a back pill and the destination
// title on the left, its tabs (the kit Segmented, when it has several)
// centred, and a quiet "Reset page" on the right while a control of the
// current tab differs from its default (one undo step).
Item {
    id: header

    // The current tab (a Categories category).
    property var category: null
    readonly property var destination: header.category ? Categories.groupOf(header.category.id) : null
    readonly property var tabs: header.category ? Categories.tabsOf(header.category.id) : []
    readonly property int modifiedCount: header.category && header.category.sections ? SettingsStore.modifiedCount(header.category) : 0

    signal tabSelected(string id)
    signal back

    implicitHeight: Space.controlM

    Row {
        id: titleRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.m

        IconButton {
            objectName: "backPill"
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.arrowLeft
            size: "s"
            focusable: true
            tooltip: I18n.t("prefs.home.back")
            onClicked: header.back()
            Accessible.name: I18n.t("prefs.home.back")
        }
        KitText {
            objectName: "destinationTitle"
            anchors.verticalCenter: parent.verticalCenter
            role: "title"
            text: header.destination ? I18n.t(header.destination.title) : ""
        }
    }

    Loader {
        id: tabsLoader
        anchors.centerIn: parent
        // centred, clear of the title when the window is narrow
        anchors.horizontalCenterOffset: Math.max(0, titleRow.width + Space.l - (header.width - tabsLoader.implicitWidth) / 2)
        active: header.tabs.length > 1
        visible: active
        sourceComponent: Segmented {
            objectName: "destinationTabs"
            focusable: true
            model: header.tabs.map(c => ({
                        "name": "tab:" + c.id,
                        "icon": "",
                        "text": I18n.t(c.title)
                    }))
            currentIndex: header.tabs.findIndex(c => header.category && c.id === header.category.id)
            onActivated: i => header.tabSelected(header.tabs[i].id)
        }
    }

    SectionLabel {
        objectName: "pageReset"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        inset: 0
        visible: header.modifiedCount > 0
        action: I18n.t("prefs.common.reset_page")
        onTriggered: SettingsStore.resetCategory(header.category)
    }
}
