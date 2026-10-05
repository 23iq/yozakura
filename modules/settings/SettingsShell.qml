pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.config
import qs.modules.settings.store
import qs.modules.settings.presets
import "schema/Categories.js" as Categories
import "Ui.js" as Ui

// Settings window content: sidebar (groups, search) + the current page.
// Pages come from the category kind (see schema/Categories.js): schema
// categories render through SettingsPage, legacy ones through
// LegacyPanelHost, the rest are hand-written pages.
Item {
    id: shell

    // Legacy GlobalStates.settingsCurrentTab values (old SettingsTab order),
    // still written by e.g. the microphone activity to open the mixer.
    readonly property var legacyTabs: ["network", "bluetooth", "sound", "ai", "effects", "appearance", "input", "system", "windows", "bar", "mods"]

    property string currentCategory: GlobalStates.settingsCategory || "appearance"
    readonly property var category: Categories.byId(currentCategory) || Categories.byId("appearance")
    readonly property bool compact: width < 860
    property var pendingReveal: null

    function select(id) {
        if (!Categories.byId(id))
            return;
        currentCategory = id;
        GlobalStates.settingsCategory = id;
    }

    function navigate(categoryId, sectionId, entryId) {
        pendingReveal = {
            "section": sectionId || "",
            "entry": entryId || ""
        };
        if (categoryId === currentCategory)
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

    function consumeLegacyTab() {
        const tab = GlobalStates.settingsCurrentTab;
        if (tab > 0 && tab < legacyTabs.length) {
            select(legacyTabs[tab]);
            GlobalStates.settingsCurrentTab = 0;
        }
    }

    Component.onCompleted: {
        consumeLegacyTab();
        // A preset trial or edit outlives the window: bring back its pill/banner.
        PresetStudio.refreshSessions();
    }

    // Fresh page per category: resets scroll and replays the enter motion.
    onCurrentCategoryChanged: {
        page.active = false;
        page.active = true;
    }

    Connections {
        target: GlobalStates
        function onSettingsCurrentTabChanged() {
            shell.consumeLegacyTab();
        }
    }
    Connections {
        target: SettingsStore
        function onNavigateRequested(categoryId, sectionId, entryId) {
            shell.navigate(categoryId, sectionId, entryId);
        }
    }

    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: sidebar.focusSearch()
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

    StyledRect {
        anchors.fill: parent
        variant: "bg"
        glassSurface: "settings"
        radius: 0
        enableBorder: false
    }

    // Sidebar backdrop: a slightly lifted plane.
    Rectangle {
        id: sidebarBg
        width: sidebar.width
        height: parent.height
        color: Ui.alpha(Colors.surfaceContainerLow, 0.55)

        Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            color: Ui.alpha(Colors.outlineVariant, 0.5)
        }
    }

    SettingsSidebar {
        id: sidebar
        width: shell.compact ? 76 : 264
        height: parent.height
        compact: shell.compact
        currentCategory: shell.currentCategory
        onCategorySelected: id => shell.select(id)
        onResultActivated: r => shell.navigate(r.categoryId, r.sectionId, r.entryId)

        Behavior on width {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    Item {
        id: content
        anchors.left: sidebar.right
        anchors.right: parent.right
        height: parent.height
        clip: true

        PresetEditBanner {
            id: editBanner
            width: parent.width
            z: 2
        }

        Loader {
            id: page
            objectName: "settingsPage"
            y: editBanner.height
            width: parent.width
            height: parent.height - editBanner.height
            sourceComponent: shell.category.sections ? schemaPage : (shell.category.legacy ? legacyPage : (shell.pages[shell.category.page] ?? placeholderPage))
            property real slide: 0

            opacity: 1 - slide
            transform: Translate {
                y: page.slide * 18
            }

            onLoaded: {
                enter.restart();
                if (shell.pendingReveal)
                    revealTimer.restart();
            }

            NumberAnimation {
                id: enter
                target: page
                property: "slide"
                from: 1
                to: 0
                duration: Math.max(1, Config.animDuration)
                easing.type: Easing.OutCubic
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

    Component {
        id: schemaPage
        SettingsPage {
            category: shell.category
        }
    }
    Component {
        id: legacyPage
        LegacyPanelHost {
            category: shell.category
        }
    }
    Component {
        id: aboutPage
        AboutPage {
            category: shell.category
        }
    }
    Component {
        id: presetStudioPage
        PresetStudioPage {
            category: shell.category
        }
    }
    // Hand-written pages by Categories.js `page` name.
    readonly property var pages: ({
            "AboutPage": aboutPage,
            "PresetStudio": presetStudioPage
        })
    Component {
        id: placeholderPage
        PlaceholderPage {
            category: shell.category
        }
    }
}
