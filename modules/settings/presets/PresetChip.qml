import QtQuick
import qs.modules.theme
import qs.config
import "../Ui.js" as Ui

// Small rounded label: preset tags, "Active", "Built-in", "Same as ...".
// `tone`: "neutral" (default), "primary" (filled accent), "soft" (tinted).
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property string tone: "neutral"
    property bool solid: false // over a thumbnail: opaque background

    readonly property color fg: tone === "primary" ? Colors.overPrimary : (tone === "soft" ? Colors.primary : Colors.overSurfaceVariant)

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 22
    radius: height / 2
    color: tone === "primary" ? Colors.primary : (tone === "soft" ? Ui.alpha(Colors.primary, solid ? 0.9 : 0.14) : (solid ? Colors.surfaceContainerHighest : Ui.alpha(Colors.overBackground, 0.07)))

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
        Text {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: Icons[root.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: 11
            color: root.solid && root.tone === "soft" ? Colors.overPrimary : root.fg
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-3)
            font.weight: Font.DemiBold
            color: root.solid && root.tone === "soft" ? Colors.overPrimary : root.fg
        }
    }
}
