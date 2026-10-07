pragma Singleton
import QtQuick
import qs.config
import qs.modules.components.kit
import "BarLookRules.js" as Rules

// How bar modules draw with the shared kit (modules/components/kit), so every
// bar style (strip, floating, islands, pills, dock-like) on every edge reads
// as the same family as the rest of the shell:
//   text     Type roles: "body" on regular bars, "secondary" on dense ones
//            (module size < 32), the language's label weight
//   glyphs   Type.iconSize("body"), scaled gently with the module size
//   groups   a run of modules sits on the language's group box (ModuleBox):
//            ink none, glass a frosted card, tiles a solid tile; on a
//            transparent bar the group box is the theme's "bg" pill; classic
//            keeps that pill and its shadow exactly as configured
//   states   hover = the language's control hover, active (popup open,
//            pinned, current workspace) = the kit's accent state (KitStates)
QtObject {
    id: root

    readonly property bool classic: Look.language === "classic"
    readonly property real denseBelow: 32
    // A visible strip / pill / frame under the modules (BarLookRules)
    readonly property bool barSurface: Rules.barSurface(Config.theme.srBarBg ? Config.theme.srBarBg.opacity : 0, Config.bar.containBar, Config.bar.frameEnabled)

    function restLook(flat: bool): string {
        return Rules.restLook(Look.language, flat, root.barSurface, Look.group.fillOpacity >= 1);
    }

    function textRole(moduleSize: real): string {
        return Rules.textRole(moduleSize, root.denseBelow);
    }

    function textSize(moduleSize: real): int {
        return Type.size(root.textRole(moduleSize));
    }

    // Module labels (clock, window menu, layouts): one weight per language
    readonly property int textWeight: root.classic ? Font.Medium : Look.activeLabelWeight
    readonly property string textFont: Type.bodyFont

    function iconSize(moduleSize: real): int {
        return Rules.iconSize(Type.iconSize("body"), moduleSize);
    }

    // Corner radius of a group box: square languages keep tiles tight
    function groupRadius(r: real): real {
        return Look.squareControls ? Math.min(r, Space.smallRadius) : r;
    }

    // Ink of a module's content in a KitStates look
    function ink(look: string): color {
        if (look === "primary")
            return Type.accentInk;
        return look === "active" ? Type.accent : Type.text;
    }
}
