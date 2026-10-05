pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.config

// Secondary actions of an expanded result (Shift+Enter / right click):
// [{id, text, icon, variant}] with a highlight following `currentIndex`.
ClippingRectangle {
    id: opts

    property var options: []
    property int currentIndex: 0
    readonly property int rowHeight: 36

    signal hovered(int index)
    signal triggered(int index)

    implicitHeight: rowHeight * options.length
    color: Colors.background
    radius: Styling.radius(0)

    ListView {
        id: list
        anchors.fill: parent
        interactive: false
        model: opts.options
        currentIndex: opts.currentIndex
        highlightFollowsCurrentItem: true
        highlightMoveDuration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
        highlightMoveVelocity: -1

        highlight: StyledRect {
            variant: {
                const o = opts.options[list.currentIndex];
                return o && o.variant ? o.variant : "primary";
            }
            radius: Styling.radius(0)
            z: -1
        }

        delegate: Item {
            id: optionRow
            required property var modelData
            required property int index
            readonly property bool current: list.currentIndex === index
            readonly property color tint: current ? Styling.srItem(modelData.variant || "primary") : Colors.overSurface

            width: list.width
            height: opts.rowHeight

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Text {
                    text: optionRow.modelData.icon || ""
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: optionRow.tint
                }

                Text {
                    Layout.fillWidth: true
                    text: optionRow.modelData.text || ""
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    font.weight: optionRow.current ? Font.Bold : Font.Normal
                    color: optionRow.tint
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: opts.hovered(optionRow.index)
                onClicked: opts.triggered(optionRow.index)
            }
        }
    }
}
