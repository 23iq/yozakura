pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.services
import qs.modules.theme
import "CompositorGate.js" as CompositorGate
import "SchemaUtil.js" as SchemaUtil
import "BentoLayout.js" as BentoLayout
import "Registry.js" as Registry

// A schema-driven destination tab, one composed screen: the hero in the
// middle (the stage: the live miniature of what the tab controls, `stage`
// in the schema, large, with a deep shadow) with the controls that act on
// space beside it (`hero.left` / `hero.right`: entries shown as side
// controls instead of in a card) and a hint under it (`hero.hint`); then
// one row of equal-height cards that fills the width (`row`: section ids),
// then any other section as a card of a bento (BentoLayout.js: one to
// three columns, a card with picture cards or an editor takes two). The
// hero recedes (scales down, fades) as the cards scroll up under it.
// Nothing here is category specific.
Flickable {
    id: page

    required property var category
    // Entries of this page the compositor gate hides on the running compositor
    readonly property var gated: CompositorGate.hiddenBy(page.category.sections, YozdService.compositorName)
    readonly property string stageUrl: page.category.stage ? Qt.resolvedUrl(Registry.stage(page.category.stage)) : ""
    readonly property var hero: page.category.hero || ({})
    // entries shown beside the stage (by key or id), not in their card
    readonly property var heroIds: (page.hero.left || []).concat(page.hero.right || [])
    readonly property var rowIds: page.category.row || []
    // the row is laid out only once all its cards exist (equal heights)
    readonly property int lastRowIndex: (page.category.sections || []).reduce((m, sec, i) => page.rowIds.indexOf(sec.id) >= 0 ? i : m, -1)
    readonly property real margin: Space.xl
    readonly property real gap: Space.l
    // the side columns of the hero
    readonly property real sideW: Math.min(Space.px(220), page.width * 0.19)
    function heroEntries(ids) {
        const out = [];
        for (const id of ids || []) {
            for (const sec of page.category.sections || []) {
                const e = (sec.entries || []).find(x => x.key === id || x.id === id);
                if (e) {
                    out.push(e);
                    break;
                }
            }
        }
        return out;
    }

    // Sections fill in a few per frame (as many as fit a frame budget): a
    // long page shows its top at once and never freezes the window.
    readonly property int sectionCount: (page.category.sections || []).length
    property int builtSections: 1
    readonly property bool complete: builtSections >= sectionCount
    // The sections built so far fill the viewport: the page can be shown.
    // SettingsPageHost keeps the page hidden until `enterReady`.
    property bool filled: false
    readonly property bool enterReady: complete || filled

    function buildAll() {
        builtSections = sectionCount;
    }

    FrameAnimation {
        running: !page.complete
        onTriggered: {
            // filled: every column reaches below the viewport, so the cards
            // still to come land out of sight (masonry puts a card at the
            // top of the shortest column)
            bento.relayout();
            if (!page.filled && page.height > 0 && page.builtSections > page.lastRowIndex && body.y + bento.floor >= page.height)
                page.filled = true;
            const start = Date.now();
            do {
                page.builtSections++;
            } while (!page.complete && Date.now() - start < 6)
            if (page.complete)
                bento.relayout();
        }
    }

    contentWidth: width
    contentHeight: body.y + body.height + Space.xxl * 3
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
    }

    NumberAnimation {
        id: scroller
        target: page
        property: "contentY"
        duration: Math.max(1, Motion.morph.duration)
        easing.type: Motion.morph.easing
    }

    // Scroll to an entry (or a section), flash it and give it focus.
    function reveal(sectionId, entryId) {
        buildAll();
        // place the cards now (twice: a card's new width can rewrap it)
        bento.relayout();
        bento.relayout();
        let target = null;
        for (let i = 0; i < sections.count; i++) {
            const s = sections.itemAt(i) as SettingsSection;
            if (!s)
                continue;
            if (entryId) {
                const r = s.rowFor(entryId);
                if (r) {
                    target = r;
                    break;
                }
            } else if (s.sectionId === sectionId) {
                target = s;
                break;
            }
        }
        if (!target)
            return;
        const y = target.mapToItem(page.contentItem, 0, 0).y;
        scroller.to = Math.max(0, Math.min(y - (page.height - target.height) / 3, contentHeight - height));
        scroller.restart();
        if (entryId) {
            SettingsStore.highlightedEntry = entryId;
            unflash.restart();
            target.forceActiveFocus();
        }
    }

    // Scroll an item of the page (e.g. one row of a custom editor) into view.
    function revealItem(item) {
        if (!item)
            return;
        const y = item.mapToItem(page.contentItem, 0, 0).y;
        const top = item.height > height / 2 ? y - Space.xxl * 3 : y - (height - item.height) / 2;
        scroller.to = Math.max(0, Math.min(top, contentHeight - height));
        scroller.restart();
    }

    Timer {
        id: unflash
        interval: 1600
        onTriggered: SettingsStore.highlightedEntry = ""
    }

    // The hero: the stage in the middle, the spatial controls beside it,
    // receding as the page scrolls.
    Item {
        id: heroArea
        objectName: "pageHero"
        readonly property real recede: Math.max(0, Math.min(1, page.contentY / Math.max(1, height)))
        readonly property bool sides: page.heroIds.length > 0
        x: page.margin
        y: Space.s + page.contentY * 0.35
        width: page.width - page.margin * 2
        height: stageLoader.active ? stageLoader.height : 0
        visible: stageLoader.active
        scale: 1 - heroArea.recede * 0.12
        opacity: 1 - heroArea.recede * 0.7
        transformOrigin: Item.Top

        Loader {
            id: stageLoader
            objectName: "pageStage"
            // as large as the window allows next to the side columns
            readonly property real room: heroArea.width - (heroArea.sides ? (page.sideW + page.gap) * 2 : 0)
            height: Math.round(Math.max(Space.px(220), Math.min(page.height * 0.5, room * 9 / 16, Space.px(460))))
            width: Math.round(Math.min(room, height * 16 / 9))
            x: (heroArea.width - width) / 2
            active: page.stageUrl !== ""
            source: page.stageUrl

            // a deep shadow under the stage
            RectangularShadow {
                z: -1
                anchors.fill: parent
                radius: Look.radius("surface", parent.height)
                offset: Qt.vector2d(0, Space.l)
                blur: Space.xxl * 2
                color: Qt.alpha(Colors.shadow, 0.55)
            }
        }

        Column {
            objectName: "heroLeft"
            width: page.sideW
            y: Space.l
            spacing: Space.s
            Repeater {
                model: page.heroEntries(page.hero.left)
                delegate: SettingRow {
                    required property var modelData
                    width: page.sideW
                    entry: modelData
                    bare: true
                }
            }
        }

        Column {
            objectName: "heroRight"
            x: heroArea.width - width
            width: page.sideW
            y: Space.l
            spacing: Space.s
            Repeater {
                model: page.heroEntries(page.hero.right)
                delegate: Card {
                    id: side
                    required property var modelData
                    width: page.sideW
                    padding: Space.s
                    visible: sideRow.shown
                    SettingRow {
                        id: sideRow
                        width: side.contentWidth
                        entry: side.modelData
                    }
                }
            }
        }
    }

    KitText {
        id: heroHint
        objectName: "heroHint"
        visible: heroArea.visible && !!page.hero.hint
        x: page.margin
        y: heroArea.y + heroArea.height * heroArea.scale + Space.m
        width: page.width - page.margin * 2
        horizontalAlignment: Text.AlignHCenter
        role: "secondary"
        opacity: heroArea.opacity
        text: page.hero.hint ? I18n.t(page.hero.hint) : ""
    }

    // The cards: the row, then the bento.
    Item {
        id: body
        z: 1
        width: page.width - page.margin * 2
        x: page.margin
        y: heroArea.visible ? heroArea.height + (heroHint.visible ? heroHint.height + Space.m : 0) + Space.xl : Space.s
        height: bento.height + (note.visible ? note.height + Space.l : 0)

        Item {
            id: bento
            objectName: "pageBento"
            readonly property real gap: page.gap
            readonly property int fullCols: BentoLayout.columns(parent.width, Space.px(300))
            readonly property var spans: (page.category.sections || []).map(s => BentoLayout.spanOf(s, SchemaUtil.inWindow))
            // the sections of the bento (the row's are laid out apart)
            readonly property var restSpans: (page.category.sections || []).filter(s => page.rowIds.indexOf(s.id) < 0).map(s => BentoLayout.spanOf(s, SchemaUtil.inWindow))
            readonly property int cols: page.rowIds.length > 0 ? fullCols : BentoLayout.fit(fullCols, restSpans)
            readonly property real colW: (parent.width - gap * (fullCols - 1)) / fullCols
            // card places {x, y, w, h} (h < 0: its own height), re-run
            // when a card's height or visibility changes
            property var places: []
            property real floor: 0
            width: page.rowIds.length > 0 ? parent.width : colW * cols + gap * (cols - 1)
            x: (parent.width - width) / 2
            height: 0

            function relayout() {
                // the row: equal widths, the tallest card's height
                const inRow = [];
                let rowH = 0;
                for (let i = 0; i < sections.count; i++) {
                    const s = sections.itemAt(i) as SettingsSection;
                    if (s && page.rowIds.indexOf(s.sectionId) >= 0 && s.visible) {
                        inRow.push(i);
                        rowH = Math.max(rowH, s.implicitHeight);
                    }
                }
                const rowW = inRow.length > 0 ? (bento.width - bento.gap * (inRow.length - 1)) / inRow.length : 0;
                const top = inRow.length > 0 ? rowH + bento.gap : 0;
                // the rest: masonry
                const items = [];
                const rest = [];
                for (let i = 0; i < sections.count; i++) {
                    const s = sections.itemAt(i);
                    if (page.rowIds.indexOf((page.category.sections[i] || {}).id) >= 0)
                        continue;
                    rest.push(i);
                    items.push({
                        "span": bento.spans[i] || 1,
                        "height": s && s.visible ? s.implicitHeight : 0
                    });
                }
                const r = BentoLayout.place(items, bento.cols, bento.gap);
                const out = [];
                inRow.forEach((i, k) => out[i] = {
                        "x": k * (rowW + bento.gap),
                        "y": 0,
                        "w": rowW,
                        "h": rowH
                    });
                rest.forEach((i, k) => {
                    const pl = r.places[k];
                    out[i] = {
                        "x": pl.col * (bento.colW + bento.gap),
                        "y": top + pl.y,
                        "w": pl.span * bento.colW + (pl.span - 1) * bento.gap,
                        "h": -1
                    };
                });
                bento.places = out;
                bento.height = top + r.height;
                bento.floor = top + r.floor;
            }
            onColsChanged: Qt.callLater(bento.relayout)
            onWidthChanged: Qt.callLater(bento.relayout)

            Repeater {
                id: sections
                model: page.category.sections

                delegate: SettingsSection {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property var place: bento.places[index] || ({
                            "x": 0,
                            "y": 0,
                            "w": bento.width,
                            "h": -1
                        })
                    section: modelData
                    exclude: page.heroIds
                    pending: index >= page.builtSections
                    x: card.place.x
                    y: card.place.y
                    width: card.place.w
                    height: card.place.h > 0 ? card.place.h : implicitHeight
                    onImplicitHeightChanged: Qt.callLater(bento.relayout)
                    onVisibleChanged: Qt.callLater(bento.relayout)
                    Component.onCompleted: Qt.callLater(bento.relayout)
                }
            }
        }

        KitText {
            id: note
            objectName: "compositorOnlyNote"
            y: bento.height + Space.l
            width: parent.width
            visible: page.gated.count > 0
            role: "caption"
            color: Type.muted
            wrapMode: Text.WordWrap
            text: I18n.tn("prefs.compositor_only.note", page.gated.count).replace("%2", CompositorGate.describe(page.gated.compositors))
        }
    }
}
