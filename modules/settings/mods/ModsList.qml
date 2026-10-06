pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import qs.modules.settings
import "ModsModel.js" as ModsModel

// Installed mods: count, search, sort and the rows. In the load-order view
// (no search) a row's handle drags it to a new position; the drop slot is
// derived from where the floating preview sits, because the DragHandler has
// already let go when it reports the release.
ModsCard {
    id: list

    property string selectedId: ""
    property string searchQuery: ""
    property string sortMode: "name"
    signal selectRequested(string id)
    signal toggleRequested(var mod)

    property string draggingId: ""
    property int dropIndex: -1

    readonly property var allMods: ModsService.mods ?? []
    readonly property var mods: ModsModel.filterMods(allMods, searchQuery, sortMode)
    readonly property bool reorderable: ModsModel.canReorder(sortMode, searchQuery)

    function beginDrag(row) {
        const point = row.mapToItem(listArea, 0, 0);
        dragPreview.label = row.mod.name ?? row.mod.id;
        dragPreview.x = point.x;
        dragPreview.y = point.y;
        dragPreview.height = row.height;
        list.draggingId = row.mod.id;
        list.dropIndex = row.index;
    }

    function endDrag(row) {
        const landing = list.dropIndex;
        list.draggingId = "";
        list.dropIndex = -1;
        if (landing >= 0 && landing !== row.index)
            ModsService.moveTo(row.mod.id, landing);
    }

    title: I18n.t("mods.installed_count", String(allMods.length))
    trailing: [
        SearchInput {
            width: Metrics.menuW + 60
            visible: list.allMods.length > 0
            placeholderText: I18n.t("mods.search")
            clearOnEscape: true
            onSearchTextChanged: text => list.searchQuery = text
        },
        PillButton {
            visible: list.allMods.length > 0
            kind: "ghost"
            text: I18n.t(ModsModel.sortLabelKey(list.sortMode))
            onClicked: list.sortMode = ModsModel.nextSort(list.sortMode)
        }
    ]

    // Empty / no matches
    ColumnLayout {
        width: parent.width
        visible: ModsService.loaded && list.mods.length === 0
        spacing: Metrics.spacing + 2

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Metrics.spacing
            text: Icons.puzzlePiece
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(12)
            color: Colors.outline
        }

        Text {
            Layout.fillWidth: true
            Layout.bottomMargin: Metrics.spacing
            text: list.allMods.length === 0 ? I18n.t("mods.empty") : I18n.t("mods.no_matches")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }

    Item {
        id: listArea
        visible: list.mods.length > 0
        width: parent.width
        height: rows.implicitHeight

        Column {
            id: rows
            width: parent.width
            spacing: 4

            Repeater {
                model: list.mods

                delegate: ModsListRow {
                    id: row
                    required property var modelData
                    required property int index
                    width: rows.width
                    mod: modelData
                    current: list.selectedId === modelData.id
                    dropTarget: list.draggingId !== "" && list.draggingId !== modelData.id && list.dropIndex === index
                    reorderable: list.reorderable
                    dragTarget: dragPreview
                    onSelected: list.selectRequested(modelData.id)
                    onToggleRequested: {
                        list.selectRequested(modelData.id);
                        list.toggleRequested(modelData);
                    }
                    onDragStarted: list.beginDrag(row)
                    onDragFinished: list.endDrag(row)
                }
            }
        }

        // Floating copy of the dragged row.
        StyledRect {
            id: dragPreview
            property string label: ""
            width: listArea.width
            height: Metrics.rowHeight
            visible: list.draggingId !== ""
            variant: "primary"
            radius: Styling.radius(0)
            z: 100

            onYChanged: {
                if (list.draggingId !== "")
                    list.dropIndex = ModsModel.dropSlot(y, height + rows.spacing, list.mods.length);
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: Metrics.padding
                anchors.rightMargin: Metrics.padding
                text: dragPreview.label
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                color: dragPreview.item
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
    }
}
