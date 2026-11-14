pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "schema/Categories.js" as Categories

// The only chrome of a destination page: a back pill and the destination
// title on the left, its tabs (the kit Segmented as navigation, when it has
// several) right after the title, and on the right two quiet buttons that
// are always there: History (the session's changes, newest first: a click
// undoes back to that one) and ⋯ (Reset page, all changes). Nothing on the
// line appears or goes with the page's state, so the header never reflows
// and the tabs start at the same place in every destination; in a narrow
// window the tabs take a line of their own, scrolling sideways when still
// too wide.
Item {
    id: header

    // The current tab (a Categories category).
    property var category: null
    readonly property var destination: header.category ? Categories.groupOf(header.category.id) : null
    readonly property string destinationId: header.destination ? header.destination.id : ""
    readonly property var tabs: header.category ? Categories.tabsOf(header.category.id) : []
    readonly property int currentTab: header.tabs.findIndex(c => header.category && c.id === header.category.id)
    readonly property int modifiedCount: header.category && header.category.sections ? SettingsStore.modifiedCount(header.category) : 0
    // the tabs' model: rebuilt when the destination changes, not per click
    readonly property var tabModel: {
        const g = Categories.groupById(header.destinationId);
        return g ? Categories.tabsOf(g.categories[0]).map(c => ({
                    "name": "tab:" + c.id,
                    "icon": "",
                    "text": I18n.t(c.title)
                })) : [];
    }

    signal tabSelected(string id)
    signal back

    // the right-hand buttons take a fixed room (never the page's state)
    readonly property real rightW: historyButton.width + Space.s + moreButton.width
    readonly property real tabsX: titleRow.width + Space.xl
    readonly property real tabsRoom: header.width - header.tabsX - header.rightW - Space.l
    readonly property bool tabsOwnLine: tabsLoader.active && tabsLoader.implicitWidth > header.tabsRoom
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
        readonly property real room: header.tabsOwnLine ? header.width : header.tabsRoom
        width: Math.min(room, tabsLoader.implicitWidth)
        height: tabsLoader.implicitHeight
        x: header.tabsOwnLine ? 0 : header.tabsX
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
            active: header.tabModel.length > 1
            sourceComponent: Segmented {
                objectName: "destinationTabs"
                focusable: true
                navigation: true
                model: header.tabModel
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

    // ⋯: what acts on the whole page (Reset page is one undoable step)
    IconButton {
        id: moreButton
        objectName: "pageMore"
        anchors.right: parent.right
        y: (Space.controlL - height) / 2
        icon: Icons.dotsThree
        size: "m"
        focusable: true
        active: moreMenu.opened
        tooltip: I18n.t("prefs.page.more")
        Accessible.name: I18n.t("prefs.page.more")
        onClicked: moreMenu.opened ? moreMenu.close() : moreMenu.open()

        PageMenu {
            id: moreMenu
            items: [
                {
                    "name": "reset",
                    "text": I18n.t("prefs.common.reset_page"),
                    "subtitle": header.modifiedCount > 0 ? I18n.tn("prefs.page.reset_count", header.modifiedCount) : I18n.t("prefs.page.reset_none"),
                    "enabled": header.modifiedCount > 0
                },
                {
                    "name": "changes",
                    "text": I18n.t("prefs.page.all_changes")
                }
            ]
            onTriggered: name => {
                if (name === "reset")
                    SettingsStore.resetCategory(header.category);
                else if (name === "changes")
                    SettingsStore.navigate("changes");
            }
        }
    }

    // History: the session's changes, newest first
    IconButton {
        id: historyButton
        objectName: "pageUndo"
        anchors.right: moreButton.left
        anchors.rightMargin: Space.s
        y: (Space.controlL - height) / 2
        icon: Icons.clockCounterClockwise
        // "m": a boxed language (glass) draws "l" as a 70 px disc
        size: "m"
        focusable: true
        active: historyMenu.opened
        tooltip: I18n.t("prefs.history")
        Accessible.name: I18n.t("prefs.history")
        onClicked: historyMenu.opened ? historyMenu.close() : historyMenu.open()

        PageMenu {
            id: historyMenu
            objectName: "historyMenu"
            empty: I18n.t("prefs.history.empty")
            items: {
                const say = (s, kind) => {
                    const what = s && s.label ? I18n.t(s.label) : I18n.t("prefs.undo.something");
                    return kind === "changed" && String(s.label).startsWith("prefs.undo.") ? what : I18n.t("prefs.undo." + kind).arg(what);
                };
                const out = [];
                const redo = SettingsStore.redoStack;
                if (redo.length > 0)
                    out.push({
                        "name": "redo",
                        "text": say(redo[redo.length - 1], "undone"),
                        "subtitle": I18n.t("prefs.undo.redo")
                    });
                const undo = SettingsStore.undoStack;
                for (let k = 0; k < Math.min(8, undo.length); k++)
                    out.push({
                        "name": "undo:" + (k + 1),
                        "text": say(undo[undo.length - 1 - k], "changed"),
                        "subtitle": k === 0 ? I18n.t("prefs.undo.undo") : I18n.t("prefs.history.undo_back")
                    });
                return out;
            }
            // a change below the newest undoes it and every newer one
            onTriggered: name => {
                if (name === "redo") {
                    SettingsStore.redo();
                    return;
                }
                const n = Number(name.split(":")[1]) || 0;
                for (let i = 0; i < n; i++) {
                    if (!SettingsStore.undo())
                        break;
                }
            }
        }
    }
}
