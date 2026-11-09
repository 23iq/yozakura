import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// A glyph of the icon font (`icon: Icons.gear`) sized for the text role it
// sits next to (Type.iconSize(role)) in an ink colour:
//   tone  "text" | "secondary" | "muted" | "accent" | "progress" |
//         "accentInk" (on an accent fill) | "" (the colour of `role`)
// `size` > 0 is an explicit pixel size for glyphs that are not next to text
// (hero art placeholders); `color` can still be bound for one-off states.
//
//   Icon { icon: Icons.wifiHigh; role: "caption"; tone: "muted" }
Text {
    id: root

    property string icon: ""
    property string role: "body"
    property string tone: ""
    property int size: 0

    function inkOf(tone: string, role: string): color {
        switch (tone) {
        case "secondary":
            return Type.secondary;
        case "muted":
            return Type.muted;
        case "accent":
            return Type.accent;
        case "progress":
            return Type.progress;
        case "accentInk":
            return Type.accentInk;
        case "text":
            return Type.text;
        default:
            return Type.color(role);
        }
    }

    text: root.icon
    font.family: Icons.font
    font.pixelSize: root.size > 0 ? root.size : Type.iconSize(root.role)
    color: root.inkOf(root.tone, root.role)
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
