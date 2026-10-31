import QtQuick
import QtQuick.Layouts
import qs.modules.components.kit
import qs.modules.services
import qs.modules.settings.store

// End of a page in the Simple view: how many expert rows it keeps out of
// sight and a quiet way to show them all (the sidebar toggle does the same).
RowLayout {
    id: root

    property int hidden: 0

    objectName: "simpleFooter"
    visible: root.hidden > 0
    spacing: Space.m

    KitText {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        role: "caption"
        color: Type.muted
        wrapMode: Text.WordWrap
        text: I18n.tn("prefs.view.more_hidden", root.hidden)
    }
    PillButton {
        objectName: "simpleShowAll"
        Layout.alignment: Qt.AlignVCenter
        kind: "ghost"
        icon: "eye"
        text: I18n.t("prefs.view.show_all")
        onClicked: SettingsStore.setShowAll(true)
    }
}
