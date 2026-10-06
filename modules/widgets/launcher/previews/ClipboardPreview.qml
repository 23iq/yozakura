import QtQuick
import qs.modules.theme
import qs.config

// Clipboard entry preview: the full text of the entry.
Flickable {
    id: preview

    property var result: null

    clip: true
    contentHeight: body.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    Text {
        id: body
        width: parent.width
        text: preview.result && preview.result.data ? String(preview.result.data.preview || "") : ""
        color: Colors.overBackground
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(0)
        wrapMode: Text.Wrap
    }
}
