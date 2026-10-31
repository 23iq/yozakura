pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// A kit ListRow the wizard selects or toggles: leading icon, title,
// subtitle and, at the end, a check mark (`mode: "check"`, the row is
// `selected` while checked), a Switch (`"toggle"`), a caret (`"link"`: opens
// something) or nothing (`"none"`, status-only rows). `badge` is a short
// status word before it. Tab focuses the row (focus ring), Enter / Space act.
ListRow {
    id: root

    property string icon: ""
    property string badge: ""
    property bool badgeOk: true
    property bool checked: false
    property string mode: "check"
    property bool dimmed: false

    signal toggled(bool value)

    // The whole row is the click target; a toggle row flips its switch.
    function activate() {
        if (!root.enabled || root.mode === "none")
            return;
        if (root.mode === "toggle")
            root.toggled(!root.checked);
        else
            root.clicked();
    }

    selected: root.checked && root.mode === "check"
    highlighted: root.activeFocus && FocusState.keyboard
    activeFocusOnTab: root.mode !== "none"
    opacity: !root.enabled ? 0.38 : (root.dimmed ? 0.55 : 1)
    onClicked: if (root.mode === "toggle")
        root.toggled(!root.checked)

    Keys.onSpacePressed: root.activate()
    Keys.onReturnPressed: root.activate()
    Keys.onEnterPressed: root.activate()

    leading: root.icon !== "" ? glyph : null
    trailing: end

    Component {
        id: glyph
        KitText {
            text: Icons[root.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: Type.iconSize("body")
            color: root.selected ? Type.accent : Type.secondary
        }
    }

    Component {
        id: end
        Row {
            spacing: Space.s
            KitText {
                visible: root.badge !== ""
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                text: root.badge
                color: root.badgeOk ? Type.secondary : Type.muted
            }
            Switch {
                visible: root.mode === "toggle"
                anchors.verticalCenter: parent.verticalCenter
                activeFocusOnTab: false
                enabled: root.enabled
                checked: root.checked
                onToggled: v => root.toggled(v)
            }
            KitText {
                visible: root.mode === "link" || (root.mode === "check" && root.checked)
                anchors.verticalCenter: parent.verticalCenter
                text: root.mode === "link" ? Icons.caretRight : Icons.accept
                font.family: Icons.font
                font.pixelSize: Type.iconSize("secondary")
                color: root.mode === "link" ? Type.secondary : Type.accent
            }
        }
    }

    FocusRing {
        shown: root.activeFocus
        radius: root.radius + Space.stroke
    }
}
