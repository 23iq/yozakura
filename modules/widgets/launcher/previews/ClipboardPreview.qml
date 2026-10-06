import QtQuick
import qs.modules.components.kit

// Clipboard entry preview: the full text of the entry.
Flickable {
    id: preview

    property var result: null

    clip: true
    contentHeight: body.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    KitText {
        id: body
        width: parent.width
        role: "body"
        text: preview.result && preview.result.data ? String(preview.result.data.preview || "") : ""
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
}
