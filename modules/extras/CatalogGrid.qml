pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import "ExtrasModel.js" as ExtrasModel
import "../settings/Ui.js" as Ui

// The Apps & Extras catalog: category chips + search, then cards in a grid
// that fits as many >= minCardWidth columns as the width allows. Settings
// shows every category with section headers; onboarding steps pass a
// `categories` subset. `selected` (id -> true) is the pending install
// selection, read by InstallBar. The grid grows to its content: the host
// page scrolls.
Column {
    id: root

    // "settings" | "onboarding"
    property string mode: "settings"
    // Category ids to offer ([] = all)
    property var categories: []
    property var selected: ({})
    property bool showSearch: root.mode === "settings"
    property bool showChips: true
    property int minCardWidth: 220
    property int gap: 14
    // Chip filter ("" = every offered category)
    property string category: ""
    readonly property string query: search.text
    signal logRequested(string job, string name)

    readonly property var catalog: ExtrasService.catalog
    readonly property int columns: Math.max(1, Math.floor((width + gap) / (minCardWidth + gap)))
    readonly property real cardWidth: Math.floor((width - (columns - 1) * gap) / columns)
    readonly property var entries: ExtrasModel.visibleEntries(root.catalog, ExtrasService.status, root.query, root.category !== "" ? root.category : root.categories, e => I18n.t("extras." + e.id + ".desc"))
    readonly property bool grouped: root.mode === "settings" && root.category === "" && root.query.trim() === ""
    readonly property var groups: root.grouped ? ExtrasModel.groupByCategory(root.catalog, root.entries) : [
        {
            "category": null,
            "entries": root.entries
        }
    ]
    // Chips: offered categories that have something to show.
    readonly property var chipCategories: {
        const cats = root.catalog ? root.catalog.categories : [];
        const all = ExtrasModel.visibleEntries(root.catalog, ExtrasService.status, "", root.categories);
        return cats.filter(c => all.some(e => e.category === c.id));
    }
    readonly property var accents: [Colors.primary, Colors.blue, Colors.tertiary, Colors.cyan, Colors.magenta, Colors.yellow]

    function accentOf(categoryId) {
        return root.accents[ExtrasModel.accentIndex(root.catalog, categoryId) % root.accents.length];
    }

    function toggle(id) {
        root.selected = ExtrasModel.toggled(root.selected, id);
    }

    spacing: 22
    Component.onCompleted: ExtrasService.load()

    Connections {
        target: ExtrasService
        function onQueued(ids) {
            const next = Object.assign({}, root.selected);
            ids.forEach(id => delete next[id]);
            root.selected = next;
        }
    }

    // Chips + search
    Item {
        width: parent.width
        visible: root.showChips || root.showSearch
        height: Math.max(chips.implicitHeight, root.showSearch ? search.height : 0)

        Flow {
            id: chips
            visible: root.showChips
            width: parent.width - (root.showSearch ? search.width + 16 : 0)
            spacing: 8

            Repeater {
                model: [
                    {
                        "id": "",
                        "name": "extras.ui.all",
                        "icon": "squaresFour"
                    }
                ].concat(root.chipCategories)

                delegate: Item {
                    id: chip
                    required property var modelData
                    readonly property bool on: root.category === chip.modelData.id

                    width: chipRow.implicitWidth + 26
                    height: 34
                    activeFocusOnTab: true
                    Keys.onReturnPressed: root.category = chip.modelData.id
                    Keys.onSpacePressed: root.category = chip.modelData.id
                    Accessible.role: Accessible.RadioButton
                    Accessible.checked: chip.on

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: chip.on ? Ui.alpha(Colors.primary, chipArea.containsMouse ? 0.34 : 0.26) : Ui.alpha(Colors.overBackground, chipArea.containsMouse ? 0.1 : 0.05)
                        border.width: chip.activeFocus ? 2 : 1
                        border.color: chip.on ? Colors.primary : Ui.alpha(Colors.outline, 0.35)
                        Behavior on color {
                            enabled: Config.animDuration > 0
                            ColorAnimation {
                                duration: Config.animDuration / 2
                            }
                        }
                    }
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons[chip.modelData.icon] ?? ""
                            font.family: Icons.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: chip.on ? Colors.primary : Colors.overSurfaceVariant
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.t(chip.modelData.name)
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: chip.on ? Font.DemiBold : Font.Normal
                            color: chip.on ? Colors.overBackground : Colors.overSurfaceVariant
                        }
                    }
                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.category = chip.modelData.id
                    }
                }
            }
        }

        SearchInput {
            id: search
            objectName: "catalogSearch"
            visible: root.showSearch
            anchors.right: parent.right
            width: Math.min(260, parent.width * 0.4)
            iconText: Icons.magnifyingGlass
            placeholderText: I18n.t("extras.ui.search")
        }
    }

    Repeater {
        model: root.groups

        delegate: Column {
            id: group
            required property var modelData
            readonly property var cat: group.modelData.category

            width: root.width
            spacing: 12

            Row {
                visible: !!group.cat
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: group.cat ? (Icons[group.cat.icon] ?? "") : ""
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(0)
                    color: group.cat ? root.accentOf(group.cat.id) : Colors.primary
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: group.cat ? I18n.t(group.cat.name) : ""
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.Bold
                    color: Colors.overBackground
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: group.modelData.entries.length
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overSurfaceVariant
                }
            }

            Grid {
                columns: root.columns
                columnSpacing: root.gap
                rowSpacing: root.gap

                Repeater {
                    model: group.modelData.entries

                    delegate: CatalogCard {
                        id: card
                        required property var modelData
                        objectName: "card-" + card.modelData.id
                        width: root.cardWidth
                        entry: card.modelData
                        status: ExtrasService.status[card.modelData.id] ?? null
                        progress: ExtrasService.progress[card.modelData.id] ?? null
                        cardState: ExtrasModel.cardState(card.status, card.progress)
                        selected: card.cardState === "selectable" && !!root.selected[card.modelData.id]
                        accent: root.accentOf(card.modelData.category)
                        onToggled: root.toggle(card.modelData.id)
                        onRetry: ExtrasService.install([card.modelData.id])
                        onUpgradeRetry: ExtrasService.retryWithUpgrade(card.progress.job)
                        onCancel: ExtrasService.cancel(card.progress.job)
                        onShowLog: root.logRequested(card.progress.job, card.modelData.name)
                    }
                }
            }
        }
    }

    Text {
        width: parent.width
        visible: root.entries.length === 0
        topPadding: 30
        horizontalAlignment: Text.AlignHCenter
        text: !root.catalog ? I18n.t("extras.ui.loading") : I18n.t("extras.ui.empty", root.query)
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(0)
        color: Colors.overSurfaceVariant
    }
}
