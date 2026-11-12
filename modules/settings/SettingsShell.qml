pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.globals
import qs.modules.services
import qs.config
import qs.modules.settings.store
import qs.modules.settings.presets
import "schema/Categories.js" as Categories
import "presets/PresetModel.js" as PresetModel
import "Ui.js" as Ui

// Settings window content, the "showcase" frame: a home screen
// (SettingsHome: search + a bento of live tiles + pills) and, once a
// destination is opened, its page - the tile expands into it (a shared
// element: a box grows from the tile to the window while the page fades
// in) - with only a back pill, the title and the tabs as chrome
// (DestinationHeader) over the page (SettingsPageHost: built on first
// visit, kept alive). Esc, the back pill, the mouse back button and
// Alt+Left return home (the page collapses back into its tile). Every
// change applies at once; Ctrl+Z / Ctrl+Shift+Z undo / redo it (UndoPill).
Item {
    id: shell

    property string currentCategory: ""
    property bool atHome: true
    // 0 = home, 1 = page fully open (animated).
    property real reveal: atHome ? 0 : 1
    // Where the page grows from / shrinks back to (a home tile), in shell
    // coordinates; null: from the middle.
    property var origin: null
    property var pendingReveal: null
    readonly property alias home: homeView
    // Off until the first frame: a deep link opens straight on its page.
    property bool animated: false

    Behavior on reveal {
        enabled: shell.animated && Motion.glide.duration > 0
        NumberAnimation {
            duration: Motion.glide.duration
            easing.type: Motion.glide.easing
        }
    }

    // Accepts a category id, a moved id or a destination id
    // (Categories.resolve); opens its page (a tab of the same destination
    // slides in from its side).
    function select(id) {
        const c = Categories.resolve(id);
        if (!c)
            return;
        const changed = c.id !== currentCategory || !page.item;
        const tabs = Categories.tabsOf(c.id);
        const from = tabs.findIndex(t => t.id === currentCategory);
        const to = tabs.findIndex(t => t.id === c.id);
        page.direction = !shell.atHome && from >= 0 && to >= 0 && from !== to ? (to > from ? 1 : -1) : 0;
        currentCategory = c.id;
        GlobalStates.settingsCategory = c.id;
        if (changed)
            page.load(c);
        shell.atHome = false;
    }

    // A home tile (or pill) opens its destination's first tab, growing
    // out of the tile.
    function openDestination(id, from) {
        const g = Categories.groupById(id);
        if (!g)
            return;
        if (from) {
            const p = from.mapToItem(shell, 0, 0);
            shell.origin = {
                "x": p.x,
                "y": p.y,
                "w": from.width,
                "h": from.height
            };
        } else {
            shell.origin = null;
        }
        select(g.categories[0]);
    }

    function goHome() {
        if (shell.atHome)
            return;
        shell.atHome = true;
        GlobalStates.settingsCategory = "";
        homeView.forceActiveFocus();
    }

    function openSearch() {
        goHome();
        Qt.callLater(homeView.focusSearch);
    }

    function navigate(categoryId, sectionId, entryId) {
        pendingReveal = {
            "section": sectionId || "",
            "entry": entryId || ""
        };
        const c = Categories.resolve(categoryId);
        if (c && c.id === currentCategory && page.item && !shell.atHome)
            revealTimer.restart();
        else
            select(categoryId);
    }

    // The active preset's actions (home footer, changes sheet, toast).
    function presetAction(id) {
        const toast = (ok, message, undo) => PresetStudio.notify(message, undo ? "save:" + undo : "");
        if (id === "save")
            PresetStudio.afterFlush(() => PresetStatusService.save(toast));
        else if (id === "saveAs")
            saveAsDialog.ask(I18n.t("presets.status.dialog_save_as"), PresetModel.uniqueName(PresetStudio.presets, PresetStatusService.suggestedName()), I18n.t("prefs.presets.save"), "", n => PresetStudio.afterFlush(() => PresetStatusService.saveAs(n, toast)));
        else if (id === "changes")
            changesSheet.open = true;
        else if (id === "revert")
            PresetStatusService.revert(toast);
    }

    function step(delta) {
        const list = Categories.ordered();
        let i = list.findIndex(c => c.id === currentCategory);
        i = (i + delta + list.length) % list.length;
        select(list[i].id);
    }

    // Another part of the shell asks for a page (e.g. the microphone
    // activity opens Sound) while the window is open.
    Connections {
        target: GlobalStates
        function onSettingsCategoryChanged() {
            if (GlobalStates.settingsCategory && (GlobalStates.settingsCategory !== shell.currentCategory || shell.atHome))
                shell.select(GlobalStates.settingsCategory);
        }
        // a plain open after a close starts at home
        function onSettingsWindowVisibleChanged() {
            if (!GlobalStates.settingsWindowVisible) {
                // the next open (maybe a deep link) starts without motion
                shell.animated = false;
                shell.atHome = true;
                GlobalStates.settingsCategory = "";
            } else {
                Qt.callLater(() => shell.animated = true);
            }
        }
    }

    Component.onCompleted: {
        // A preset trial or edit outlives the window: bring back its pill/banner.
        PresetStudio.refreshSessions();
        if (Categories.resolve(GlobalStates.settingsCategory))
            select(GlobalStates.settingsCategory);
        else
            homeView.forceActiveFocus();
        Qt.callLater(() => shell.animated = true);
    }

    Connections {
        target: SettingsStore
        function onNavigateRequested(categoryId, sectionId, entryId) {
            shell.navigate(categoryId, sectionId, entryId);
        }
    }

    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: shell.openSearch()
    }
    Shortcut {
        sequences: ["Alt+Left"]
        onActivated: shell.goHome()
    }
    Shortcut {
        sequences: ["Ctrl+Z"]
        onActivated: SettingsStore.undo()
    }
    Shortcut {
        sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]
        onActivated: SettingsStore.redo()
    }
    Shortcut {
        sequences: ["Ctrl+PgDown", "Ctrl+Tab"]
        onActivated: shell.step(1)
    }
    Shortcut {
        sequences: ["Ctrl+PgUp", "Ctrl+Shift+Tab"]
        onActivated: shell.step(-1)
    }
    // Esc returns home when nothing inside took it (a search field clears
    // itself first, a popup closes first).
    Keys.onEscapePressed: shell.goHome()

    // Window background: the theme's "bg" surface, or the language's
    // translucent window fill (glass) over the desktop.
    StyledRect {
        anchors.fill: parent
        visible: !Look.windowTranslucent
        variant: "bg"
        glassSurface: "settings"
        radius: 0
        enableBorder: false
    }
    Rectangle {
        objectName: "windowGlass"
        anchors.fill: parent
        visible: Look.windowTranslucent
        color: Look.windowFill
    }

    // The mouse back button returns home.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        onClicked: shell.goHome()
    }

    PresetEditBanner {
        id: editBanner
        width: parent.width
        z: 5
    }

    SettingsHome {
        id: homeView
        objectName: "settingsHome"
        y: editBanner.height
        width: parent.width
        height: parent.height - y
        visible: shell.reveal < 1
        enabled: shell.atHome
        focus: shell.atHome
        opacity: 1 - shell.reveal
        scale: 1 - shell.reveal * 0.03
        onDestinationOpened: (id, tile) => shell.openDestination(id, tile)
        onResultActivated: r => shell.navigate(r.categoryId, r.sectionId, r.entryId)
        onPresetAction: id => shell.presetAction(id)
    }

    // The shared element: a box growing from the tile to the window.
    Mark {
        readonly property var o: shell.origin || {
            "x": shell.width * 0.4,
            "y": shell.height * 0.4,
            "w": shell.width * 0.2,
            "h": shell.height * 0.2
        }
        readonly property real t: shell.reveal
        visible: t > 0 && t < 1
        x: o.x * (1 - t)
        y: o.y * (1 - t)
        width: o.w + (shell.width - o.w) * t
        height: o.h + (shell.height - o.h) * t
        radius: Look.bigRadius(Space.controlXL) * (1 - t)
        color: Look.raisedFill(false)
        opacity: Math.min(1, (1 - t) * 4)
    }

    FocusScope {
        id: pageView
        objectName: "settingsPageView"
        y: editBanner.height
        width: parent.width
        height: parent.height - y
        visible: shell.reveal > 0
        enabled: !shell.atHome
        focus: !shell.atHome
        // the page arrives once the box has nearly grown
        opacity: Math.max(0, (shell.reveal - 0.4) / 0.6)

        DestinationHeader {
            id: header
            objectName: "destinationHeader"
            x: Space.xl
            y: Space.l
            width: parent.width - Space.xl * 2
            category: page.category
            onTabSelected: id => shell.select(id)
            onBack: shell.goHome()
        }

        SettingsPageHost {
            id: page
            objectName: "settingsPage"
            y: header.y + header.height + Space.m
            width: parent.width
            height: parent.height - y
            onLoaded: {
                if (shell.pendingReveal)
                    revealTimer.restart();
            }
        }
    }

    UndoPill {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Space.xl
        z: 6
    }

    PresetTrialPill {
        anchors.horizontalCenter: parent.horizontalCenter
        y: editBanner.height + Space.l
        z: 6
    }

    PresetToast {
        anchors.left: parent.left
        anchors.leftMargin: Space.xl
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Space.xl
        z: 6
        onDetailsRequested: shell.presetAction("changes")
    }

    PresetChangesSheet {
        id: changesSheet
        objectName: "presetChangesSheet"
        anchors.fill: parent
        z: 7
        index: homeView.index
        onClosed: open = false
        onActionRequested: id => shell.presetAction(id)
        onNavigate: (c, s, e) => shell.navigate(c, s, e)
    }

    PresetNameDialog {
        id: saveAsDialog
    }

    // Reveal after the page laid out.
    Timer {
        id: revealTimer
        interval: 60
        onTriggered: {
            const r = shell.pendingReveal;
            shell.pendingReveal = null;
            if (r)
                Ui.invoke(page.item, "reveal", [r.section, r.entry]);
        }
    }
}
