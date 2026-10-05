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

// One key combo of a bind with a "record" mode: a focused capture pad takes
// the next key press (held modifiers count, a lone Super press records
// Super), a mouse button or the wheel (with a modifier). The compositor
// keeps combos it already binds, so the modifier chips can be toggled by
// hand and the key typed by name (also for XF86 keys and switches).
// A combo another bind (or the compositor) already uses is marked, live
// while typing a key name too, but always saved: both binds are kept.
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
    property var chipMods: []
    property bool sawKey: false

    readonly property var draftMods: KeyNames.normalizeMods(chipMods)
    readonly property var clashRows: BindModel.rowsUsing(KeybindsStore.rows, combo.modifiers, combo.key, exceptUid)
    readonly property var clashNative: nativeUsing(combo.modifiers, combo.key)
    readonly property string clashText: clashList(clashRows, clashNative)
    // While recording: the modifiers held/toggled + the key name typed.
    readonly property string draftClashText: {
        const key = keyName.text.trim();
        if (!recording || !key)
            return "";
        return clashList(BindModel.rowsUsing(KeybindsStore.rows, draftMods, key, exceptUid), nativeUsing(draftMods, key));
    }

    function nativeUsing(mods, key) {
        const id = KeyNames.comboId(mods, key);
        return id ? KeybindsStore.nativeBinds.filter(n => n.combo === id) : [];
    }

    function clashList(rows, native) {
        return rows.map(r => KeybindsStore.title(r)).concat(native.map(n => I18n.t("binds.conflict_native", n.text))).join(", ");
    }

    spacing: 6

    function start() {
        chipMods = [];
        sawKey = false;
        keyName.text = "";
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

    function toggleMod(mod, on) {
        const rest = chipMods.filter(m => m !== mod);
        chipMods = on ? rest.concat([mod]) : rest;
    }

    Component.onCompleted: if (autoStart)
        Qt.callLater(start)

    // Idle: the combo, Record, remove
    RowLayout {
        Layout.fillWidth: true
        visible: !root.recording
        spacing: 10

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

    Text {
        objectName: "clashNote"
        Layout.fillWidth: true
        readonly property string list: root.recording ? root.draftClashText : root.clashText
        visible: list !== ""
        wrapMode: Text.Wrap
        text: I18n.t("binds.also_used_by", list) + ". " + I18n.t("binds.conflict_kept")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-3)
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

        Keys.onPressed: event => {
            event.accepted = true;
            const mod = KeyNames.qtModifierKey(event.key);
            if (mod) {
                root.toggleMod(mod, true);
                return;
            }
            const held = KeyNames.modsFromQt(event.modifiers);
            if (event.key === Qt.Key_Escape && held.length === 0 && root.chipMods.length === 0) {
                root.cancel();
                return;
            }
            const key = KeyNames.keyFromQt(event.key, event.text);
            if (!key)
                return;
            root.sawKey = true;
            root.commit(root.chipMods.concat(held), key);
        }
        Keys.onReleased: event => {
            event.accepted = true;
            // A lone Super press binds Super itself (like the launcher).
            if (KeyNames.qtModifierKey(event.key) === "SUPER" && !root.sawKey && root.draftMods.length === 1)
                root.commit(["SUPER"], "Super_L");
        }

        Rectangle {
            anchors.fill: parent
            radius: Styling.radius(-2)
            color: Ui.alpha(Colors.primary, 0.08)
            border.width: 2
            border.color: Colors.primary
            SequentialAnimation on border.color {
                running: root.recording && Config.animDuration > 0
                loops: Animation.Infinite
                ColorAnimation {
                    to: Ui.alpha(Colors.primary, 0.35)
                    duration: 700
                }
                ColorAnimation {
                    to: Colors.primary
                    duration: 700
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: mouse => {
                pad.forceActiveFocus();
                const held = KeyNames.modsFromQt(mouse.modifiers).concat(root.chipMods);
                const key = KeyNames.mouseKey(mouse.button);
                if (key && held.length > 0)
                    root.commit(held, key);
            }
            onWheel: wheel => {
                const held = KeyNames.modsFromQt(wheel.modifiers).concat(root.chipMods);
                if (held.length > 0)
                    root.commit(held, wheel.angleDelta.y > 0 ? "mouse_up" : "mouse_down");
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 6

            KeyCombo {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.draftMods.length > 0
                modifiers: root.draftMods
                key: ""
                sizeOffset: 0
                tone: "accent"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.draftMods.length > 0 ? I18n.t("binds.record_hint_key") : I18n.t("binds.record_hint")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overBackground
            }
        }
    }

    // Recording: modifier chips, key by name, cancel
    Flow {
        Layout.fillWidth: true
        visible: root.recording
        spacing: 6

        Repeater {
            model: KeyNames.MOD_ORDER
            delegate: ChipToggle {
                required property string modelData
                text: KeyNames.modcap(modelData).kind === "super" ? I18n.t("binds.mod_super") : KeyNames.modcap(modelData).text
                checked: root.draftMods.indexOf(modelData) !== -1
                onToggled: v => {
                    root.toggleMod(modelData, v);
                    pad.forceActiveFocus();
                }
            }
        }

        Item {
            width: 160
            height: 30
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Ui.alpha(Colors.overBackground, 0.06)
                border.width: keyName.activeFocus ? 2 : 1
                border.color: keyName.activeFocus ? Colors.primary : Ui.alpha(Colors.outline, 0.35)
            }
            TextInput {
                id: keyName
                objectName: "keyName"
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overBackground
                onAccepted: root.commit(root.chipMods, text.trim())
                Keys.onEscapePressed: root.cancel()
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.text === ""
                    text: I18n.t("binds.key_placeholder")
                    font: parent.font
                    color: Colors.outline
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }

        PillButton {
            kind: "ghost"
            text: I18n.t("binds.cancel")
            onClicked: root.cancel()
        }
    }

    Text {
        Layout.fillWidth: true
        visible: root.recording
        wrapMode: Text.Wrap
        text: I18n.t("binds.record_super_note")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-3)
        color: Colors.overSurfaceVariant
    }
}
