pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings.store
import "SchemaUtil.js" as SchemaUtil
import "BentoLayout.js" as BentoLayout

// The cards of a schema page (SettingsPage): one SettingsSection per
// section, placed as a masonry (BentoLayout.place: cards as tall as their
// rows, each at the highest free place that holds it). In two panes the
// left column alone; on the wide grid two equal columns; in a narrow window
// one to three columns with hysteresis. The grid starts at the page's left
// edge in every tab (it never moves between tabs) and a list page's cards
// share the band's whole width. Once the first change was made on the page
// a card keeps its column (a toggle moves it up or down, never across).
Item {
    id: bento

    // the schema category and the page's order of its sections
    required property var category
    required property var order
    required property var rank
    // sections built so far (the page fills them in a few per frame)
    required property int builtSections
    required property bool complete
    // the page has shown once (relayouts glide from then on)
    required property bool settled
    // two panes (the left column) / the two-column destination grid
    required property bool split
    required property bool wide
    // a list page: the cards share the band's width
    required property bool listForm
    // entry keys / ids shown elsewhere (beside the stage)
    required property var exclude
    // every key a card row of this page edits
    required property var pageKeys
    // the page shows (a kept-alive hidden page ignores changes)
    required property bool active

    objectName: "pageBento"
    readonly property real gap: Look.screenGap
    readonly property alias count: sections.count
    function itemAt(i) {
        return sections.itemAt(i);
    }

    // columns with hysteresis: a resize near a breakpoint never makes the
    // cards flip back and forth
    property int fullCols: 1
    function pickCols() {
        if (bento.split || bento.wide) {
            // the destination grid: the left column of two panes, or both
            // columns
            bento.fullCols = bento.split ? 1 : 2;
            return;
        }
        const w = bento.width;
        const n = BentoLayout.columns(w, Space.px(340));
        // fewer columns only once the width is clearly under the switch point
        bento.fullCols = n < bento.fullCols && BentoLayout.columns(w + Space.px(24), Space.px(340)) >= bento.fullCols ? bento.fullCols : n;
    }
    onWidthChanged: bento.pickCols()
    Component.onCompleted: bento.pickCols()
    onWideChanged: bento.pickCols()
    onSplitChanged: bento.pickCols()
    readonly property var spans: (bento.category.sections || []).map(s => BentoLayout.spanOf(s, SchemaUtil.inCards))
    // the cards that show (a section without a card row is no card)
    readonly property int cols: bento.split ? 1 : BentoLayout.fit(bento.fullCols, bento.spans.filter((sp, i) => ((bento.category.sections || [])[i].entries || []).some(e => SchemaUtil.inCards(e, bento.category.sections[i]))))
    // the grid's column: a lone card keeps a column's width (the grid
    // never moves between tabs); a list page's cards share the band's width
    readonly property real colW: bento.split ? bento.width : (bento.width - bento.gap * ((bento.listForm ? bento.cols : bento.fullCols) - 1)) / (bento.listForm ? bento.cols : bento.fullCols)
    // card places {x, y, w} (in page order), re-run when a card's height or
    // visibility changes
    property var places: []
    // the columns of the cards once the page is whole (see relayout)
    property var assigned: null
    property bool frozen: false
    Connections {
        target: bento.active ? SettingsStore : null
        function onValueSet(key, value) {
            bento.frozen = true;
        }
    }
    property int assignedCols: 0
    // cards that took the free columns beside them keep that span while
    // the column count holds: a widened card is shorter, and placing it
    // narrow again would widen it again (no relayout loop)
    property var grown: ({})
    property int grownCols: 0
    // where the shortest column ends
    property real floor: 0
    implicitHeight: 0

    // `eased`: a discrete relayout (a card shown or hidden, a new column
    // count): the cards glide to their places. Otherwise (a card folding
    // rows open or shut, content wrapping, a resize) they follow in the
    // same frame, in lockstep with the fold.
    function relayout(eased) {
        const items = [];
        for (const i of bento.order) {
            const s = sections.itemAt(i);
            items.push({
                "span": bento.split ? 1 : Math.max(bento.spans[i] || 1, bento.grownCols === bento.cols ? (bento.grown[i] || 1) : 1),
                "height": s && s.visible ? s.implicitHeight : 0
            });
        }
        // after the first change made on the page, cards keep their columns
        // (a toggle never reshuffles them); until then, and for a new column
        // count, they are placed afresh (content that loads late still
        // balances the columns)
        const keep = bento.frozen && bento.assigned !== null && bento.assignedCols === bento.cols;
        const r = BentoLayout.place(items, bento.cols, bento.gap, keep ? bento.order.map(i => bento.assigned[i]) : null, null);
        if (!keep) {
            const a = [];
            bento.order.forEach((i, k) => a[i] = r.places[k]);
            bento.assigned = a;
            // (recorded once every card is built: a neighbour still to come
            // is no free column)
            const g = bento.grownCols === bento.cols ? Object.assign({}, bento.grown) : {};
            if (bento.complete)
                bento.order.forEach((i, k) => {
                    if (r.places[k].span > (bento.spans[i] || 1))
                        g[i] = Math.max(g[i] || 1, r.places[k].span);
                });
            bento.grown = g;
            bento.grownCols = bento.cols;
            bento.assignedCols = bento.cols;
        }
        const out = [];
        bento.order.forEach((i, k) => {
            const pl = r.places[k];
            out[i] = {
                "x": pl.col * (bento.colW + bento.gap),
                "y": pl.y,
                "w": pl.span * bento.colW + (pl.span - 1) * bento.gap,
                // the last card of a column reaches the tallest one's end
                "extra": r.extra[k] || 0
            };
        });
        bento.places = out;
        // (only after a change made on the page: a page that builds or loads
        // content late never moves by itself once shown)
        const glide = eased === true && bento.settled && bento.frozen && Motion.glide.duration > 0;
        for (let i = 0; i < sections.count; i++) {
            const s = sections.itemAt(i);
            if (s && out[i])
                s.moveTo(out[i], glide);
        }
        bento.implicitHeight = r.height;
        bento.floor = r.floor;
    }
    function relayoutEased() {
        bento.relayout(true);
    }
    onColsChanged: Qt.callLater(bento.relayoutEased)
    onColWChanged: Qt.callLater(bento.relayout)

    Repeater {
        id: sections
        model: bento.category.sections

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
            exclude: bento.exclude
            pageKeys: bento.pageKeys
            pending: bento.rank[index] >= bento.builtSections
            height: implicitHeight + (card.place.extra || 0)

            // To a place: gliding (a discrete relayout) or at once. A
            // placement at once leaves alone a glide already heading there
            // (a fold under a gliding card).
            function moveTo(pl, glide) {
                const props = [["x", pl.x, ax], ["y", pl.y, ay], ["width", pl.w, aw]];
                props.forEach(p => {
                    const a = p[2];
                    if (glide && Math.abs(card[p[0]] - p[1]) > 0.5) {
                        a.stop();
                        a.to = p[1];
                        a.start();
                    } else if (!(a.running && a.to === p[1])) {
                        a.stop();
                        card[p[0]] = p[1];
                    }
                });
            }
            NumberAnimation {
                id: ax
                target: card
                property: "x"
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
            NumberAnimation {
                id: ay
                target: card
                property: "y"
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
            NumberAnimation {
                id: aw
                target: card
                property: "width"
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
            // a card that shows on a shown page fades in (built late, or
            // brought back by a setting)
            NumberAnimation {
                id: fadeIn
                target: card
                property: "opacity"
                from: 0
                to: 1
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
            // at once, in the same frame: a card that grows never paints
            // over the card under it
            onImplicitHeightChanged: bento.relayout()
            // just built (not brought back by a setting): built cards land
            // out of sight, they need no fade
            property bool fresh: false
            onPendingChanged: if (!card.pending) {
                card.fresh = true;
                Qt.callLater(() => card.fresh = false);
            }
            onVisibleChanged: {
                if (card.visible && bento.settled && bento.complete && !card.fresh && Motion.glide.duration > 0)
                    fadeIn.restart();
                Qt.callLater(bento.relayoutEased);
            }
            Component.onCompleted: {
                card.moveTo(card.place, false);
                Qt.callLater(bento.relayout);
            }
        }
    }
}
