import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.services
import qs.modules.settings.store

// Under a greyed row (enabledWhen false): why, in one line, and, when one
// switch decides it, a quiet [Turn on] / [Turn off] that flips it through
// SettingsStore (staged like any edit: Discard undoes it). The note stays
// at full strength while the row above it is dimmed.
RowLayout {
    id: root

    // {text, fix: {key, value, on} | null} (SettingsStore.disabledNote)
    property var note: null

    objectName: "disabledNote"
    visible: root.note !== null
    spacing: Space.m

    Text {
        Layout.alignment: Qt.AlignVCenter
        text: Icons.info ?? ""
        font.family: Icons.font
        font.pixelSize: Type.iconSize("caption")
        color: Type.secondary
    }
    KitText {
        objectName: "disabledReason"
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        role: "caption"
        color: Type.secondary
        text: root.note ? root.note.text : ""
        wrapMode: Text.WordWrap
    }
    PillButton {
        objectName: "disabledFix"
        Layout.alignment: Qt.AlignVCenter
        visible: !!(root.note && root.note.fix)
        kind: "ghost"
        text: root.note && root.note.fix ? I18n.t(root.note.fix.on ? "prefs.disabled.turn_on" : "prefs.disabled.turn_off") : ""
        onClicked: SettingsStore.set(root.note.fix.key, root.note.fix.value)
    }
}
