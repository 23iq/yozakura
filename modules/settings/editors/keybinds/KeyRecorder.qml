pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.keybinds
import qs.modules.settings
import qs.config
import "../../Ui.js" as Ui
import "../../../keybinds/KeyNames.js" as KeyNames
import "../../../keybinds/BindModel.js" as BindModel
import qs.modules.components.kit

// One key combo of a bind with a "record" mode: Record focuses a capture
// pad that takes the next combo pressed on the keyboard (held modifiers
// count, a lone Super press records Super), or a mouse button / the wheel
// with a modifier held. While recording, the compositor's own binds are held
// off so combos it already binds (Super+E, a lone Super) reach the pad too:
// Hyprland through an empty submap (KeybindsStore), every compositor through
// keyboard-shortcuts-inhibit on the Settings window (RecordInhibitor).
// A combo another bind (or the compositor) already uses is marked, but
// always saved: both binds are kept.
ColumnLayout {
    id: root

    property var combo: ({
            "modifiers": [],
            "key": ""
        })
    property string exceptUid: ""
    property bool removable: false
    property bool autoStart: false
    signal committed(var combo)
    signal removed

    property bool recording: false
    // the modifiers held down so far while recording
    property var heldMods: []
    property bool sawKey: false

    readonly property var draftMods: KeyNames.normalizeMods(heldMods)
    // the keys so far while recording, shared through KeybindsStore.recordingDraft
    readonly property var draft: recording ? ({
            "modifiers": draftMods,
            "key": ""
        }) : null
    onDraftChanged: KeybindsStore.recordingDraft = draft
    readonly property var clashRows: BindModel.rowsUsing(KeybindsStore.rows, combo.modifiers, combo.key, exceptUid)
    readonly property var clashNative: nativeUsing(combo.modifiers, combo.key)
    readonly property string clashText: clashList(clashRows, clashNative)

    function nativeUsing(mods, key) {
        const id = KeyNames.comboId(mods, key);
        return id ? KeybindsStore.nativeBinds.filter(n => n.combo === id) : [];
    }

    function clashList(rows, native) {
        return rows.map(r => KeybindsStore.title(r)).concat(native.map(n => I18n.t("binds.conflict_native", n.text))).join(", ");
    }

    spacing: Space.s

    function start() {
        heldMods = [];
        sawKey = false;
        recording = true;
        pad.forceActiveFocus();
    }

    function cancel() {
        recording = false;
    }

    function commit(mods, key) {
        recording = false;
        if (key)
            committed({
                "modifiers": KeyNames.normalizeMods(mods),
                "key": key
            });
    }

    function holdMod(mod, on) {
        const rest = heldMods.filter(m => m !== mod);
        heldMods = on ? rest.concat([mod]) : rest;
    }

    Component.onCompleted: if (autoStart)
        Qt.callLater(start)

    onRecordingChanged: KeybindsStore.holdCompositorBinds(recording)
    Component.onDestruction: {
        if (recording) {
            KeybindsStore.holdCompositorBinds(false);
            KeybindsStore.recordingDraft = null;
        }
    }

    Connections {
        target: KeybindsStore
        function onRecordTimedOut() {
            root.recording = false;
        }
    }

    // Idle: the combo, Record, remove
    RowLayout {
        Layout.fillWidth: true
        visible: !root.recording
        spacing: Space.m

        KeyCombo {
            modifiers: root.combo.modifiers
            key: root.combo.key
            sizeOffset: 0
            tone: root.clashText !== "" ? "error" : "normal"
            placeholder: I18n.t("binds.not_set")
        }
        Item {
            Layout.fillWidth: true
        }
        PillButton {
            objectName: "keyRecord"
            icon: "record"
            text: I18n.t("binds.record")
            onClicked: root.start()
        }
        PillButton {
            visible: root.removable
            kind: "ghost"
            icon: "trash"
            text: ""
            implicitWidth: implicitHeight
            onClicked: root.removed()
            Accessible.name: I18n.t("binds.remove_key")
        }
    }

    KitText {
        objectName: "clashNote"
        role: "caption"
        Layout.fillWidth: true
        visible: !root.recording && root.clashText !== ""
        wrapMode: Text.Wrap
        text: I18n.t("binds.also_used_by", root.clashText) + ". " + I18n.t(KeybindsStore.compositor === "niri" ? "binds.conflict_first_wins" : "binds.conflict_kept")
        color: Colors.error
    }

    // Recording: capture pad
    Item {
        id: pad
        objectName: "keyCapture"
        Layout.fillWidth: true
        visible: root.recording
        implicitHeight: Math.round(Styling.fontSize(0) * 4.2)
        focus: root.recording

        // The settings window's own shortcuts (Ctrl+S, Ctrl+Tab, ...) must
        // not fire while a combo is being captured.
        Keys.onShortcutOverride: event => event.accepted = true

        Keys.onPressed: event => {
            event.accepted = true;
            const mod = KeyNames.qtModifierKey(event.key);
            if (mod) {
                root.holdMod(mod, true);
                return;
            }
            const held = KeyNames.modsFromQt(event.modifiers);
            if (event.key === Qt.Key_Escape && held.length === 0) {
                root.cancel();
                return;
            }
            const key = KeyNames.keyFromQt(event.key, event.text);
            if (!key)
                return;
            root.sawKey = true;
            root.commit(root.heldMods.concat(held), key);
        }
        Keys.onReleased: event => {
            event.accepted = true;
            const mod = KeyNames.qtModifierKey(event.key);
            if (!mod)
                return;
            // A lone Super press binds Super itself (like the launcher).
            if (mod === "SUPER" && !root.sawKey && root.draftMods.length === 1 && root.draftMods[0] === "SUPER")
                root.commit(["SUPER"], "Super_L");
            else
                root.holdMod(mod, false);
        }

        Rectangle {
            anchors.fill: parent
            radius: Look.radius("control")
            color: Ui.alpha(Colors.primary, 0.08)
            border.width: 2
            border.color: Colors.primary
            SequentialAnimation on border.color {
                running: root.recording && Config.animDuration > 0
                loops: Animation.Infinite
                ColorAnimation {
                    to: Ui.alpha(Colors.primary, 0.35)
                    duration: Motion.pan.duration
                }
                ColorAnimation {
                    to: Colors.primary
                    duration: Motion.pan.duration
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: mouse => {
                pad.forceActiveFocus();
                const held = KeyNames.modsFromQt(mouse.modifiers).concat(root.heldMods);
                const key = KeyNames.mouseKey(mouse.button);
                if (key && held.length > 0)
                    root.commit(held, key);
            }
            onWheel: wheel => {
                const held = KeyNames.modsFromQt(wheel.modifiers).concat(root.heldMods);
                if (held.length > 0)
                    root.commit(held, wheel.angleDelta.y > 0 ? "mouse_up" : "mouse_down");
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: Space.s

            KeyCombo {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.draftMods.length > 0
                modifiers: root.draftMods
                key: ""
                sizeOffset: 0
                tone: "accent"
            }
            KitText {
                role: "caption"
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.draftMods.length > 0 ? I18n.t("binds.record_hint_key") : I18n.t("binds.record_hint")
                color: Colors.overBackground
            }
        }
    }

    // Recording: the note and Cancel
    RowLayout {
        Layout.fillWidth: true
        visible: root.recording
        spacing: Space.m

        KitText {
            role: "caption"
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: KeybindsStore.compositor === "hyprland" ? I18n.t("binds.record_super_note") : I18n.t("binds.record_paused_note")
            color: Colors.overSurfaceVariant
        }
        PillButton {
            kind: "ghost"
            text: I18n.t("binds.cancel")
            onClicked: root.cancel()
        }
    }
}
