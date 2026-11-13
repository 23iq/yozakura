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
// current tab differs from its default (one undo step). In a narrow window
// the tabs take a line of their own, scrolling sideways when still too wide.
Item {
    id: header

    // The current tab (a Categories category).
    property var category: null
    readonly property var destination: header.category ? Categories.groupOf(header.category.id) : null
    readonly property var tabs: header.category ? Categories.tabsOf(header.category.id) : []
    readonly property int currentTab: header.tabs.findIndex(c => header.category && c.id === header.category.id)
    readonly property int modifiedCount: header.category && header.category.sections ? SettingsStore.modifiedCount(header.category) : 0

    signal tabSelected(string id)
    signal back

    // the tabs fit centred on the title line, clear of the title and of
    // the right-hand controls; else they take a line of their own
    readonly property real rightW: undoButton.width + (resetLabel.visible ? resetLabel.width + Space.m : 0)
    readonly property real sideRoom: Math.max(titleRow.width, header.rightW) + Space.l
    readonly property bool tabsOwnLine: tabsLoader.active && tabsLoader.implicitWidth > header.width - header.sideRoom * 2
    implicitHeight: Space.controlL + (header.tabsOwnLine ? Space.s + tabsLoader.implicitHeight : 0)

    Row {
        id: titleRow
        y: (Space.controlL - height) / 2
        spacing: Space.m

        IconButton {
            objectName: "backPill"
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.arrowLeft
            size: "m"
            focusable: true
            tooltip: I18n.t("prefs.home.back")
            onClicked: header.back()
            Accessible.name: I18n.t("prefs.home.back")
        }
        KitText {
            objectName: "destinationTitle"
            anchors.verticalCenter: parent.verticalCenter
            role: "title"
            font.pixelSize: Math.round(Type.size("title") * 1.25)
            text: header.destination ? I18n.t(header.destination.title) : ""
        }
    }

    // the tabs: a sideways-scrolling line when wider than the window
    Flickable {
        id: tabsView
        objectName: "destinationTabsView"
        readonly property real room: header.tabsOwnLine ? header.width : header.width - header.sideRoom * 2
        width: Math.min(room, tabsLoader.implicitWidth)
        height: tabsLoader.implicitHeight
        x: (header.width - width) / 2
        y: header.tabsOwnLine ? Space.controlL + Space.s : (Space.controlL - height) / 2
        visible: tabsLoader.active
        contentWidth: tabsLoader.implicitWidth
        contentHeight: height
        interactive: contentWidth > width
        clip: interactive
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        // the current tab scrolls into view
        function reveal() {
            if (!tabsLoader.item || !tabsView.interactive)
                return;
            const n = Math.max(1, header.tabs.length);
            const i = Math.max(0, header.currentTab);
            const centre = tabsView.contentWidth * (i + 0.5) / n;
            tabsView.contentX = Math.max(0, Math.min(centre - tabsView.width / 2, tabsView.contentWidth - tabsView.width));
        }
        onWidthChanged: Qt.callLater(tabsView.reveal)
        Connections {
            target: header
            function onCategoryChanged() {
                Qt.callLater(tabsView.reveal);
            }
        }

        Loader {
            id: tabsLoader
            active: header.tabs.length > 1
            sourceComponent: Segmented {
                objectName: "destinationTabs"
                focusable: true
                model: header.tabs.map(c => ({
                            "name": "tab:" + c.id,
                            "icon": "",
                            "text": I18n.t(c.title)
                        }))
                currentIndex: header.currentTab
                onActivated: i => header.tabSelected(header.tabs[i].id)
            }
        }
    }
    // edge fades while the line scrolls
    Mark {
        visible: tabsView.interactive && tabsView.contentX > 1
        x: tabsView.x
        y: tabsView.y
        width: Space.xl
        height: tabsView.height
        radius: 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Colors.background
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }
    Mark {
        visible: tabsView.interactive && tabsView.contentX < tabsView.contentWidth - tabsView.width - 1
        x: tabsView.x + tabsView.width - width
        y: tabsView.y
        width: Space.xl
        height: tabsView.height
        radius: 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Colors.background
            }
        }
    }

    IconButton {
        id: undoButton
        objectName: "pageUndo"
        anchors.right: parent.right
        y: (Space.controlL - height) / 2
        icon: Icons.arrowCounterClockwise
        // "m": a boxed language (glass) draws "l" as a 70 px disc
        size: "m"
        focusable: true
        enabled: SettingsStore.undoStack.length > 0
        opacity: enabled ? 1 : 0.4
        tooltip: I18n.t("prefs.home.undo")
        onClicked: SettingsStore.undo()
    }

    // a real (quiet) button, not grey text: it resets the whole tab
    PillButton {
        id: resetLabel
        objectName: "pageReset"
        anchors.right: undoButton.left
        anchors.rightMargin: Space.m
        anchors.verticalCenter: undoButton.verticalCenter
        visible: header.modifiedCount > 0
        kind: "ghost"
        text: I18n.t("prefs.common.reset_page")
        onClicked: SettingsStore.resetCategory(header.category)
    }
}
