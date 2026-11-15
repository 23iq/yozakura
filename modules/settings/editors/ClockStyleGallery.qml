pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.settings.controls
import qs.modules.settings.previews
import qs.modules.settings.store
import "../../desktop/clockstyles/ClockStyleRegistry.js" as ClockStyles
import "../controls/PictureGrid.js" as PictureGrid
import qs.modules.components.kit

// Depth clock style picker: every registered style (ClockStyleRegistry.js)
// rendered live on the current wallpaper with its subject cutout and the
// chosen ink. In a card of the page row (`fillHeight`) it is one strip of
// pictures, the title inside each, scrolling sideways when they do not fit.
Item {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property bool strip: root.fillHeight > 0
    readonly property string current: ClockStyles.get(SettingsStore.get("desktop.depthClockStyle")).id
    readonly property string ink: SettingsStore.get("desktop.depthClockInk") ?? "auto"
    readonly property int count: ClockStyles.styles.length
    readonly property int columns: root.strip ? root.count : PictureGrid.columns(width, Space.m, root.count, Space.px(132))
    readonly property real cardWidth: root.strip ? Math.max(Space.px(120), Math.min(root.fillHeight * 16 / 9, (root.width - Space.m * (root.count + 1)) / Math.max(1, root.count))) : PictureGrid.cardWidth(grid.width, grid.spacing, root.columns, Space.px(190))

    implicitHeight: root.strip ? root.fillHeight : grid.implicitHeight

    Flickable {
        id: flick
        objectName: "pictureStrip"
        width: parent.width
        height: root.strip ? root.fillHeight : grid.height
        contentWidth: grid.width + (root.strip ? Space.m * 2 : 0)
        interactive: root.strip && contentWidth > width
        clip: root.strip
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        Grid {
            id: grid
            x: root.strip ? Space.m : 0
            y: root.strip ? Space.s : 0
            width: root.strip ? implicitWidth : flick.width
            columns: root.columns
            spacing: Space.m

            Repeater {
                model: ClockStyles.styles

                delegate: ChoiceCard {
                    id: card
                    required property var modelData
                    objectName: "clockStyle:" + modelData.id
                    width: root.cardWidth
                    previewHeight: root.strip ? root.fillHeight - Space.s * 2 : Math.round((width - 16) * 9 / 16)
                    inset: root.strip
                    selected: root.current === modelData.id
                    title: I18n.t(modelData.labelKey)
                    icon: modelData.icon
                    onClicked: SettingsStore.set("desktop.depthClockStyle", modelData.id)

                    ClockStyleScene {
                        anchors.fill: parent
                        styleId: card.modelData.id
                        inkRole: root.ink
                    }
                }
            }
        }
    }
    StripFade {
        flick: flick
        visible: root.strip
    }
}
