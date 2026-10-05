pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.bar.workspaces
import "../workspaces/WorkspaceNumerals.js" as Numerals

// Text workspaces, tmux/i3 style: [1][2][3]. The active one is highlighted,
// empty ones dimmed. moduleOptions.workspaceTags.brackets toggles the [].
// Numbers follow workspaces.numeralStyle (kanji, roman...).
BarModuleBase {
    id: root

    moduleKey: "workspaceTags"

    readonly property var monitor: bar ? YozdService.monitorFor(bar.screen) : null
    readonly property int activeId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
    readonly property int shown: Config.workspaces && Config.workspaces.shown ? Config.workspaces.shown : 10
    readonly property int group: Math.floor((activeId - 1) / shown)
    readonly property bool brackets: options.brackets !== false
    readonly property string numeralStyle: Config.workspaces && Config.workspaces.numeralStyle ? Config.workspaces.numeralStyle : "arabic"
    readonly property var occupied: CompositorData.workspaceOccupationMap
    // Only as many tags as needed: every occupied one plus the active one
    readonly property var ids: {
        const out = [];
        for (let i = 1; i <= shown; i++) {
            const id = group * shown + i;
            if (occupied[id] || id === activeId)
                out.push(id);
        }
        return out;
    }

    contentLength: vertical ? column.implicitHeight + 12 : row.implicitWidth + (flat ? 8 : 20)

    BarModuleSurface {
        module: root
    }

    Row {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: root.brackets ? 2 : 6
        Repeater {
            model: root.ids
            delegate: Tag {}
        }
    }

    Column {
        id: column
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: root.ids
            delegate: Tag {}
        }
    }

    component Tag: Rectangle {
        id: tag
        required property int modelData
        readonly property bool active: modelData === root.activeId

        implicitWidth: label.implicitWidth + (root.brackets ? 6 : 12)
        implicitHeight: Math.round(root.moduleSize * 0.74)
        radius: root.brackets ? 2 : height / 2
        color: active ? Colors.primary : "transparent"

        Text {
            id: label
            objectName: "workspaceTagLabel"
            readonly property string numeral: Numerals.format(root.numeralStyle, tag.modelData)
            anchors.centerIn: parent
            text: root.brackets ? "[" + numeral + "]" : numeral
            font.family: root.numeralStyle === "arabic" ? Config.theme.font : NumeralFonts.family(numeral)
            font.pixelSize: root.textSize
            font.weight: tag.active ? Font.Bold : Font.Normal
            color: tag.active ? Colors.overPrimary : Colors.overBackground
            opacity: tag.active || root.occupied[tag.modelData] ? 1 : 0.5
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: YozdService.dispatch(`workspace ${tag.modelData}`)
        }
    }
}
