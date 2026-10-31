import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// The wizard's tabs [{id, icon, label}] (icon: an Icons name) as a kit
// Segmented the keyboard reaches: Tab focuses it (focus ring), Left / Right
// switch tabs. `picked(id)` on a click or a key; the step owns `current`.
Segmented {
    id: root

    property var tabs: []
    property string current: ""
    signal picked(string id)

    model: root.tabs.map(t => ({
                "name": "tab:" + t.id,
                "icon": Icons[t.icon] ?? "",
                "text": t.label
            }))
    currentIndex: Math.max(0, root.tabs.findIndex(t => t.id === root.current))
    activeFocusOnTab: true
    onActivated: index => root.step(index - root.currentIndex)

    function step(delta: int) {
        const i = root.currentIndex + delta;
        if (i >= 0 && i < root.tabs.length)
            root.picked(root.tabs[i].id);
    }

    Keys.onLeftPressed: root.step(-1)
    Keys.onRightPressed: root.step(1)

    FocusRing {
        shown: root.activeFocus
        radius: Look.bigRadius(root.height) + Space.stroke
    }
}
