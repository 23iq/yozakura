pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.config
import "../BarModules.js" as BarModules
import "../Ui.js" as Ui

// Faithful schematic of the bar for a layout: classic (one continuous bar)
// or islands (floating groups beside the notch), drawn with the live bar
// variants, roundness and module icons. Horizontal only; `unit` is the
// module height.
Item {
    id: root

    property string style: "classic"
    property var leftIds: []
    property var rightIds: []
    property var drawerIds: []
    property real unit: 22
    property bool showNotch: true
    property bool highlightDrawer: false
    // Style cards: keep the bar/island background visible even when the
    // theme's bar background is transparent, so the two styles differ.
    property bool illustrative: false
    readonly property real bgOpacity: illustrative ? Math.max(Config.theme.srBarBg.opacity ?? 1, 0.9) : -1

    readonly property bool islands: style === "islands"
    readonly property real barHeight: unit + 10

    implicitHeight: barHeight
    implicitWidth: 520

    // Classic: one bar across
    StyledRect {
        anchors.fill: parent
        visible: !root.islands
        variant: "barbg"
        backgroundOpacity: root.bgOpacity
        radius: Math.min(Styling.radius(0), height / 2)
        enableShadow: false
    }

    // Notch
    Rectangle {
        visible: root.showNotch
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.islands ? 0 : 3
        width: Math.min(parent.width * 0.2, 140)
        height: root.islands ? root.barHeight : root.barHeight - 6
        radius: Math.min(Styling.radius(0), height / 2)
        color: Colors.surfaceContainerLowest
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.7)
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.38
            height: 4
            radius: 2
            color: Ui.alpha(Colors.overSurfaceVariant, 0.4)
        }
    }

    Group {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        ids: root.leftIds
    }

    Group {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        ids: root.rightIds
        drawerCount: root.drawerIds.length
    }

    component Group: Item {
        id: group
        property var ids: []
        property int drawerCount: 0
        width: ids.length === 0 && drawerCount === 0 ? 0 : row.implicitWidth + (root.islands ? 10 : 10)
        height: root.barHeight
        visible: width > 0

        StyledRect {
            anchors.fill: parent
            visible: root.islands
            variant: "barbg"
            backgroundOpacity: root.bgOpacity
            radius: Math.min(Styling.radius(0), height / 2)
            enableShadow: false
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 3

            Item {
                visible: group.drawerCount > 0
                width: root.unit * 0.8
                height: root.unit
                Rectangle {
                    anchors.fill: parent
                    radius: Math.min(Styling.radius(-4), height / 2)
                    color: root.highlightDrawer ? Ui.alpha(Colors.primary, 0.25) : "transparent"
                    border.width: 1
                    border.color: Ui.alpha(Colors.outline, 0.7)
                }
                Text {
                    anchors.centerIn: parent
                    text: Icons.caretLeft
                    font.family: Icons.font
                    font.pixelSize: root.unit * 0.5
                    color: Colors.overSurfaceVariant
                }
            }

            Repeater {
                model: group.ids
                delegate: Glyph {
                    required property string modelData
                    moduleId: modelData
                }
            }
        }
    }

    component Glyph: Item {
        id: glyph
        property string moduleId
        width: moduleId === "workspaces" ? root.unit * 3.6 : (moduleId === "clock" ? clockText.implicitWidth + root.unit * 0.8 : root.unit * 1.15)
        height: root.unit

        StyledRect {
            anchors.fill: parent
            variant: "common"
            radius: Math.min(Styling.radius(-4), height / 2)
            enableShadow: false
        }

        Row {
            visible: glyph.moduleId === "workspaces"
            anchors.centerIn: parent
            spacing: root.unit * 0.18
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    width: index === 0 ? root.unit * 0.8 : root.unit * 0.3
                    height: root.unit * 0.3
                    radius: height / 2
                    color: index === 0 ? Colors.primary : Ui.alpha(Colors.overSurfaceVariant, index < 3 ? 0.7 : 0.35)
                }
            }
        }

        Text {
            id: clockText
            visible: glyph.moduleId === "clock"
            anchors.centerIn: parent
            text: "21:47"
            font.family: Styling.defaultFont
            font.pixelSize: root.unit * 0.5
            font.weight: Font.Bold
            color: Colors.overBackground
        }

        Text {
            visible: glyph.moduleId !== "workspaces" && glyph.moduleId !== "clock"
            anchors.centerIn: parent
            text: Icons[BarModules.info(glyph.moduleId).icon] ?? ""
            font.family: Icons.font
            font.pixelSize: root.unit * 0.55
            color: glyph.moduleId === "launcher" ? Colors.primary : Colors.overBackground
        }
    }
}
