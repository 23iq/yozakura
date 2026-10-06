pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.settings

// The routine of a "Run routine" bind: one chip per saved routine
// (RoutinesService); with none yet, a link to the Routines page.
Column {
    id: root

    property string routineId: ""
    signal picked(string id)

    readonly property var routines: RoutinesService.routines || []
    readonly property bool missing: routineId !== "" && !routines.some(r => r.id === routineId)

    spacing: 6

    Flow {
        width: parent.width
        spacing: 6
        visible: root.routines.length > 0

        Repeater {
            model: root.routines
            delegate: ChipToggle {
                required property var modelData
                objectName: "routineChip:" + modelData.id
                text: modelData.name
                checked: modelData.id === root.routineId
                onToggled: v => {
                    if (v)
                        root.picked(modelData.id);
                }
            }
        }
    }

    Text {
        width: parent.width
        visible: root.missing || root.routines.length === 0
        text: root.missing ? I18n.t("routines.bind_missing", root.routineId) : I18n.t("routines.bind_empty")
        wrapMode: Text.WordWrap
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        color: root.missing ? Colors.error : Colors.overSurfaceVariant
    }

    PillButton {
        visible: root.routines.length === 0
        kind: "ghost"
        icon: "lightning"
        text: I18n.t("routines.open_page")
        onClicked: GlobalStates.settingsCategory = "routines"
    }
}
