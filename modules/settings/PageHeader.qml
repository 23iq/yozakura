import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Page header: the title (title role) over a secondary description, and a
// quiet "Reset page" text action (schema categories) while anything differs
// from the defaults. Children (a hand-written page's actions) follow on the
// right; `description` overrides the category's.
RowLayout {
    id: header

    required property var category
    property string description: category && category.description ? I18n.t(category.description) : ""
    readonly property int modifiedCount: category && category.sections ? SettingsStore.modifiedCount(category) : 0

    spacing: Space.l

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Space.xs

        KitText {
            Layout.fillWidth: true
            role: "title"
            text: I18n.t(header.category.title)
        }
        KitText {
            Layout.fillWidth: true
            role: "secondary"
            text: header.description
            visible: text !== ""
            wrapMode: Text.WordWrap
        }
    }

    SectionLabel {
        objectName: "pageReset"
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: Space.xs
        visible: header.modifiedCount > 0
        action: I18n.t("prefs.common.reset_page")
        onTriggered: SettingsStore.resetCategory(header.category)
    }
}
