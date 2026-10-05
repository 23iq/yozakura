import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.settings.store
import qs.config
import qs.modules.keybinds

// Full-screen keybind cheatsheet on one screen: a frosted scrim (the layer
// namespace gets the compositor blur) with the cheatsheet panel. Opens on
// the focused screen through Visibilities ("keybinds" module, `<app> run
// keybinds`); Esc, a click outside or "Edit" close it.
PanelWindow {
    id: root

    property bool open: false
    // Follows `open` one tick late so the opening animates too.
    property bool shown: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: Brand.namespace("keybinds")
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region {
        item: root.open ? scrim : emptyMask
    }

    Item {
        id: emptyMask
        width: 0
        height: 0
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            root.shown = Qt.binding(() => root.open);
            panel.focusSearch();
        });
        KeybindsStore.refreshNative();
    }

    function close() {
        if (Visibilities.currentActiveModule === "keybinds")
            Visibilities.setActiveModule("");
    }

    function edit(uid) {
        KeybindsStore.requestEdit(uid);
        const row = KeybindsStore.row(uid);
        GlobalStates.settingsCategory = "input";
        if (GlobalStates.settingsWindowVisible)
            SettingsStore.navigate("input", row ? row.group : "", "");
        else
            GlobalShortcuts.toggleSettings();
        close();
    }

    FocusGrab {
        windows: [root]
        active: root.open
        onCleared: Qt.callLater(() => root.close())
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.background
        opacity: root.shown ? 0.72 : 0
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    CheatsheetPanel {
        id: panel
        objectName: "cheatsheetPanel"
        anchors.fill: parent
        anchors.leftMargin: Math.max(32, (parent.width - 1600) / 2)
        anchors.rightMargin: anchors.leftMargin
        anchors.topMargin: Math.max(32, parent.height * 0.06)
        anchors.bottomMargin: anchors.topMargin
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.97
        transform: Translate {
            y: root.shown ? 0 : 18
            Behavior on y {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }
        onCloseRequested: root.close()
        onEditRequested: uid => root.edit(uid)
    }
}
