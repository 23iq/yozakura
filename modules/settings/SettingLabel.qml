import QtQuick
import QtQuick.Layouts
import qs.modules.components.kit
import qs.modules.services

// The left side of a SettingRow: label (body), description (caption) and,
// for a host / style picker while the notch is off, the option it shows as.
ColumnLayout {
    id: root

    required property var entry
    property string shownAs: ""

    spacing: Space.xs / 2

    Item {
        Layout.fillHeight: true
    }
    KitText {
        Layout.fillWidth: true
        role: "body"
        text: I18n.t(root.entry.label)
        wrapMode: Text.WordWrap
    }
    KitText {
        Layout.fillWidth: true
        visible: !!root.entry.description
        role: "caption"
        text: root.entry.description ? I18n.t(root.entry.description) : ""
        wrapMode: Text.WordWrap
    }
    KitText {
        objectName: "rowShownAs"
        Layout.fillWidth: true
        visible: root.shownAs !== ""
        role: "caption"
        text: root.shownAs !== "" ? I18n.t("prefs.layout.island_off").arg(root.shownAs) : ""
        wrapMode: Text.WordWrap
    }
    Item {
        Layout.fillHeight: true
    }
}
