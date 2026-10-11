import QtQuick

// Wrapping row of items whose every line is centred (Flow only left-aligns).
// Items are positioned by hand from their implicit widths; the height is
// the sum of the lines.
Item {
    id: root

    default property alias content: holder.data
    readonly property var items: holder.children
    property real spacing: 8
    property real rowSpacing: spacing

    implicitHeight: 0

    function layoutRows() {
        const items = [];
        for (let i = 0; i < holder.children.length; i++) {
            const c = holder.children[i];
            const w = c.implicitWidth > 0 ? c.implicitWidth : c.width;
            if (c.visible && w > 0)
                items.push({
                    item: c,
                    w: Math.min(w, root.width)
                });
        }
        let y = 0;
        let start = 0;
        while (start < items.length) {
            let end = start;
            let rowW = 0;
            let rowH = 0;
            while (end < items.length && (end === start || rowW + root.spacing + items[end].w <= root.width)) {
                rowW += (end === start ? 0 : root.spacing) + items[end].w;
                rowH = Math.max(rowH, items[end].item.implicitHeight > 0 ? items[end].item.implicitHeight : items[end].item.height);
                end++;
            }
            let x = (root.width - rowW) / 2;
            for (let k = start; k < end; k++) {
                const it = items[k].item;
                const h = it.implicitHeight > 0 ? it.implicitHeight : it.height;
                it.x = Math.round(x);
                it.y = Math.round(y + (rowH - h) / 2);
                x += items[k].w + root.spacing;
            }
            y += rowH + root.rowSpacing;
            start = end;
        }
        implicitHeight = Math.max(0, y - root.rowSpacing);
    }

    onWidthChanged: Qt.callLater(layoutRows)
    Component.onCompleted: Qt.callLater(layoutRows)

    Item {
        id: holder
        anchors.fill: parent
        onChildrenChanged: Qt.callLater(root.layoutRows)
    }
}
