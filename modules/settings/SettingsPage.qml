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

// A schema-driven tab, one scrolling page: an optional compact stage at the
// top (`stage`: the live picture of what the tab places or styles, at most
// about a third of the page; only tabs about something on the desktop have
// one, see Registry.DESKTOP_STAGES) with a one-line hint under it
// (`hero.hint`) and, for Wallpaper, a film strip along its foot
// (`hero.foot`); then every section of the tab as a card of a masonry
// (BentoLayout.js: one to three columns, cards as tall as their rows; a
// card with pictures or an editor takes two columns). `row` names the
// cards that come first, in that order. Nothing is hidden behind a sheet:
// every window row of the tab is on the page, and the stage recedes as the
// cards scroll up over it. Nothing here is category specific.
Flickable {
    id: page

    required property var category
    // Entries of this page the compositor gate hides on the running compositor
    readonly property var gated: CompositorGate.hiddenBy(page.category.sections, YozdService.compositorName)
    readonly property string stageUrl: page.category.stage ? Qt.resolvedUrl(Registry.stage(page.category.stage)) : ""
    readonly property var hero: page.category.hero || ({})
    // `hero.foot`: entries in a strip along the stage's foot (the wallpaper
    // library), as wide as the stage; not in their card
    readonly property var heroIds: page.hero.foot || []
    readonly property real footH: page.heroIds.length > 0 && page.stageUrl !== "" ? Space.px(76) : 0
    // a wide page puts the foot beside the stage (the library as a grid as
    // tall as the miniature) instead of under it: one band, not two
    readonly property bool footSide: page.footH > 0 && heroArea.width - page.height / 3 * 16 / 9 - Space.l >= Space.px(480)
    // `row`: the sections that lead the page, in this order
    readonly property var leadIds: (page.category.row || []).map(r => typeof r === "string" ? r : r.id)
    // the sections in page order: the lead ones first, then cards of plain
    // rows, then cards of big controls (BentoLayout.order)
    readonly property var order: BentoLayout.order(page.category.sections || [], page.leadIds, SchemaUtil.inWindow)
    // rank of a section in the page order (built in this order too)
    readonly property var rank: {
        const out = [];
        page.order.forEach((i, k) => out[i] = k);
        return out;
    }
    readonly property bool listForm: page.category.form === "list"
    // a stage that is not the desktop: no wallpaper (Stage `calm`)
    readonly property bool plainStage: !Registry.DESKTOP_STAGES[page.category.id]
    // every key a window row of this page edits (a card offers no "Turn on"
    // for a switch that is a row of the page)
    readonly property var pageKeys: (page.category.sections || []).reduce((all, sec) => all.concat((sec.entries || []).filter(e => e.key && SchemaUtil.inWindow(e, sec)).map(e => e.key)), [])
    readonly property real margin: Space.xl
    readonly property real gap: Look.screenGap

    // Sections fill in a few per frame (as many as fit a frame budget): a
    // long page shows its top at once and never freezes the window.
    readonly property int sectionCount: (page.category.sections || []).length
    property int builtSections: 1
    readonly property bool complete: builtSections >= sectionCount
    // The sections built so far fill the viewport: the page can be shown.
    // SettingsPageHost keeps the page hidden until `enterReady`.
    property bool filled: false
    readonly property bool enterReady: complete || filled
    // once shown, cards glide to new places (a toggle that shows rows):
    // before, they land in place
    property bool settled: false
    onEnterReadyChanged: if (enterReady)
        Qt.callLater(() => page.settled = true)

    // every card placed inside the viewport is built (a card still to build
    // has no height: it would appear, or grow, after the page showed; cards
    // fill holes above others, so build order alone does not decide it)
    function viewportBuilt() {
        const places = bento.places;
        for (let i = 0; i < places.length; i++) {
            if (places[i] && body.y + places[i].y < page.height && page.rank[i] >= page.builtSections)
                return false;
        }
        return true;
    }

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
            if (!page.filled && page.height > 0 && body.y + bento.floor >= page.height && page.viewportBuilt())
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
    contentHeight: body.y + body.height + page.margin
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
        } else {
            // a card reached from the stage: a brief accent wash
            SettingsStore.highlightedSection = sectionId;
            unflash.restart();
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
        onTriggered: {
            SettingsStore.highlightedEntry = "";
            SettingsStore.highlightedSection = "";
        }
    }

    // A desktop stage (a 16:9 screen) on a wide page (two or three columns)
    // stands in the first column, the cards beside and under it (no blank band beside a
    // centred stage); a strip, a band or a narrower page keeps it on top.
    readonly property bool beside: !!stageLoader.stage && !stageLoader.strip && !page.listForm && !page.plainStage && bento.fullCols >= 3 && bento.cols >= 2 && page.footH === 0
    // the block the stage and its hint take in the first column
    readonly property real besideH: page.beside ? heroArea.height + (heroHint.visible ? heroHint.height + Space.m : 0) : 0
    onBesideChanged: Qt.callLater(bento.relayout)
    onBesideHChanged: Qt.callLater(bento.relayout)

    // The stage: compact, centred, receding as the page scrolls.
    Item {
        id: heroArea
        objectName: "pageHero"
        readonly property real recede: page.beside ? 0 : Math.max(0, Math.min(1, page.contentY / Math.max(1, height)))
        x: page.beside ? body.x + bento.x : page.margin
        y: page.beside ? body.y : Space.s + page.contentY * 0.35
        width: page.beside ? bento.colW : page.width - page.margin * 2
        height: stageLoader.active ? stageLoader.height + (page.footH > 0 && !page.footSide ? Space.s + page.footH : 0) : 0
        visible: stageLoader.active
        scale: 1 - heroArea.recede * 0.12
        opacity: 1 - heroArea.recede * 0.7
        transformOrigin: Item.Top

        Loader {
            id: stageLoader
            objectName: "pageStage"
            // a third of the page at most, 16:9, never taller than a band
            // needs (a list page's band is short)
            // a stage that is a strip (the bar, the dock) asks for its height
            // the loaded stage, untyped (stages declare what they ask for)
            readonly property var stage: stageLoader.item
            readonly property real asked: stageLoader.stage && stageLoader.stage.preferredHeight > 0 ? stageLoader.stage.preferredHeight : 0
            // beside the cards: the column's width, a third of the page at most
            height: page.beside ? Math.round(Math.min(heroArea.width * 9 / 16, page.height / 3)) : Math.round(Math.min(page.height / 3, stageLoader.asked > 0 ? stageLoader.asked : page.listForm ? Math.max(Space.px(110), Math.min(page.height * 0.2, Space.px(150))) : Math.max(Space.px(150), Math.min(page.height * 0.32, heroArea.width * 9 / 16, Space.px(300)))))
            // a desktop stage is a 16:9 screen; a plain one (a band, the
            // battery, a terminal) is a wide strip of the thing itself
            // a strip stage (`pageWide: true`) takes the page's width (a flag,
            // never its height: that follows from the width)
            readonly property bool strip: !!stageLoader.stage && stageLoader.stage.pageWide === true
            width: Math.round(page.listForm || stageLoader.strip ? heroArea.width : (page.plainStage ? Math.min(heroArea.width, Space.px(900)) : Math.min(heroArea.width, height * 16 / 9)))
            x: page.footSide ? 0 : (heroArea.width - width) / 2
            active: page.stageUrl !== ""
            source: page.stageUrl
            // a page that is not about the desktop, or a strip of the thing itself
            // (the bar, the island): a plain stage, no picture
            onLoaded: {
                if (item && "calm" in item)
                    item.calm = Qt.binding(() => page.plainStage || stageLoader.strip);
            }

            // a soft shadow under the stage
            RectangularShadow {
                z: -1
                anchors.fill: parent
                radius: Look.radius("surface", parent.height)
                offset: Qt.vector2d(0, Space.m)
                blur: Space.xxl
                color: Qt.alpha(Colors.shadow, 0.4)
            }
        }

        // `hero.foot`: a strip along the stage's foot, as wide as the stage
        Column {
            id: heroFoot
            objectName: "heroFoot"
            visible: page.footH > 0
            x: page.footSide ? stageLoader.width + Space.l : stageLoader.x
            y: page.footSide ? 0 : stageLoader.height + Space.s
            width: page.footSide ? heroArea.width - x : stageLoader.width
            Repeater {
                model: page.footH > 0 ? (page.category.sections || []).reduce((all, sec) => all.concat((sec.entries || []).filter(e => page.heroIds.indexOf(e.key || e.id) >= 0)), []) : []
                delegate: SettingRow {
                    required property var modelData
                    width: heroFoot.width
                    height: page.footSide ? stageLoader.height : page.footH
                    entry: modelData
                    bare: true
                    fillHeight: (page.footSide ? stageLoader.height : page.footH) - Space.s * 2
                }
            }
        }
    }

    // the hint: a plain caption line under the stage, clear of it
    KitText {
        id: heroHint
        objectName: "heroHint"
        visible: heroArea.visible && !!page.hero.hint
        x: page.beside ? heroArea.x : page.footSide ? page.margin + stageLoader.x : page.margin
        y: heroArea.y + heroArea.height * heroArea.scale + Space.m
        width: page.beside ? heroArea.width : page.footSide ? stageLoader.width : page.width - page.margin * 2
        horizontalAlignment: Text.AlignHCenter
        role: "caption"
        // two lines at most in a narrow window, whole
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        opacity: heroArea.opacity
        text: page.hero.hint ? I18n.t(page.hero.hint) : ""
    }

    // The cards.
    Item {
        id: body
        z: 1
        width: page.width - page.margin * 2
        x: page.margin
        y: heroArea.visible && !page.beside ? heroArea.height + (heroHint.visible ? heroHint.height + Space.m : 0) + page.gap + Space.s : Space.s
        height: bento.height + (note.visible ? note.height + page.gap : 0)

        Item {
            id: bento
            objectName: "pageBento"
            readonly property real gap: page.gap
            // columns with hysteresis: a resize near a breakpoint never makes
            // the cards flip back and forth
            property int fullCols: 1
            function pickCols() {
                const w = body.width;
                const n = BentoLayout.columns(w, Space.px(340));
                // fewer columns only once the width is clearly under the
                // switch point
                bento.fullCols = n < bento.fullCols && BentoLayout.columns(w + Space.px(24), Space.px(340)) >= bento.fullCols ? bento.fullCols : n;
            }
            Connections {
                target: body
                function onWidthChanged() {
                    bento.pickCols();
                }
            }
            Component.onCompleted: bento.pickCols()
            readonly property var spans: (page.category.sections || []).map(s => BentoLayout.spanOf(s, SchemaUtil.inWindow))
            // the cards that show (a section without a window row is no card)
            readonly property int cols: BentoLayout.fit(fullCols, bento.spans.filter((sp, i) => ((page.category.sections || [])[i].entries || []).some(e => SchemaUtil.inWindow(e, page.category.sections[i]))))
            // two or three columns share the page's width; one card alone keeps
            // a column's width (centred), never stretched across
            readonly property real colW: bento.cols >= 2 ? (parent.width - gap * (cols - 1)) / cols : (parent.width - gap * (fullCols - 1)) / fullCols
            // card places {x, y, w} (in page order), re-run when a card's
            // height or visibility changes
            property var places: []
            property bool jump: false
            // the columns of the cards once the page is whole (see relayout)
            property var assigned: null
            property bool frozen: false
            Connections {
                target: page.visible ? SettingsStore : null
                function onValueSet(key, value) {
                    bento.frozen = true;
                }
            }
            property int assignedCols: 0
            property real floor: 0
            width: colW * cols + gap * (cols - 1)
            x: (parent.width - width) / 2
            height: 0

            function relayout() {
                const items = [];
                for (const i of page.order) {
                    const s = sections.itemAt(i);
                    items.push({
                        "span": bento.spans[i] || 1,
                        "height": s && s.visible ? s.implicitHeight : 0
                    });
                }
                // after the first change made on the page, cards keep their
                // columns (a toggle never reshuffles them); until then, and
                // for a new column count, they are placed afresh (content
                // that loads late still balances the columns)
                const keep = bento.frozen && bento.assigned !== null && bento.assignedCols === bento.cols;
                const r = BentoLayout.place(items, bento.cols, bento.gap, keep ? page.order.map(i => bento.assigned[i]) : null, page.beside ? [
                    {
                        "col": 0,
                        "span": 1,
                        "height": page.besideH + bento.gap
                    }
                ] : null);
                if (!keep) {
                    const a = [];
                    page.order.forEach((i, k) => a[i] = r.places[k]);
                    bento.assigned = a;
                    bento.assignedCols = bento.cols;
                }
                const out = [];
                page.order.forEach((i, k) => {
                    const pl = r.places[k];
                    out[i] = {
                        "x": pl.col * (bento.colW + bento.gap),
                        "y": pl.y,
                        "w": pl.span * bento.colW + (pl.span - 1) * bento.gap
                    };
                });
                // one card pushed down: every card lands at once (a glide
                // up beside a jump down could cross for a few frames)
                bento.jump = out.some((pl, i) => {
                    const s = sections.itemAt(i);
                    return s && pl && pl.y > s.y + 0.5;
                });
                bento.places = out;
                bento.height = r.height;
                bento.floor = r.floor;
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
                            "w": bento.width
                        })
                    section: modelData
                    exclude: page.heroIds
                    pageKeys: page.pageKeys
                    pending: page.rank[index] >= page.builtSections
                    x: card.place.x
                    width: card.place.w
                    height: implicitHeight
                    // cards that move up (rows hidden above them) glide into
                    // the room; when one is pushed down (a card above grew)
                    // all land at once, so none sits under another, even for
                    // a frame
                    readonly property real placeY: card.place.y
                    onPlaceYChanged: {
                        if (page.settled && Motion.glide.duration > 0 && !bento.jump && card.placeY < card.y) {
                            glideY.to = card.placeY;
                            glideY.restart();
                        } else {
                            glideY.stop();
                            card.y = card.placeY;
                        }
                    }
                    NumberAnimation {
                        id: glideY
                        target: card
                        property: "y"
                        duration: Motion.glide.duration
                        easing.type: Motion.glide.easing
                    }
                    // at once, in the same frame: a card that grows never
                    // paints over the card under it
                    onImplicitHeightChanged: bento.relayout()
                    onVisibleChanged: Qt.callLater(bento.relayout)
                    Component.onCompleted: {
                        card.y = card.placeY;
                        Qt.callLater(bento.relayout);
                    }
                }
            }
        }

        KitText {
            id: note
            objectName: "compositorOnlyNote"
            y: bento.height + page.gap
            width: parent.width
            visible: page.gated.count > 0
            role: "caption"
            color: Type.muted
            wrapMode: Text.WordWrap
            text: page.gated.count > 0 ? I18n.tn("prefs.compositor_only.note", page.gated.count).replace("%2", CompositorGate.describe(page.gated.compositors)) : ""
        }
    }
}
