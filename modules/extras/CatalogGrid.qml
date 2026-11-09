pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import "ExtrasModel.js" as ExtrasModel

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
    property int minCardWidth: 260
    property int gap: Space.m
    // Chip filter ("" = every offered category)
    property string category: ""
    // Own headed sections instead of one per category (onboarding AI step):
    // [{title, icon, hint, categories: [ids], footer: Component}], the
    // footer (optional) sits under the section's cards.
    property var sections: []
    readonly property string query: search.text
    signal logRequested(string job, string name)

    readonly property var catalog: ExtrasService.catalog
    readonly property int columns: Math.max(1, Math.floor((width + gap) / (minCardWidth + gap)))
    readonly property real cardWidth: Math.floor((width - (columns - 1) * gap) / columns)
    readonly property var entries: ExtrasModel.visibleEntries(root.catalog, ExtrasService.status, root.query, root.category !== "" ? root.category : root.categories, e => I18n.t("extras." + e.id + ".desc"))
    readonly property bool grouped: root.mode === "settings" && root.category === "" && root.query.trim() === ""
    readonly property var groups: root.sections.length > 0 ? root.sections.map(s => ({
                "category": null,
                "section": s,
                "entries": root.entries.filter(e => s.categories.includes(e.category))
            })).filter(g => g.entries.length > 0) : root.grouped ? ExtrasModel.groupByCategory(root.catalog, root.entries) : [
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

    spacing: Space.xl
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
            width: parent.width - (root.showSearch ? search.width + Space.l : 0)
            spacing: Space.s

            Repeater {
                model: [
                    {
                        "id": "",
                        "name": "extras.ui.all",
                        "icon": "squaresFour"
                    }
                ].concat(root.chipCategories)

                delegate: Chip {
                    id: chip
                    required property var modelData

                    icon: Icons[chip.modelData.icon] ?? ""
                    text: I18n.t(chip.modelData.name)
                    active: root.category === chip.modelData.id
                    activeFocusOnTab: true
                    Keys.onReturnPressed: root.category = chip.modelData.id
                    Keys.onSpacePressed: root.category = chip.modelData.id
                    Accessible.role: Accessible.RadioButton
                    onClicked: root.category = chip.modelData.id

                    FocusRing {
                        shown: chip.activeFocus
                        radius: chip.radius + Space.stroke
                    }
                }
            }
        }

        SearchField {
            id: search
            objectName: "catalogSearch"
            visible: root.showSearch
            anchors.right: parent.right
            width: Math.min(260, parent.width * 0.4)
            boxed: true
            placeholderText: I18n.t("extras.ui.search")
        }
    }

    Repeater {
        model: root.groups

        delegate: Column {
            id: group
            required property var modelData
            readonly property var cat: group.modelData.category
            readonly property var sec: group.modelData.section ?? null

            width: root.width
            spacing: Space.m

            Row {
                visible: !!group.cat
                spacing: Space.s
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: group.cat ? (Icons[group.cat.icon] ?? "") : ""
                    color: group.cat ? root.accentOf(group.cat.id) : Type.muted
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "body"
                    font.weight: Look.activeLabelWeight
                    text: group.cat ? I18n.t(group.cat.name) : ""
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "caption"
                    text: group.modelData.entries.length
                }
            }

            Column {
                visible: !!group.sec
                width: parent.width
                spacing: Space.xs
                Row {
                    spacing: Space.s
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: group.sec ? (Icons[group.sec.icon] ?? "") : ""
                        role: "body"
                        tone: "secondary"
                    }
                    KitText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "body"
                        font.weight: Look.activeLabelWeight
                        text: group.sec ? group.sec.title : ""
                    }
                }
                KitText {
                    visible: text !== ""
                    width: parent.width
                    role: "secondary"
                    text: group.sec ? (group.sec.hint ?? "") : ""
                    wrapMode: Text.WordWrap
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

            Loader {
                width: parent.width
                active: !!group.sec && !!group.sec.footer
                visible: active
                sourceComponent: group.sec ? (group.sec.footer ?? null) : null
            }
        }
    }

    KitText {
        width: parent.width
        visible: root.entries.length === 0
        topPadding: Space.xxl
        horizontalAlignment: Text.AlignHCenter
        role: "secondary"
        text: !root.catalog ? I18n.t("extras.ui.loading") : I18n.t("extras.ui.empty", root.query)
    }
}
