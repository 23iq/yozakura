import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// One quiet "name ... value" line of the page inspector (PageInspector):
// the name muted on the left, the value on the right; both wrap (translated
// text is never cut), the name in at most a little over half the line.
// `strong`: the value in the text ink.
Item {
    id: line

    property string name: ""
    property string value: ""
    property bool strong: false

    implicitHeight: Math.max(nameText.implicitHeight, valueText.implicitHeight)

    KitText {
        id: nameText
        width: Math.min(implicitWidth, line.width * 0.55)
        role: "secondary"
        color: Type.muted
        wrapMode: Text.WordWrap
        text: line.name
    }
    KitText {
        id: valueText
        x: line.width - width
        width: Math.min(implicitWidth, line.width - nameText.width - Space.m)
        role: "secondary"
        color: line.strong ? Type.text : Type.secondary
        horizontalAlignment: Text.AlignRight
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        text: line.value
    }
}
