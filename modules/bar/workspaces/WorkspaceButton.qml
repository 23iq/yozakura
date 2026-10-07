import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.components.kit
import qs.modules.bar.look
import "WorkspaceSlot.js" as WorkspaceSlot
import "indicators/IndicatorStyles.js" as IndicatorStyles

// One slot of the bar's workspace strip: its number, a placeholder dot and
// the icon of the workspace's most recently focused window. Orientation
// agnostic; the parent layout decides which axis it stretches along.
Button {
    id: root
    objectName: "wsButton"

    required property int workspaceId
    required property bool active
    required property bool occupied
    required property real slotSize
    required property real iconSize
    required property real iconSizeShrinked
    required property real iconOpacityShrinked
    required property real iconMarginShrinked

    // Label color of the active slot: the kit's accent state (accent on the
    // pill's tint, the on-accent ink on a solid fill: tiles, classic, brush),
    // accent on the bar background (underline, dot, bracket styles).
    readonly property string indicatorStyle: Config.workspaces.indicatorStyle
    readonly property bool solidIndicator: IndicatorStyles.filled(root.indicatorStyle) && (root.indicatorStyle !== "pill" || Look.solidActive || BarLook.classic)
    readonly property color activeColor: root.solidIndicator ? Styling.srItem("primary") : Type.accent

    onPressed: YozdService.dispatch(`workspace ${root.workspaceId}`)

    background: Item {
        id: slot
        implicitWidth: root.slotSize
        implicitHeight: root.slotSize

        readonly property var focusedWindow: {
            const windowsInThisWorkspace = CompositorData.workspaceWindowsMap[root.workspaceId] || [];
            if (windowsInThisWorkspace.length === 0)
                return null;
            // Get the window with the lowest focusHistoryID (most recently focused)
            return windowsInThisWorkspace.reduce((best, win) => {
                const bestFocus = (best && best.focusHistoryID !== undefined ? best.focusHistoryID : Infinity);
                const winFocus = (win && win.focusHistoryID !== undefined ? win.focusHistoryID : Infinity);
                return winFocus < bestFocus ? win : best;
            }, null);
        }
        readonly property bool hasWindow: !!focusedWindow
        readonly property var focusedDesktopEntry: focusedWindow ? DesktopEntries.heuristicLookup(focusedWindow.class) : null
        readonly property var mainAppIconSource: {
            if (focusedDesktopEntry && focusedDesktopEntry.icon) {
                return Quickshell.iconPath(focusedDesktopEntry.icon, "image-missing");
            }
            return Quickshell.iconPath(AppSearch.getCachedIcon(focusedWindow ? focusedWindow.class : undefined), "image-missing");
        }
        readonly property bool iconFullSize: WorkspaceSlot.iconFullSize(Config.workspaces)

        WorkspaceNumberLabel {
            z: 3
            anchors.fill: parent
            workspaceId: root.workspaceId
            opacity: WorkspaceSlot.numberVisible(Config.workspaces, slot.hasWindow) ? 1 : 0
            color: root.active ? root.activeColor : (root.occupied ? Type.text : Type.muted)
        }

        Rectangle {
            opacity: WorkspaceSlot.dotOpacity(Config.workspaces, slot.hasWindow, root.active, root.occupied)
            visible: opacity > 0
            anchors.centerIn: parent
            width: root.slotSize * 0.2
            height: width
            radius: width / 2
            color: root.active ? root.activeColor : Type.text

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Motion.enter.duration
                    easing.type: Motion.enter.easing
                }
            }
        }

        Item {
            anchors.centerIn: parent
            width: root.slotSize
            height: root.slotSize
            opacity: WorkspaceSlot.iconOpacity(Config.workspaces, slot.hasWindow, root.iconOpacityShrinked)
            visible: opacity > 0

            IconImage {
                id: mainAppIcon
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.bottomMargin: slot.iconFullSize ? Math.round((root.slotSize - root.iconSize) / 2) : root.iconMarginShrinked
                anchors.rightMargin: slot.iconFullSize ? Math.round((root.slotSize - root.iconSize) / 2) : root.iconMarginShrinked

                source: slot.mainAppIconSource
                implicitSize: slot.iconFullSize ? root.iconSize : root.iconSizeShrinked

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Motion.enter.duration
                        easing.type: Motion.enter.easing
                    }
                }
                Behavior on anchors.bottomMargin {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Motion.morph.duration
                        easing.type: Motion.morph.easing
                    }
                }
                Behavior on anchors.rightMargin {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Motion.morph.duration
                        easing.type: Motion.morph.easing
                    }
                }
                Behavior on implicitSize {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Motion.morph.duration
                        easing.type: Motion.morph.easing
                    }
                }
            }

            Tinted {
                sourceItem: mainAppIcon
                anchors.fill: mainAppIcon
            }
        }
    }
}
