pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../Ui.js" as Ui

// The searchable font list of FontControl: a kit Surface with a SearchField,
// a "Monospace only" Chip and one ListRow per family, each drawn in itself
// (the current family selected with a check). Arrow keys move, Enter picks.
Popup {
    id: picker

    property string family: ""
    property bool monoOnly: false
    property string query: ""
    readonly property var families: {
        const q = query.trim().toLowerCase();
        return Qt.fontFamilies().filter(f => (!monoOnly || Ui.looksMonospace(f)) && (q === "" || f.toLowerCase().indexOf(q) !== -1));
    }

    signal picked(string family)

    function pick(f) {
        picker.picked(f);
        picker.close();
    }

    height: Math.min(Space.px(360), list.contentHeight + head.height + Space.s * 3)
    padding: Space.s
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    onOpened: {
        query = "";
        searchField.text = "";
        searchField.focusInput();
        const i = families.indexOf(picker.family);
        if (i >= 0)
            list.positionViewAtIndex(i, ListView.Center);
    }

    // The kit popup Surface, kept nearly opaque: an in-window popup gets no
    // compositor blur, and the families must stay readable over the page.
    background: Surface {
        padding: 0
        backgroundOpacity: 0.96
    }

    contentItem: Column {
        spacing: Space.s

        Row {
            id: head
            width: parent.width
            leftPadding: Space.s
            spacing: Space.s

            SearchField {
                id: searchField
                objectName: "fontSearch"
                width: parent.width - parent.leftPadding - monoChip.width - parent.spacing
                height: Space.controlS
                placeholderText: I18n.t("prefs.font.search")
                onSearchTextChanged: t => picker.query = t
                onDownPressed: list.incrementCurrentIndex()
                onUpPressed: list.decrementCurrentIndex()
                onAccepted: {
                    if (list.currentIndex >= 0 && list.currentIndex < picker.families.length)
                        picker.pick(picker.families[list.currentIndex]);
                }
            }

            Chip {
                id: monoChip
                objectName: "fontMonoOnly"
                anchors.verticalCenter: parent.verticalCenter
                active: picker.monoOnly
                text: I18n.t("prefs.font.mono_only")
                onClicked: picker.monoOnly = !picker.monoOnly
            }
        }

        ListView {
            id: list
            objectName: "fontList"
            width: parent.width
            height: picker.availableHeight - head.height - parent.spacing
            clip: true
            model: picker.families
            cacheBuffer: 200
            spacing: Space.hairline
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            currentIndex: picker.families.indexOf(picker.family)

            delegate: ListRow {
                id: row
                required property string modelData
                required property int index
                width: list.width
                title: row.modelData
                titleFamily: row.modelData
                selected: row.modelData === picker.family
                highlighted: list.currentIndex === row.index && !row.selected
                trailing: row.selected ? checkGlyph : null
                onClicked: picker.pick(row.modelData)
            }
        }
    }

    Component {
        id: checkGlyph
        Text {
            text: Icons.accept
            font.family: Icons.font
            font.pixelSize: Type.iconSize("secondary")
            color: Type.accent
        }
    }
}
