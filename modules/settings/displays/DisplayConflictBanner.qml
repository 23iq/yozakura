import QtQuick
import qs.modules.services
import qs.modules.settings

// Monitor rules found in the user's own compositor config: they would fight
// the layout saved here. One click comments them out and imports what they said.
DisplayNotice {
    id: root

    property int count: 0
    signal moveRequested

    tone: "warning"
    icon: "warning"
    title: I18n.tn("prefs.displays.conflicts.title", root.count)
    message: I18n.t("prefs.displays.conflicts.desc")

    PillButton {
        objectName: "moveConflictsButton"
        kind: "filled"
        icon: "arrowsOut"
        text: I18n.t("prefs.displays.conflicts.move")
        onClicked: root.moveRequested()
    }
}
