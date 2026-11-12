pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "schema/Categories.js" as Categories

// The top of the settings content: the destination's icon and title, its
// tabs (a kit Segmented, only when it has several) and a quiet "Reset page"
// while a row of the current tab differs from its default (one undo step).
Item {
    id: header

    // The current tab (a Categories category).
    property var category: null
    readonly property var destination: header.category ? Categories.groupOf(header.category.id) : null
    readonly property var tabs: header.category ? Categories.tabsOf(header.category.id) : []
    readonly property int modifiedCount: header.category && header.category.sections ? SettingsStore.modifiedCount(header.category) : 0

    signal tabSelected(string id)

    implicitHeight: titleRow.height + (header.tabs.length > 1 ? tabsLoader.height + Space.l : 0)

    Row {
        id: titleRow
        spacing: Space.m
        height: Math.max(titleText.implicitHeight, glyph.implicitHeight)

        Icon {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            icon: header.destination ? (Icons[header.destination.icon] ?? "") : ""
            role: "title"
            tone: "accent"
        }
        KitText {
            id: titleText
            objectName: "destinationTitle"
            anchors.verticalCenter: parent.verticalCenter
            role: "title"
            text: header.destination ? I18n.t(header.destination.title) : ""
        }
    }

    SectionLabel {
        objectName: "pageReset"
        anchors.right: parent.right
        anchors.verticalCenter: titleRow.verticalCenter
        inset: 0
        visible: header.modifiedCount > 0
        action: I18n.t("prefs.common.reset_page")
        onTriggered: SettingsStore.resetCategory(header.category)
    }

    Loader {
        id: tabsLoader
        y: titleRow.height + Space.l
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
}
