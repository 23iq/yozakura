pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import "../../../components/kit/KitStates.js" as KitStates

// Row 0 of the emoji list while not searching: the "Recent" section label
// (its "Clear" action asks once more), a horizontal strip of recent emoji
// cells in the kit's hover / selected look (Left/Right move the cursor,
// Shift+wheel scrolls), then the label of the emoji rows below.
Item {
    id: strip

    required property var tab
    required property int rowIndex
    readonly property bool current: strip.tab.selectedIndex === strip.rowIndex
    readonly property int cellWidth: Space.rowHeight + Space.xs

    height: Space.xl * 2 + Space.rowHeight

    SectionLabel {
        x: Space.s
        width: parent.width - Space.s * 2
        height: Space.xl
        text: I18n.t("emoji.recent")
        action: strip.tab.clearButtonConfirmState ? I18n.t("emoji.clear_recent") : I18n.t("common.clear")
        onTriggered: {
            if (strip.tab.clearButtonConfirmState)
                strip.tab.clearRecentEmojis();
            else
                strip.tab.clearButtonConfirmState = true;
        }
    }

    ListView {
        id: cells
        // Glyphs centred over the row glyphs below
        x: Math.round(Space.s + Metrics.iconSize / 2 - strip.cellWidth / 2)
        y: Space.xl
        width: parent.width - x
        height: Space.rowHeight
        orientation: ListView.Horizontal
        model: strip.tab.recentModel
        currentIndex: strip.current ? strip.tab.selectedRecentIndex : -1
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        highlightFollowsCurrentItem: false

        Behavior on contentX {
            enabled: Config.animDuration > 0 && !cells.moving
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Motion.morph.easing
            }
        }

        onCurrentIndexChanged: {
            if (currentIndex < 0)
                return;
            const x = currentIndex * strip.cellWidth;
            if (x < contentX)
                contentX = x;
            else if (x + strip.cellWidth > contentX + width)
                contentX = x + strip.cellWidth - width;
        }

        // Shift+wheel scrolls the strip
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                if (!(wheel.modifiers & Qt.ShiftModifier)) {
                    wheel.accepted = false;
                    return;
                }
                cells.contentX = Math.max(0, Math.min(cells.contentWidth - cells.width, cells.contentX - (wheel.angleDelta.y || wheel.angleDelta.x)));
            }
        }

        delegate: Item {
            id: cell
            required property var emojiData
            required property int index
            readonly property string look: KitStates.look(false, strip.current && strip.tab.selectedRecentIndex === cell.index, hover.containsMouse)

            width: strip.cellWidth
            height: cells.height

            StyledRect {
                anchors.fill: parent
                anchors.margins: Space.xs / 2
                variant: KitStates.variant(cell.look, "transparent")
                backgroundOpacity: KitStates.opacity(cell.look, hover.containsMouse)
                enableBorder: false
                radius: Look.chipRadius(height)
            }

            Text {
                anchors.centerIn: parent
                text: cell.emojiData.emoji
                font.pixelSize: Math.round(Space.rowHeight / 2)
                color: Type.text
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                    strip.tab.selectedIndex = strip.rowIndex;
                    strip.tab.selectedRecentIndex = cell.index;
                }
                onClicked: strip.tab.copyEmoji(cell.emojiData)
            }
        }
    }

    SectionLabel {
        x: Space.s
        y: Space.xl + Space.rowHeight
        width: parent.width - Space.s * 2
        height: Space.xl
        text: I18n.t("emoji.all")
    }
}
