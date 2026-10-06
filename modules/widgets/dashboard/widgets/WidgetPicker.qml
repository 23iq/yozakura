pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// Bento widget picker: the registry widgets not on the grid yet. Arrow keys
// move, Enter adds, Escape closes.
StyledRect {
    id: root

    property var registry
    property var ids: []

    signal picked(string id)
    signal closed

    variant: "popup"
    enableShadow: true
    radius: Styling.radius(8)
    implicitWidth: Math.min(Metrics.bentoCell * 4, grid.cellWidth * Math.max(1, Math.min(3, ids.length)) + Metrics.padding * 2)
    implicitHeight: title.height + grid.contentHeight + Metrics.padding * 2 + Metrics.spacing

    function open() {
        visible = true;
        grid.currentIndex = 0;
        grid.forceActiveFocus();
    }

    function close() {
        visible = false;
        closed();
    }

    Text {
        id: title
        x: Metrics.padding
        y: Metrics.padding * 0.75
        text: root.ids.length > 0 ? I18n.t("bento.picker_title") : I18n.t("bento.picker_empty")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(0)
        font.weight: Font.DemiBold
        color: Colors.overBackground
    }

    GridView {
        id: grid
        objectName: "bentoPickerGrid"
        anchors.top: title.bottom
        anchors.topMargin: Metrics.spacing
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Metrics.padding
        cellWidth: Metrics.bentoCell
        cellHeight: Metrics.rowHeight * 2
        interactive: false
        model: root.ids
        keyNavigationEnabled: true
        focus: root.visible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (grid.currentIndex >= 0 && grid.currentIndex < root.ids.length)
                    root.picked(root.ids[grid.currentIndex]);
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.close();
                event.accepted = true;
            }
        }

        delegate: Item {
            id: cardWrap

            required property string modelData
            required property int index
            readonly property var def: root.registry ? root.registry.byId(modelData) : null

            width: grid.cellWidth
            height: grid.cellHeight

            StyledRect {
                anchors.fill: parent
                anchors.margins: Metrics.spacing / 2
                radius: Styling.radius(2)
                variant: grid.currentIndex === cardWrap.index && grid.activeFocus || cardHover.hovered ? "primary" : "common"
                Accessible.role: Accessible.Button
                Accessible.name: cardWrap.def ? I18n.t(cardWrap.def.labelKey) : ""

                Column {
                    anchors.centerIn: parent
                    spacing: Metrics.spacing / 2
                    width: parent.width - Metrics.spacing * 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: cardWrap.def ? (Icons[cardWrap.def.icon] || "") : ""
                        font.family: Icons.font
                        font.pixelSize: Styling.fontSize(6)
                        color: Colors.primary
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: cardWrap.def ? I18n.t(cardWrap.def.labelKey) : ""
                        elide: Text.ElideRight
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.DemiBold
                        color: Colors.overBackground
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: cardWrap.def ? cardWrap.def.defaultW + "×" + cardWrap.def.defaultH : ""
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-3)
                        color: Colors.outline
                    }
                }

                HoverHandler {
                    id: cardHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: root.picked(cardWrap.modelData)
                }
            }
        }
    }
}
