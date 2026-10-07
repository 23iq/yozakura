import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.bar.look
import "../../specials/Specials.js" as Specials

Item {
    id: workspacesWidget
    required property var bar
    required property string orientation
    readonly property var monitor: YozdService.monitorFor(bar.screen)
    readonly property string specialWorkspaceName: Config.workspaces.showSpecialWorkspace ? (CompositorData.specialWorkspaceNames[bar.screen.name] || "") : ""
    readonly property bool specialWorkspaceActive: specialWorkspaceName.length > 0
    // A configured special (modules/specials) shows its own name and icon.
    readonly property var specialItem: specialWorkspaceActive && Config.specials.enabled ? Specials.byHyprName(Config.specials.workspaces, specialWorkspaceName) : null
    readonly property string specialLabel: specialItem ? specialItem.name : specialWorkspaceName
    readonly property string specialGlyph: specialItem ? (Icons[specialItem.icon] || "") : ""
    property real specialBlur: specialWorkspaceActive && !workspaceHover.hovered ? 1 : 0

    Behavior on specialBlur {
        NumberAnimation {
            duration: Config.animDuration > 0 ? Math.max(0, Config.workspaces.specialWorkspaceAnimationDuration) : 0
            easing.type: Easing.OutQuad
        }
    }

    HoverHandler {
        id: workspaceHover
    }

    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

    // Niri's workspaces are created and destroyed on demand, so the
    // dynamic (occupied-only) model is the only one that makes sense
    // there. Forced on regardless of the persisted config value.
    readonly property bool dynamicMode: Config.workspaces.dynamic || YozdService.compositorName === "niri"

    readonly property int workspaceGroup: Math.floor(((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) - 1 || 0) / Config.workspaces.shown)
    property var workspaceOccupied: []
    property var dynamicWorkspaceIds: []
    property int effectiveWorkspaceCount: dynamicMode ? Math.max(dynamicWorkspaceIds.length, workspaceIndexInGroup + 1) : Config.workspaces.shown
    property int widgetPadding: 4
    property real radius: Styling.radius(0)
    property real startRadius: radius
    property real endRadius: radius

    property int baseSize: BarMetrics.moduleSize
    // Bar panels: no pill background of its own
    property bool flat: false
    property int workspaceButtonSize: baseSize - widgetPadding * 2
    property int workspaceButtonWidth: workspaceButtonSize
    property real workspaceIconSize: Math.floor(workspaceButtonWidth * 0.6)
    property real workspaceIconSizeShrinked: Math.round(workspaceButtonWidth * 0.5)
    property real workspaceIconOpacityShrinked: 1
    property real workspaceIconMarginShrinked: -4
    readonly property int activeWorkspaceId: (monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) || 1

    // Sorted position the active workspace will occupy once the dynamic
    // list catches up. A workspace niri just created isn't in the list
    // yet (100ms refresh debounce); indexOf would return -1 there and
    // drag the stretchy highlight to an out-of-bounds slot first.
    property int workspaceIndexInGroup: {
        if (!dynamicMode) {
            return ((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) - 1 || 0) % Config.workspaces.shown;
        }
        const idx = dynamicWorkspaceIds.indexOf(activeWorkspaceId);
        if (idx >= 0) {
            return idx;
        }
        let insert = 0;
        for (let i = 0; i < dynamicWorkspaceIds.length; i++) {
            if (dynamicWorkspaceIds[i] < activeWorkspaceId) {
                insert = i + 1;
            } else {
                break;
            }
        }
        return insert;
    }
    property var occupiedRanges: []

    function updateWorkspaceOccupied() {
        if (dynamicMode) {
            // Get occupied workspace IDs using the precomputed occupation map, sorted and limited by 'shown'
            const occupiedIds = YozdService.workspaces.values.filter(ws => !String(ws.name || "").startsWith("special:") && CompositorData.workspaceOccupationMap[ws.id]).map(ws => ws.id).sort((a, b) => a - b).slice(0, Config.workspaces.shown);

            // Always include active workspace, even if empty
            const activeId = (monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) || 1;
            if (!occupiedIds.includes(activeId)) {
                occupiedIds.push(activeId);
                occupiedIds.sort((a, b) => a - b);
                if (occupiedIds.length > Config.workspaces.shown) {
                    occupiedIds.pop();
                }
            }

            dynamicWorkspaceIds = occupiedIds;
            workspaceOccupied = Array.from({
                length: dynamicWorkspaceIds.length
            }, (_, i) => CompositorData.workspaceOccupationMap[dynamicWorkspaceIds[i]]);
        } else {
            workspaceOccupied = Array.from({
                length: Config.workspaces.shown
            }, (_, i) => {
                const wsId = workspaceGroup * Config.workspaces.shown + i + 1;
                return CompositorData.workspaceOccupationMap[wsId];
            });
        }
        updateOccupiedRanges();
    }

    function updateOccupiedRanges() {
        const ranges = [];
        let rangeStart = -1;

        for (let i = 0; i < effectiveWorkspaceCount; i++) {
            const isOccupied = workspaceOccupied[i];

            if (isOccupied) {
                if (rangeStart === -1) {
                    rangeStart = i;
                }
            } else {
                if (rangeStart !== -1) {
                    ranges.push({
                        start: rangeStart,
                        end: i - 1
                    });
                    rangeStart = -1;
                }
            }
        }

        if (rangeStart !== -1) {
            ranges.push({
                start: rangeStart,
                end: effectiveWorkspaceCount - 1
            });
        }

        occupiedRanges = ranges;
    }

    // Matches only the monitor's real active workspace (no fallback to 1).
    function isMonitorWorkspace(id) {
        return !!(monitor && monitor.activeWorkspace) && Number(monitor.activeWorkspace.id) === id;
    }

    function getWorkspaceId(index) {
        if (dynamicMode) {
            // Pending slot: the active workspace niri just created, not
            // yet in the refreshed dynamic list.
            if (index >= dynamicWorkspaceIds.length) {
                return activeWorkspaceId;
            }
            return dynamicWorkspaceIds[index] || 1;
        }
        return workspaceGroup * Config.workspaces.shown + index + 1;
    }

    Timer {
        id: updateTimer
        interval: 100
        repeat: false
        onTriggered: workspacesWidget.updateWorkspaceOccupied()
    }

    // Initial update
    Component.onCompleted: updateTimer.restart()

    Connections {
        target: YozdService.workspaces
        function onValuesChanged() {
            updateTimer.restart();
        }
    }

    Connections {
        target: activeWindow
        function onActivatedChanged() {
            updateTimer.restart();
        }
    }

    Connections {
        target: CompositorData
        function onWindowListChanged() {
            updateTimer.restart();
        }
    }

    onWorkspaceGroupChanged: {
        updateTimer.restart();
    }

    onDynamicModeChanged: {
        updateTimer.restart();
    }

    implicitWidth: orientation === "vertical" ? baseSize : workspaceButtonSize * effectiveWorkspaceCount + widgetPadding * 2
    implicitHeight: orientation === "vertical" ? workspaceButtonSize * effectiveWorkspaceCount + widgetPadding * 2 : baseSize

    readonly property bool effectiveContainBar: Config.bar.containBar && ((Config.bar.frameEnabled !== undefined ? Config.bar.frameEnabled : false))
    property bool shadowEnabled: Config.showBackground && (!effectiveContainBar || Config.bar.keepBarShadow)

    ModuleBox {
        id: bgRect
        vertical: orientation === "vertical"
        startRadius: workspacesWidget.startRadius
        endRadius: workspacesWidget.endRadius
        flat: workspacesWidget.flat
        shadow: workspacesWidget.shadowEnabled
    }

    WheelHandler {
        onWheel: event => {
            if (event.angleDelta.y < 0)
                YozdService.dispatch(`workspace r+1`);
            else if (event.angleDelta.y > 0)
                YozdService.dispatch(`workspace r-1`);
        }
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        onPressed: event => {
            if (event.button === Qt.BackButton) {
                YozdService.dispatch(`togglespecialworkspace`);
            }
        }
    }

    Item {
        id: regularWorkspaces
        anchors.fill: parent
        scale: 1 - 0.08 * workspacesWidget.specialBlur
        layer.enabled: workspacesWidget.specialBlur > 0
        layer.smooth: true
        layer.effect: MultiEffect {
            brightness: -0.1 * workspacesWidget.specialBlur
            blurEnabled: true
            blur: workspacesWidget.specialBlur
            blurMax: 32
        }
    }

    OccupiedRanges {
        parent: regularWorkspaces
        z: 1
        anchors.fill: parent
        anchors.margins: widgetPadding
        vertical: workspacesWidget.orientation === "vertical"
        ranges: workspacesWidget.occupiedRanges
        slot: workspacesWidget.workspaceButtonWidth
        radius: workspacesWidget.startRadius > 0 ? Math.max(workspacesWidget.startRadius - widgetPadding, 0) : 0
    }

    // Active workspace indicator (style: workspaces.indicatorStyle)
    ActiveIndicator {
        id: activeIndicator
        objectName: "activeIndicator"
        parent: regularWorkspaces
        z: 2
        vertical: workspacesWidget.orientation === "vertical"
        index: workspacesWidget.workspaceIndexInGroup
        slotSize: workspacesWidget.workspaceButtonWidth
        padding: workspacesWidget.widgetPadding
        occupied: !!CompositorData.workspaceOccupationMap[workspacesWidget.activeWorkspaceId]
        baseRadius: workspacesWidget.radius
        workspaceId: workspacesWidget.activeWorkspaceId
    }

    // Slot bindings shared by both orientations.
    component SlotButton: WorkspaceButton {
        required property int index
        workspaceId: workspacesWidget.getWorkspaceId(index)
        active: workspacesWidget.isMonitorWorkspace(workspaceId)
        occupied: !!workspacesWidget.workspaceOccupied[index]
        slotSize: workspacesWidget.workspaceButtonWidth
        iconSize: workspacesWidget.workspaceIconSize
        iconSizeShrinked: workspacesWidget.workspaceIconSizeShrinked
        iconOpacityShrinked: workspacesWidget.workspaceIconOpacityShrinked
        iconMarginShrinked: workspacesWidget.workspaceIconMarginShrinked
    }

    RowLayout {
        id: rowLayoutNumbers
        parent: regularWorkspaces
        visible: workspacesWidget.orientation === "horizontal"
        z: 3

        spacing: 0
        anchors.fill: parent
        anchors.margins: workspacesWidget.widgetPadding
        implicitHeight: workspacesWidget.workspaceButtonWidth

        Repeater {
            model: workspacesWidget.effectiveWorkspaceCount

            SlotButton {
                Layout.fillHeight: true
                width: workspacesWidget.workspaceButtonWidth
            }
        }
    }

    ColumnLayout {
        id: columnLayoutNumbers
        parent: regularWorkspaces
        visible: workspacesWidget.orientation === "vertical"
        z: 3

        spacing: 0
        anchors.fill: parent
        anchors.margins: workspacesWidget.widgetPadding
        implicitWidth: workspacesWidget.workspaceButtonWidth

        Repeater {
            model: workspacesWidget.effectiveWorkspaceCount

            SlotButton {
                Layout.fillWidth: true
                height: workspacesWidget.workspaceButtonWidth
            }
        }
    }

    StyledRect {
        id: specialWorkspaceBadge
        animateRadius: false
        anchors.centerIn: parent
        variant: "primary"
        z: 4
        visible: opacity > 0
        opacity: workspacesWidget.specialBlur
        scale: 0.8 + 0.2 * workspacesWidget.specialBlur
        readonly property real labelWidth: specialWorkspaceText.implicitWidth + (specialWorkspaceGlyph.visible ? specialWorkspaceGlyph.implicitWidth + 6 : 0)
        width: orientation === "vertical" ? workspaceButtonWidth : Math.min(workspacesWidget.width - widgetPadding * 2, labelWidth + workspaceButtonWidth)
        height: orientation === "vertical" ? Math.min(workspacesWidget.height - widgetPadding * 2, labelWidth + workspaceButtonWidth) : workspaceButtonWidth
        radius: Math.min(width, height) / 2
        border.width: 1
        border.color: workspacesWidget.specialItem ? (Colors[workspacesWidget.specialItem.accent] ?? Colors.primary) : Colors.primary

        Row {
            anchors.centerIn: parent
            rotation: orientation === "vertical" ? -90 : 0
            spacing: 6

            Text {
                id: specialWorkspaceGlyph
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: workspacesWidget.specialGlyph
                font.family: Icons.font
                font.pixelSize: Config.theme.fontSize
                color: Styling.srItem("primary")
            }

            Text {
                id: specialWorkspaceText
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, (orientation === "vertical" ? specialWorkspaceBadge.height : specialWorkspaceBadge.width) - widgetPadding * 2 - (specialWorkspaceGlyph.visible ? specialWorkspaceGlyph.implicitWidth + 6 : 0))
                text: workspacesWidget.specialLabel
                color: Styling.srItem("primary")
                font.family: Config.workspaces.specialWorkspaceFont || Qt.application.font.family
                font.weight: Qt.application.font.weight
                font.pixelSize: Config.theme.fontSize
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }
}
