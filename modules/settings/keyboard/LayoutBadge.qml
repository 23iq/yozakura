import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../Ui.js" as Ui
import "../../services/KeyboardModel.js" as KeyboardModel
import qs.modules.components.kit

// Square code badge of a layout (EN, RU, DE...). `lit` tints it with the
// accent (the layout in use).
Rectangle {
    id: root

    property string code: ""
    property bool lit: false

    width: 44
    height: 44
    radius: Look.radius("box")
    color: lit ? Ui.alpha(Colors.primary, 0.24) : Ui.alpha(Colors.overBackground, 0.08)
    border.width: 1
    border.color: lit ? Ui.alpha(Colors.primary, 0.6) : Ui.alpha(Colors.outline, 0.3)

    KitText {
        anchors.centerIn: parent
        text: KeyboardModel.shortName(root.code)
        font.weight: Font.Bold
        font.letterSpacing: 0.5
        color: root.lit ? Colors.primary : Colors.overBackground
    }
}
