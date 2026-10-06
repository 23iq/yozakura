import QtQuick
import qs.modules.components.kit

// Calculator / unit conversion preview: the full value, large (Copy is the
// main action of the detail pane).
Item {
    id: preview

    property var result: null
    readonly property string value: result && result.data ? String(result.data.value) : ""

    KitText {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        role: "display"
        text: preview.value
        wrapMode: Text.WrapAnywhere
        maximumLineCount: 2
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: Type.size("title")
    }
}
