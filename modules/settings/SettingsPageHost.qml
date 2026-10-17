pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.config
import qs.modules.settings.presets
import qs.modules.settings.displays
import qs.modules.settings.keyboard
import qs.modules.settings.extras
import qs.modules.settings.connect
import qs.modules.settings.mods
// Not used here: lets Quickshell's scanner reach these page directories.
import qs.modules.settings.layout
import qs.modules.settings.system

// The page of the settings window. `load()` always starts a fresh instance
// (scroll reset, enter motion). Schema categories render through
// SettingsPage (which adds its sections a few per frame), the rest are
// hand-written pages (Categories.js `page`).
// Pages are not kept alive hidden: a hidden page keeps its animations,
// previews and image loads running. Nor is the Loader asynchronous: Qt
// incubates nested Repeater delegates late, which breaks the editors that
// size themselves from Repeater.itemAt().
Loader {
    id: host

    property var category: null
    property real slide: 0

    function load(cat) {
        host.active = false;
        host.category = cat;
        host.active = cat !== null;
    }

    active: false
    sourceComponent: !category ? null : (category.sections ? schemaPage : (host.pages[category.page] ?? placeholderPage))

    opacity: 1 - slide
    transform: Translate {
        y: host.slide * 18
    }

    onLoaded: enterAnim.restart()

    NumberAnimation {
        id: enterAnim
        target: host
        property: "slide"
        from: 1
        to: 0
        duration: Math.max(1, Config.animDuration)
        easing.type: Motion.morph.easing
    }

    Component {
        id: schemaPage
        SettingsPage {
            category: host.category
        }
    }
    Component {
        id: modsPage
        ModsEditor {
            category: host.category
        }
    }
    // Connect pages: the live device controls of the dashboard.
    Component {
        id: networkPage
        ConnectPage {
            category: host.category
            panel: "WifiPanel.qml"
        }
    }
    Component {
        id: bluetoothPage
        ConnectPage {
            category: host.category
            panel: "BluetoothPanel.qml"
        }
    }
    Component {
        id: soundPage
        ConnectPage {
            category: host.category
            panel: "AudioMixerPanel.qml"
        }
    }
    Component {
        id: effectsPage
        ConnectPage {
            category: host.category
            panel: "EasyEffectsPanel.qml"
        }
    }
    Component {
        id: aboutPage
        AboutPage {
            category: host.category
        }
    }
    Component {
        id: presetStudioPage
        PresetStudioPage {
            category: host.category
        }
    }
    Component {
        id: displaysPage
        DisplaysPage {
            category: host.category
        }
    }
    Component {
        id: keyboardPage
        KeyboardPage {
            category: host.category
        }
    }
    Component {
        id: extrasPage
        ExtrasPage {
            category: host.category
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
            category: host.category
        }
    }
}
