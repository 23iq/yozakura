pragma Singleton
import QtQuick
import qs.config
import qs.modules.theme
import "../../theme/TypeRoles.js" as TypeRoles

// Type roles and ink colors of the shared kit (modules/components/kit).
// Every text in the shell is one of six roles, sized from theme.fontSize:
//   display    ~3x, light, tabular numbers (clocks, big numbers)
//   title      1.3x, semibold, heading font
//   body       1x, regular
//   secondary  0.93x, overSurfaceVariant
//   caption    0.86x, outline (muted)
//   label      0.78x, semibold, UPPERCASE, tracked, muted: the section label
// The accent (primary) is reserved for active state, progress, today /
// selected and the single primary action of a surface; never decoration.
QtObject {
    id: root

    readonly property var roles: ["display", "title", "body", "secondary", "caption", "label"]
    readonly property real base: Config.theme.fontSize
    readonly property var scale: ({
            "display": 3,
            "title": 1.3,
            "body": 1,
            "secondary": 0.93,
            "caption": 0.86,
            "label": 0.78
        })

    readonly property string bodyFont: Styling.bodyFont
    readonly property string headingFont: Styling.headingFont

    // Colors
    readonly property color text: Colors.overBackground
    readonly property color secondary: Colors.overSurfaceVariant
    readonly property color muted: Colors.outline
    readonly property color hairline: Qt.rgba(Colors.overBackground.r, Colors.overBackground.g, Colors.overBackground.b, 0.08)
    readonly property color track: Qt.rgba(Colors.overBackground.r, Colors.overBackground.g, Colors.overBackground.b, 0.14)
    readonly property color placeholder: Qt.rgba(Colors.overBackground.r, Colors.overBackground.g, Colors.overBackground.b, 0.06)
    readonly property color accent: Colors.primary
    readonly property color onAccent: Colors.overPrimary

    function size(role: string): int {
        const f = root.scale[role];
        return Math.max(8, Math.round(root.base * (f === undefined ? 1 : f)));
    }

    function weight(role: string): int {
        if (role === "display")
            return Font.Light;
        if (role === "title" || role === "label")
            return Font.DemiBold;
        return Font.Normal;
    }

    function family(role: string): string {
        return role === "display" || role === "title" ? root.headingFont : root.bodyFont;
    }

    function color(role: string): color {
        if (role === "secondary")
            return root.secondary;
        if (role === "caption" || role === "label")
            return root.muted;
        return root.text;
    }

    function letterSpacing(role: string): real {
        return role === "label" ? Math.round(root.size("label") * 0.14 * 10) / 10 : 0;
    }

    // label UPPERCASE / title as typed, unless theme.type.headingCase sets a case
    function capitalization(role: string): int {
        switch (TypeRoles.capitalization(role, Config.theme.type ? Config.theme.type.headingCase : "none")) {
        case "upper":
            return Font.AllUppercase;
        case "lower":
            return Font.AllLowercase;
        case "capitalize":
            return Font.Capitalize;
        default:
            return Font.MixedCase;
        }
    }

    // Icon glyph size next to a role's text (Phosphor glyphs read ~1.2x).
    function iconSize(role: string): int {
        return Math.round(root.size(role) * 1.2);
    }
}
