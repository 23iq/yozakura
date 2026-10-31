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
import "Ui.js" as Ui

// Settings window content: sidebar (groups, search) + the current page
// (SettingsPageHost: a fresh, asynchronously built page per category).
Item {
    id: shell

    property string currentCategory: ""
    readonly property bool compact: width < 860
    // Compact: the icon rail has no search field. Ctrl+F or the rail's search
    // button slides the full sidebar over the page until a pick or Escape.
    property bool searchOpen: false
    readonly property bool railed: compact && !searchOpen
    readonly property real railWidth: 76
    function openSearch() {
        if (compact)
            searchOpen = true;
        Qt.callLater(sidebar.focusSearch);
    }
    property var pendingReveal: null

    // Accepts a category id or a sidebar group id (Categories.resolve).
    // The page is rebuilt here, after the category is known: a handler on
    // currentCategory would run before the bindings that follow it and
    // build the old page once more.
    function select(id) {
        const c = Categories.resolve(id);
        if (!c)
            return;
        const changed = c.id !== currentCategory || !page.category;
        currentCategory = c.id;
        searchOpen = false;
        GlobalStates.settingsCategory = c.id;
        if (changed)
            page.load(c);
    }

    function navigate(categoryId, sectionId, entryId) {
        pendingReveal = {
            "section": sectionId || "",
            "entry": entryId || ""
        };
        const c = Categories.resolve(categoryId);
        if (c && c.id === currentCategory && page.status === Loader.Ready)
            revealTimer.restart();
        else
            select(categoryId);
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
            if (GlobalStates.settingsCategory && GlobalStates.settingsCategory !== shell.currentCategory)
                shell.select(GlobalStates.settingsCategory);
        }
    }

    Component.onCompleted: {
        // A preset trial or edit outlives the window: bring back its pill/banner.
        PresetStudio.refreshSessions();
        select(Categories.resolve(GlobalStates.settingsCategory) ? GlobalStates.settingsCategory : "appearance");
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
        sequences: [StandardKey.Cancel]
        enabled: shell.searchOpen
        onActivated: shell.searchOpen = false
    }
    Shortcut {
        sequences: [StandardKey.Save]
        enabled: SettingsStore.hasChanges
        onActivated: SettingsStore.apply()
    }
    Shortcut {
        sequences: ["Ctrl+PgDown", "Ctrl+Tab"]
        onActivated: shell.step(1)
    }
    Shortcut {
        sequences: ["Ctrl+PgUp", "Ctrl+Shift+Tab"]
        onActivated: shell.step(-1)
    }

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

    // Sidebar plane: the language's group fill (ink: none), and a hairline
    // against the page.
    Rectangle {
        id: sidebarBg
        z: shell.searchOpen ? 5 : 0
        width: sidebar.width
        height: parent.height
        color: Look.groupFill

        Divider {
            anchors.right: parent.right
            vertical: true
            height: parent.height
        }
    }

    SettingsSidebar {
        id: sidebar
        z: shell.searchOpen ? 6 : 0
        width: shell.railed ? shell.railWidth : 264
        height: parent.height
        compact: shell.railed
        currentCategory: shell.currentCategory
        onCategorySelected: id => shell.select(id)
        onResultActivated: r => {
            shell.searchOpen = false;
            shell.navigate(r.categoryId, r.sectionId, r.entryId);
        }

        Behavior on width {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.morph.duration
                easing.type: Motion.morph.easing
            }
        }
    }

    // The rail's search button (the field itself needs the wide sidebar).
    IconButton {
        objectName: "railSearch"
        visible: shell.railed
        size: "s"
        icon: Icons.magnifyingGlass
        x: (shell.railWidth - width) / 2
        y: sidebar.height - height - Space.l
        onClicked: shell.openSearch()
    }

    Item {
        id: content
        anchors.left: parent.left
        anchors.leftMargin: shell.compact ? shell.railWidth : sidebar.width
        anchors.right: parent.right
        height: parent.height
        clip: true

        // Click outside the opened search sidebar closes it.
        MouseArea {
            anchors.fill: parent
            z: 4
            enabled: shell.searchOpen
            visible: shell.searchOpen
            onClicked: shell.searchOpen = false
        }

        PresetEditBanner {
            id: editBanner
            width: parent.width
            z: 2
        }

        SettingsPageHost {
            id: page
            objectName: "settingsPage"
            y: editBanner.height
            width: parent.width
            height: parent.height - editBanner.height
            onLoaded: {
                if (shell.pendingReveal)
                    revealTimer.restart();
            }
        }

        ChangesBar {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 22
        }

        PresetTrialPill {
            anchors.horizontalCenter: parent.horizontalCenter
            y: editBanner.height + 16
            z: 3
        }

        PresetToast {
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 22
            z: 3
        }
    }

    // Closing the window with unsaved staged changes asks first
    // (SettingsWindow keeps the window and raises settingsCloseConfirm).
    ConfirmSheet {
        id: closeConfirm
        anchors.fill: parent
        open: GlobalStates.settingsCloseConfirm && SettingsStore.hasChanges
        title: I18n.t("prefs.close.title")
        body: I18n.t("prefs.close.body")
        actions: [
            {
                "id": "keep",
                "text": I18n.t("prefs.close.keep"),
                "kind": "ghost"
            },
            {
                "id": "discard",
                "text": I18n.t("prefs.changes.discard"),
                "kind": "tonal"
            },
            {
                "id": "apply",
                "text": I18n.t("prefs.changes.apply"),
                "kind": "filled"
            }
        ]
        onDismissed: GlobalStates.settingsCloseConfirm = false
        onChosen: id => {
            GlobalStates.settingsCloseConfirm = false;
            if (id === "keep")
                return;
            if (id === "apply")
                SettingsStore.apply();
            else
                SettingsStore.discard();
            GlobalStates.settingsWindowVisible = false;
        }
    }

    // Reset page / section over settings that save at once (no Apply /
    // Discard covers them): ask before applying the defaults.
    ConfirmSheet {
        anchors.fill: parent
        open: SettingsStore.pendingReset !== null
        title: I18n.t("prefs.reset.title")
        body: I18n.t("prefs.reset.body", SettingsStore.pendingResetCount)
        actions: [
            {
                "id": "cancel",
                "text": I18n.t("common.cancel"),
                "kind": "ghost"
            },
            {
                "id": "reset",
                "text": I18n.t("prefs.common.reset"),
                "kind": "filled"
            }
        ]
        onDismissed: SettingsStore.cancelReset()
        onChosen: id => id === "reset" ? SettingsStore.confirmReset() : SettingsStore.cancelReset()
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
