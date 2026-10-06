pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.settings.store
import "GalleryTabs.js" as GalleryTabs

// The preset switcher: search, tabs (GalleryTabs.js, one model per tab) and
// a grid of thumbnail cards. Moving over a card (pointer or arrows) previews
// it live; Enter or a click keeps it, Escape reverts; closing the switcher
// any other way reverts too (PresetPreviewer).
FocusScope {
    id: root

    property alias dwell: previewer.dwell
    property string tab: GalleryTabs.TABS[0].id
    property string query: ""
    property int currentIndex: 0
    property bool moved: false
    readonly property var cards: GalleryTabs.cards(root.tab, {
        "presets": PresetStudio.presets
    }, root.query)
    readonly property var current: root.cards[root.currentIndex] || null

    readonly property int columns: 3
    readonly property int cardW: Metrics.rowHeight * 5
    readonly property int cardH: Math.round((cardW - Metrics.spacing * 2) * 10 / 16) + Metrics.rowHeight
    readonly property int gap: Metrics.spacing * 2

    signal closeRequested

    implicitWidth: root.columns * (root.cardW + root.gap) + Metrics.padding * 2
    implicitHeight: header.implicitHeight + Math.round(2.5 * (root.cardH + root.gap)) + Metrics.padding * 3

    onCardsChanged: {
        if (!root.moved)
            root.currentIndex = GalleryTabs.startIndex(root.cards);
        root.currentIndex = Math.max(0, Math.min(root.currentIndex, root.cards.length - 1));
    }
    onQueryChanged: root.moved = true
    onActiveFocusChanged: {
        if (activeFocus)
            search.focusInput();
    }
    Component.onCompleted: PresetStudio.refresh()

    function select(index) {
        if (index < 0 || index >= root.cards.length)
            return;
        root.moved = true;
        root.currentIndex = index;
        grid.positionViewAtIndex(index, GridView.Contain);
        previewer.hover(root.cards[index]);
    }

    function move(delta) {
        root.select(Math.max(0, Math.min(root.cards.length - 1, root.currentIndex + delta)));
    }

    function accept() {
        if (!root.current)
            return;
        previewer.keep(root.current);
        root.closeRequested();
    }

    function cancel() {
        previewer.revert();
        root.closeRequested();
    }

    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Right)
            root.move(1);
        else if (k === Qt.Key_Left)
            root.move(-1);
        else if (k === Qt.Key_Down)
            root.move(root.columns);
        else if (k === Qt.Key_Up)
            root.move(-root.columns);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter)
            root.accept();
        else if (k === Qt.Key_Escape)
            root.cancel();
        else
            return;
        event.accepted = true;
    }

    PresetPreviewer {
        id: previewer
    }

    Column {
        id: header
        x: Metrics.padding
        y: Metrics.padding
        width: root.width - Metrics.padding * 2
        spacing: Metrics.spacing

        SearchInput {
            id: search
            width: parent.width
            iconText: Icons.magnifyingGlass
            placeholderText: I18n.t("presets.gallery.search")
            clearOnEscape: false
            onTextChanged: root.query = text
            onAccepted: root.accept()
            onEscapePressed: root.cancel()
            onLeftPressed: root.move(-1)
            onRightPressed: root.move(1)
            onUpPressed: root.move(-root.columns)
            onDownPressed: root.move(root.columns)
        }

        Row {
            visible: GalleryTabs.TABS.length > 1
            spacing: Metrics.spacing

            Repeater {
                model: GalleryTabs.TABS

                delegate: StyledRect {
                    id: chip
                    required property var modelData
                    variant: root.tab === modelData.id ? "primary" : "common"
                    radius: height / 2
                    width: chipLabel.implicitWidth + Metrics.padding * 2
                    height: Metrics.rowHeight * 0.7

                    Text {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: I18n.t(chip.modelData.labelKey)
                        color: Colors.overBackground
                        font.family: Config.defaultFont
                        font.pixelSize: Styling.fontSize(-1)
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.tab = chip.modelData.id;
                            root.moved = false;
                        }
                    }
                }
            }
        }
    }

    GridView {
        id: grid
        anchors.top: header.bottom
        anchors.topMargin: Metrics.padding
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Metrics.padding
        x: Metrics.padding
        width: root.columns * cellWidth
        clip: true
        cellWidth: root.cardW + root.gap
        cellHeight: root.cardH + root.gap
        model: root.cards
        currentIndex: root.currentIndex
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            width: grid.cellWidth
            height: grid.cellHeight

            PresetGalleryCard {
                anchors.centerIn: parent
                width: root.cardW
                height: root.cardH
                card: cell.modelData
                selected: root.currentIndex === cell.index
                onHovered: root.select(cell.index)
                onClicked: {
                    root.select(cell.index);
                    root.accept();
                }
            }
        }
    }

    Text {
        anchors.centerIn: grid
        visible: root.cards.length === 0
        text: I18n.t("presets.no_presets")
        color: Colors.outline
        font.family: Config.defaultFont
        font.pixelSize: Styling.fontSize(0)
    }
}
