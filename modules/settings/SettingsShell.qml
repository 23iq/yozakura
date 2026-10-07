pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.globals
import qs.config
import qs.modules.settings.store
import qs.modules.settings.presets
import qs.modules.settings.displays
import qs.modules.settings.layout
import qs.modules.settings.keyboard
import qs.modules.settings.system
import qs.modules.settings.extras
import qs.modules.settings.connect
import qs.modules.settings.mods
import "schema/Categories.js" as Categories
import "Ui.js" as Ui

// Settings window content: sidebar (groups, search) + the current page.
// Pages come from the category kind (see schema/Categories.js): schema
// categories render through SettingsPage, the rest are hand-written pages.
Item {
    id: shell

    property string currentCategory: GlobalStates.settingsCategory || "appearance"
    readonly property var category: Categories.resolve(currentCategory) || Categories.byId("appearance")
    readonly property bool compact: width < 860
    property var pendingReveal: null

    // Accepts a category id or a sidebar group id (Categories.resolve).
    function select(id) {
        const c = Categories.resolve(id);
        if (!c)
            return;
        currentCategory = c.id;
        GlobalStates.settingsCategory = c.id;
    }

    function navigate(categoryId, sectionId, entryId) {
        pendingReveal = {
            "section": sectionId || "",
            "entry": entryId || ""
        };
        const c = Categories.resolve(categoryId);
        if (c && c.id === currentCategory)
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
    }

    // Fresh page per category: resets scroll and replays the enter motion.
    onCurrentCategoryChanged: {
        page.active = false;
        page.active = true;
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

    // Sidebar plane: the language's group fill (ink: none), and a hairline
    // against the page.
    Rectangle {
        id: sidebarBg
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
                easing.type: Motion.morph.easing
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
            sourceComponent: shell.category.sections ? schemaPage : (shell.pages[shell.category.page] ?? placeholderPage)
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
                easing.type: Motion.morph.easing
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
        id: modsPage
        ModsEditor {
            category: shell.category
        }
    }
    // Connect pages: the live device controls of the dashboard.
    Component {
        id: networkPage
        ConnectPage {
            category: shell.category
            panel: "WifiPanel.qml"
        }
    }
    Component {
        id: bluetoothPage
        ConnectPage {
            category: shell.category
            panel: "BluetoothPanel.qml"
        }
    }
    Component {
        id: soundPage
        ConnectPage {
            category: shell.category
            panel: "AudioMixerPanel.qml"
        }
    }
    Component {
        id: effectsPage
        ConnectPage {
            category: shell.category
            panel: "EasyEffectsPanel.qml"
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
    Component {
        id: displaysPage
        DisplaysPage {
            category: shell.category
        }
    }
    Component {
        id: keyboardPage
        KeyboardPage {
            category: shell.category
        }
    }
    Component {
        id: extrasPage
        ExtrasPage {
            category: shell.category
        }
    }
    // Hand-written pages by Categories.js `page` name.
    readonly property var pages: ({
            "AboutPage": aboutPage,
            "Bluetooth": bluetoothPage,
            "Displays": displaysPage,
            "Effects": effectsPage,
            "Extras": extrasPage,
            "Keyboard": keyboardPage,
            "Mods": modsPage,
            "Network": networkPage,
            "PresetStudio": presetStudioPage,
            "Sound": soundPage
        })
    Component {
        id: placeholderPage
        PlaceholderPage {
            category: shell.category
        }
    }
}
