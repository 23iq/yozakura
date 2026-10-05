import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.desktop
import qs.modules.desktop.widgets
import qs.modules.bar.workspaces
import qs.modules.services
import qs.modules.theme
import qs.config
import qs.modules.globals
import qs.modules.bar.panels

PanelWindow {
    id: desktop

    property int barSize: Config.showBackground ? 44 : 40
    property int bottomTextMargin: 32
    property string barPosition: Panels.primaryEdge

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"

    // Icons (desktop.enabled) and/or widgets (DesktopWidgets). Edit desktop
    // mode lifts the layer above windows so the widgets can be arranged
    // with anything open.
    readonly property bool iconsEnabled: Config.desktop.enabled ?? false
    readonly property bool editing: DesktopWidgets.editMode

    WlrLayershell.layer: editing ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.namespace: Brand.namespace("desktop")
    // On demand: a note widget (or Esc in edit mode) gets keys after a click.
    WlrLayershell.keyboardFocus: editing || DesktopWidgets.widgets.length > 0 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    visible: iconsEnabled || DesktopWidgets.wanted

    onIconsEnabledChanged: {
        if (iconsEnabled)
            DesktopService.initialize();
    }

    Component.onCompleted: {
        if (iconsEnabled)
            DesktopService.initialize();
        DesktopService.maxRowsHint = Qt.binding(() => iconContainer.maxRows);
        DesktopService.maxColumnsHint = Qt.binding(() => iconContainer.maxColumns);
    }

    // Right click on the bare desktop: arrange widgets.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        enabled: !desktop.editing && (Config.desktop.widgetsEnabled ?? true)
        onClicked: Visibilities.contextMenu.openCustomMenu([
            {
                text: I18n.t("desktop.widgets.edit"),
                icon: Icons.widgets,
                isSeparator: false,
                onTriggered: function () {
                    DesktopWidgets.editMode = true;
                }
            }
        ], 200, 32, "desktop")
    }

    Item {
        id: iconContainer
        visible: desktop.iconsEnabled
        anchors.fill: parent
        anchors.margins: 16
        anchors.bottomMargin: desktop.barPosition === "bottom" ? desktop.barSize + 16 : 16
        anchors.topMargin: desktop.barPosition === "top" ? desktop.barSize + 16 : 16
        anchors.leftMargin: desktop.barPosition === "left" ? desktop.barSize + 16 : 16
        anchors.rightMargin: desktop.barPosition === "right" ? desktop.barSize + 16 : 16

        property int cellHeight: Config.desktop.iconSize + 40 + Config.desktop.spacingVertical
        property int cellWidth: cellHeight
        property int maxRows: Math.floor(height / cellHeight)
        property int maxColumns: Math.floor(width / cellWidth)

        Repeater {
            model: DesktopService.items

            delegate: Item {
                id: delegateRoot
                required property string name
                required property string path
                required property string type
                required property string icon
                required property bool isDesktopFile
                required property bool isPlaceholder
                required property int index

                width: iconContainer.cellWidth
                height: iconContainer.cellHeight

                x: Math.floor(index / iconContainer.maxRows) * iconContainer.cellWidth
                y: (index % iconContainer.maxRows) * iconContainer.cellHeight

                visible: !isPlaceholder

                Behavior on x {
                    enabled: !dragHandler.active && Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on y {
                    enabled: !dragHandler.active && Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                DesktopIcon {
                    id: iconItem
                    anchors.fill: parent

                    itemName: delegateRoot.name
                    itemPath: delegateRoot.path
                    itemType: delegateRoot.type
                    itemIcon: delegateRoot.icon
                    isDesktopFile: delegateRoot.isDesktopFile

                    onActivated: {
                        console.log("Activated:", itemName);
                    }

                    onContextMenuRequested: {
                        console.log("Context menu requested for:", itemName);
                        Visibilities.contextMenu.openCustomMenu([
                            {
                                text: I18n.t("desktop.open"),
                                icon: Icons.launch,
                                isSeparator: false,
                                onTriggered: function () {
                                    if (delegateRoot.isDesktopFile) {
                                        DesktopService.executeDesktopFile(delegateRoot.path);
                                    } else {
                                        DesktopService.openFile(delegateRoot.path);
                                    }
                                }
                            },
                            {
                                isSeparator: true,
                                text: ""
                            },
                            {
                                text: I18n.t("desktop.delete"),
                                icon: Icons.trash,
                                textColor: Colors.overError,
                                highlightColor: Colors.error,
                                isSeparator: false,
                                onTriggered: function () {
                                    DesktopService.trashFile(delegateRoot.path);
                                }
                            }
                        ], 160, 32, "desktop");
                    }

                    opacity: dragHandler.active ? 0.3 : 1.0

                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutCubic
                        }
                    }

                    DragHandler {
                        id: dragHandler
                        target: dragPreview
                        onActiveChanged: {
                            if (!active) {
                                var targetIndex = delegateRoot.index;

                                console.log("Drop - Drag.target:", dragPreview.Drag.target);

                                if (dragPreview.Drag.target && dragPreview.Drag.target.visualIndex !== undefined) {
                                    targetIndex = dragPreview.Drag.target.visualIndex;
                                    console.log("Using Drag.target visualIndex:", targetIndex);
                                } else {
                                    var gridPos = iconContainer.mapFromItem(dragPreview.parent, dragPreview.x, dragPreview.y);
                                    var dropX = gridPos.x + dragPreview.width / 2;
                                    var dropY = gridPos.y + dragPreview.height / 2;

                                    if (dropX >= 0 && dropY >= 0 && dropX < iconContainer.width && dropY < iconContainer.height) {
                                        var col = Math.floor(dropX / iconContainer.cellWidth);
                                        var row = Math.floor(dropY / iconContainer.cellHeight);

                                        col = Math.max(0, Math.min(col, iconContainer.maxColumns - 1));
                                        row = Math.max(0, Math.min(row, iconContainer.maxRows - 1));

                                        targetIndex = col * iconContainer.maxRows + row;
                                        console.log("Calculated targetIndex:", targetIndex, "col:", col, "row:", row);
                                    }
                                }

                                if (targetIndex !== delegateRoot.index) {
                                    console.log("Moving from", delegateRoot.index, "to", targetIndex);
                                    DesktopService.moveItem(delegateRoot.index, targetIndex);
                                }

                                dragPreview.Drag.drop();
                            }
                        }
                    }
                }

                Item {
                    id: dragPreview
                    parent: iconContainer
                    width: delegateRoot.width
                    height: delegateRoot.height
                    visible: dragHandler.active
                    z: 999

                    DesktopIcon {
                        anchors.fill: parent
                        itemName: delegateRoot.name
                        itemPath: delegateRoot.path
                        itemType: delegateRoot.type
                        itemIcon: delegateRoot.icon
                        isDesktopFile: delegateRoot.isDesktopFile
                        opacity: 0.7
                        scale: 1.05
                    }

                    Drag.active: dragHandler.active
                    Drag.source: delegateRoot
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2
                    Drag.keys: ["desktopIcon"]
                }

                DropArea {
                    anchors.fill: parent
                    keys: ["desktopIcon"]

                    property int visualIndex: delegateRoot.index

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: Styling.srItem("overprimary")
                        border.width: 2
                        radius: Styling.radius(0) / 2
                        visible: parent.containsDrag
                        opacity: 0.5
                    }
                }
            }
        }
    }

    DesktopWidgetsCanvas {
        anchors.fill: parent
        screenName: desktop.screen ? desktop.screen.name : ""
        monitor: YozdService.monitorFor(desktop.screen)
        windows: CompositorData.windowList
        obscured: CompositorData.monitorHasFullscreen(monitor) || GlobalStates.lockscreenVisible
        bounds: ({
                x: iconContainer.x,
                y: iconContainer.y,
                w: iconContainer.width,
                h: iconContainer.height
            })
    }

    Rectangle {
        anchors.centerIn: parent
        width: 200
        height: 60
        color: Qt.rgba(0, 0, 0, 0.7)
        radius: Styling.radius(0)
        visible: desktop.iconsEnabled && !DesktopService.initialLoadComplete

        Text {
            anchors.centerIn: parent
            text: I18n.t("lockscreen.loading")
            color: "white"
            font.family: Config.defaultFont
            font.pixelSize: Styling.fontSize(0)
        }
    }
}
