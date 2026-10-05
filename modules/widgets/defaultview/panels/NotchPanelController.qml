import QtQuick
import qs.config
import "NotchPanels.js" as NotchPanels

// Which notch panel is open (see NotchPanels.js). Owns only pointer and
// click timing; the view decides how panels look.
//
// hover mode: resting on a segment (`hoverTarget`, a panel id) for
//   notch.hoverExpandDelay opens its panel; moving to another segment
//   switches after the same delay (so crossing the title on the way down
//   does not flip panels); leaving everything (`hold` false) closes after
//   notch.hoverCollapseDelay.
// click mode: toggle(id) opens/switches/closes; close() closes.
// auto panels (registry `auto`) open by themselves as soon as they are
//   available and take precedence over hover/click until they become
//   unavailable or are dismissed (close()), which keeps them closed until
//   their content goes away and comes back.
// Either way a panel closes as soon as it becomes unavailable or the view
// is suspended (launcher/dashboard transitions). Closing a panel that is
// still available (close(), suspension) emits dismissed(id).
Item {
    id: controller

    property string mode: "hover"
    // Panel id under the pointer ("" when none)
    property string hoverTarget: ""
    // Pointer inside the open panel or one of its menus
    property bool hold: false
    property bool suspended: false
    // { panelId: bool }
    property var available: ({})

    property string openPanel: ""
    readonly property bool expanded: controller.openPanel !== ""
    // The open panel takes keyboard focus / click-outside (registry `modal`)
    readonly property bool modal: controller.expanded && NotchPanels.isModal(controller.openPanel)
    // An auto panel is open (the notch must show itself)
    readonly property bool autoOpen: controller.expanded && NotchPanels.isAuto(controller.openPanel)

    // Auto panel the user dismissed; stays closed until it is unavailable
    property string dismissedAuto: ""
    readonly property string autoTarget: controller.suspended ? "" : NotchPanels.autoPanel(controller.available, controller.dismissedAuto)

    readonly property bool clickMode: NotchPanels.expandMode(controller.mode) === "click"
    readonly property string target: !controller.clickMode && !controller.suspended && controller.autoTarget === "" && controller.available[controller.hoverTarget] ? controller.hoverTarget : ""

    // A panel was closed while its content was still there (Esc, click
    // outside, suspension)
    signal dismissed(string id)

    // Registry access for the view (NotchPanels.js)
    readonly property var panels: NotchPanels.PANELS
    function panelFor(trigger) {
        return NotchPanels.panelFor(trigger);
    }
    function urlFor(entry) {
        return Qt.resolvedUrl(entry.url);
    }
    function widthFor(id, fallback) {
        return NotchPanels.widthFor(id, fallback);
    }
    function availability(ctx) {
        return NotchPanels.availability(ctx);
    }

    function toggle(id) {
        if (controller.suspended || controller.autoTarget !== "")
            return;
        controller.openPanel = NotchPanels.toggled(controller.openPanel, id, controller.available);
    }

    function close() {
        const id = controller.openPanel;
        if (id === "")
            return;
        if (NotchPanels.isAuto(id))
            controller.dismissedAuto = id;
        // Before closing: the panel is unloaded as soon as it is hidden
        if (controller.available[id])
            controller.dismissed(id);
        controller.openPanel = "";
    }

    function validate() {
        if (controller.dismissedAuto !== "" && !controller.available[controller.dismissedAuto])
            controller.dismissedAuto = "";
        if (controller.autoTarget !== "") {
            controller.openPanel = controller.autoTarget;
            return;
        }
        if (controller.suspended && controller.expanded) {
            controller.close();
            return;
        }
        if (controller.expanded && !controller.available[controller.openPanel])
            controller.openPanel = "";
    }

    onSuspendedChanged: controller.validate()
    onAvailableChanged: controller.validate()
    onAutoTargetChanged: controller.validate()
    onClickModeChanged: {
        if (!controller.autoOpen)
            controller.openPanel = "";
    }

    // Open / switch after a deliberate rest on a segment
    Timer {
        interval: Math.max(0, Config.notch.hoverExpandDelay)
        running: controller.target !== "" && controller.target !== controller.openPanel
        onTriggered: controller.openPanel = controller.target
    }
    // Close once the pointer left the segments and the panel
    Timer {
        interval: Math.max(0, Config.notch.hoverCollapseDelay)
        running: !controller.clickMode && controller.expanded && !controller.autoOpen && controller.target === "" && !controller.hold
        onTriggered: controller.openPanel = ""
    }
}
