pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services.activities
import qs.modules.bar.activities
import "../activities/ActivityChips.js" as Chips
import "../../widgets/defaultview/activities/ActivityRegistry.js" as Registry
import "../../widgets/defaultview/panels/NotchPanels.js" as NotchPanels

// Live activities as chips in the bar (ActivityService.presentation "bar":
// the notch shares the bar's edge, notch.activitiesIn). BarContent puts it
// first in the end group of the panel on the notch's edge; it grows from
// nothing with one Motion.morph and folds away when the last activity ends.
// Hovering a chip opens its notch panel in a popup anchored to it (after
// notch.hoverExpandDelay); leaving chip and popup closes it after
// notch.hoverCollapseDelay; a click pins it (again: unpins).
BarModuleBase {
    id: root

    moduleKey: "activities"

    readonly property bool on: ActivityService.presentation === "bar"
    readonly property var model: root.on ? Chips.chips(ActivityService.activities, ActivityService.maxVisible) : ({
            shown: [],
            overflow: 0
        })
    readonly property var registry: Registry.resolve(Config.notch ? Config.notch.activities : [])
    readonly property var available: NotchPanels.availability(Chips.context(ActivityService))
    readonly property string screenName: root.bar && root.bar.screen ? root.bar.screen.name : ""

    // Length along the bar: the chips' run, animated with the bar's morph
    readonly property real targetLength: root.model.shown.length > 0 ? (root.vertical ? strip.implicitHeight : strip.implicitWidth) : 0
    property real shownLength: root.targetLength
    Behavior on shownLength {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    contentLength: root.shownLength
    // Folded away: the slot leaves the layout (BarModuleSlot)
    readonly property bool collapsed: root.shownLength < 0.5

    // ── Popup state ──
    property string hoverChip: ""
    property var hoverActivity: null
    property Item hoverItem: null
    property string openChip: ""
    property bool pinned: false
    property string quietChip: ""
    onHoverChipChanged: if (root.hoverChip !== root.quietChip)
        root.quietChip = ""
    readonly property string hoverPanel: Chips.panelFor(root.hoverActivity, root.registry, root.available)
    readonly property bool held: Chips.held(root.pinned, root.hoverChip !== "", popup.hovered)

    function show(key, activity, item, pin) {
        const panel = Chips.panelFor(activity, root.registry, root.available);
        if (panel === "")
            return false;
        root.openChip = key;
        root.pinned = pin;
        popup.panelId = panel;
        popup.anchorItem = item;
        if (popup.isOpen)
            popup.measure();
        else
            popup.open();
        return true;
    }
    function hide() {
        root.openChip = "";
        root.pinned = false;
        popup.close();
    }
    function chipClicked(key, activity, item, button) {
        if (button === Qt.LeftButton && Chips.panelFor(activity, root.registry, root.available) !== "") {
            const s = Chips.clicked({
                chip: root.pinned ? root.openChip : "",
                pinned: root.pinned
            }, key);
            if (s.pinned) {
                root.show(key, activity, item, true);
            } else {
                root.hide();
                // Unpinned under the pointer: no hover re-open until it leaves
                root.quietChip = key;
            }
            return;
        }
        ActivityService.activate(activity, button, root.screenName);
    }

    Timer {
        id: openTimer
        interval: Math.max(0, Config.notch ? Config.notch.hoverExpandDelay : 90)
        running: !root.pinned && root.hoverPanel !== "" && root.hoverChip !== root.openChip && root.hoverChip !== root.quietChip
        onTriggered: root.show(root.hoverChip, root.hoverActivity, root.hoverItem, false)
    }
    Timer {
        interval: Math.max(0, Config.notch ? Config.notch.hoverCollapseDelay : 200)
        running: popup.isOpen && !root.held
        onTriggered: root.hide()
    }
    // The panel's content went away (download finished, mic released)
    onAvailableChanged: if (popup.isOpen && !root.available[popup.panelId])
        root.hide()

    BarModuleSurface {
        id: surface
        module: root
        hovered: root.hoverChip !== ""
        active: popup.isOpen
    }

    // The module reveals the strip (pinned to its start) while growing
    Item {
        anchors.fill: parent
        clip: true

        Grid {
            id: strip
            objectName: "activityChipStrip"
            columns: root.vertical ? 1 : 99
            spacing: 0

            Repeater {
                model: root.model.shown
                delegate: ActivityChip {
                    id: chip
                    required property var modelData
                    objectName: "activityChip:" + chip.modelData.id
                    activity: chip.modelData
                    vertical: root.vertical
                    moduleSize: root.moduleSize
                    glyphSize: root.iconSize
                    ink: surface.foreground
                    onHoveredChanged: {
                        if (chip.hovered) {
                            root.hoverChip = chip.modelData.id;
                            root.hoverActivity = chip.modelData;
                            root.hoverItem = chip;
                        } else if (root.hoverChip === chip.modelData.id) {
                            root.hoverChip = "";
                            root.hoverActivity = null;
                        }
                    }
                    TapHandler {
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onTapped: (point, button) => root.chipClicked(chip.modelData.id, chip.modelData, chip, button)
                    }
                }
            }
            ActivityChip {
                visible: root.model.overflow > 0
                overflowCount: root.model.overflow
                vertical: root.vertical
                moduleSize: root.moduleSize
                glyphSize: root.iconSize
                ink: surface.foreground
            }
        }
    }

    ActivityChipPopup {
        id: popup
        anchorItem: root
        bar: root.bar
        screenName: root.screenName
        pinned: root.pinned
        onClosedExternally: {
            root.openChip = "";
            root.pinned = false;
        }
    }
}
