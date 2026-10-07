import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.config
import qs.modules.components.kit
import qs.modules.bar.look
import "../../components/kit/KitStates.js" as KitStates
import qs.modules.globals

Item {
    id: root

    required property var bar

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius
    // Bar panels: module size, and "flat" (no pill background of its own)
    property int moduleSize: BarMetrics.moduleSize
    property bool flat: false
    property bool enableShadow: false
    // App icons read a touch larger than glyphs of the same size
    readonly property int iconSize: Math.round(BarLook.iconSize(root.moduleSize) * 1.1)

    // Orientación derivada de la barra
    property bool vertical: bar.orientation === "vertical"

    readonly property var allItems: SystemTray.items?.values ?? []
    readonly property var hiddenIds: StateService.systrayHidden
    readonly property var visibleItems: allItems.filter(item => !hiddenIds.includes(item.id))
    readonly property var overflowItems: allItems.filter(item => hiddenIds.includes(item.id))

    // The tray collapses to a chevron-only pill while every icon is in the popup
    readonly property bool hasItems: allItems.length > 0

    // Menu popup currently opened from an icon inside the overflow popup
    property var activeChildMenu: null

    // When the nested menu closes it drops the shared focus grab, so
    // the overflow popup must take it back
    onActiveChildMenuChanged: {
        if (activeChildMenu === null && overflowPopup.isOpen)
            overflowPopup.refreshFocusGrab();
    }

    // The caret points to where the overflow popup opens, per bar side;
    // the chevron rotates while the popup is open
    readonly property string chevronIcon: {
        switch (bar.barPosition) {
        case "bottom":
            return Icons.caretUp;
        case "left":
            return Icons.caretRight;
        case "right":
            return Icons.caretLeft;
        default:
            return Icons.caretDown;
        }
    }

    // Hide when no tray items
    visible: hasItems

    ModuleBox {
        vertical: root.vertical
        startRadius: root.startRadius
        endRadius: root.endRadius
        flat: root.flat
        shadow: root.enableShadow
        active: overflowPopup.isOpen
    }

    // Ajustes de tamaño dinámicos según orientación
    height: vertical ? implicitHeight : parent.height
    // Padding along the bar stays 16px; across it the tray matches the
    // module thickness (icons + padding = the module size)
    readonly property int crossPadding: Math.max(4, root.moduleSize - root.iconSize)
    Layout.preferredWidth: hasItems ? ((vertical ? columnLayout.implicitWidth + crossPadding : rowLayout.implicitWidth + Space.s * 2)) : 0
    implicitWidth: hasItems ? ((vertical ? columnLayout.implicitWidth + crossPadding : rowLayout.implicitWidth + Space.s * 2)) : 0
    implicitHeight: hasItems ? ((vertical ? columnLayout.implicitHeight + Space.s * 2 : rowLayout.implicitHeight + crossPadding)) : 0

    // Model mutations are deferred: committing mid-drop would destroy
    // delegates while their drop/click handlers are still on the stack
    function hideItem(id) {
        Qt.callLater(() => {
            const current = StateService.systrayHidden ?? [];
            if (current.includes(id))
                return;
            StateService.systrayHidden = [...current, id];
        });
    }

    function showItem(id) {
        Qt.callLater(() => {
            StateService.systrayHidden = (StateService.systrayHidden ?? []).filter(entry => entry !== id);
        });
    }

    function toggleOverflow() {
        overflowPopup.toggle();
    }

    // Drop zone for showing overflow icons: dropping a hidden item
    // anywhere over the tray pill puts it back in the bar
    DropArea {
        anchors.fill: parent
        keys: ["text/x-" + Brand.appId + "-tray-item"]

        onDropped: drop => {
            const id = drop.getDataAsString("text/x-" + Brand.appId + "-tray-item");
            if (id && root.hiddenIds.includes(id))
                root.showItem(id);
        }
    }

    RowLayout {
        id: rowLayout
        visible: !root.vertical
        anchors.fill: parent
        anchors.margins: Space.s
        anchors.topMargin: root.crossPadding / 2
        anchors.bottomMargin: root.crossPadding / 2
        spacing: Space.s

        Repeater {
            id: rowRepeater
            model: root.visibleItems

            SysTrayItem {
                required property SystemTrayItem modelData
                bar: root.bar
                item: modelData
                trayItemSize: root.iconSize
                overflowPopupRef: overflowPopup
            }
        }

        ChevronButton {
            id: chevronRow
            tray: root
        }
    }

    ColumnLayout {
        id: columnLayout
        visible: root.vertical
        anchors.fill: parent
        anchors.margins: Space.s
        anchors.leftMargin: root.crossPadding / 2
        anchors.rightMargin: root.crossPadding / 2
        spacing: Space.s

        Repeater {
            id: columnRepeater
            model: root.visibleItems

            SysTrayItem {
                required property SystemTrayItem modelData
                bar: root.bar
                item: modelData
                trayItemSize: root.iconSize
                overflowPopupRef: overflowPopup
            }
        }

        ChevronButton {
            id: chevronColumn
            tray: root
        }
    }

    component ChevronButton: Item {
        id: chevron

        required property var tray

        property bool hot: dropArea.containsDrag

        Layout.preferredWidth: 20
        Layout.preferredHeight: 20
        Layout.fillHeight: !chevron.tray.vertical
        Layout.fillWidth: chevron.tray.vertical

        MouseArea {
            id: chevronMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: chevron.tray.toggleOverflow()
        }

        Rectangle {
            anchors.fill: parent
            radius: Look.chipRadius(Math.min(width, height))
            color: chevron.hot ? Look.alpha("primary", KitStates.TINT) : Look.controlFill(true)
            opacity: chevron.hot || chevronMouse.containsMouse ? 1 : 0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: chevron.tray.chevronIcon
            font.family: Icons.font
            font.pixelSize: Type.iconSize("caption")
            color: chevron.hot ? Type.accent : Type.secondary
            rotation: overflowPopup.isOpen ? 180 : 0

            Behavior on rotation {
                enabled: Config.animDuration > 0
                RotationAnimation {
                    duration: Config.animDuration
                    easing.type: Motion.morph.easing
                }
            }
        }

        DropArea {
            id: dropArea
            anchors.fill: parent
            keys: ["text/x-" + Brand.appId + "-tray-item"]

            onDropped: drop => {
                const id = drop.getDataAsString("text/x-" + Brand.appId + "-tray-item");
                if (!id)
                    return;
                if (chevron.tray.hiddenIds.includes(id))
                    chevron.tray.showItem(id);
                else
                    chevron.tray.hideItem(id);
            }
        }
    }

    BarPopup {
        id: overflowPopup
        anchorItem: root.vertical ? chevronColumn : chevronRow
        bar: root.bar
        popupPadding: Look.surfacePadding
        visualMargin: 16
        clickThroughMargins: true

        readonly property int columns: Math.max(1, Math.min(root.overflowItems.length, 5))
        readonly property int rows: Math.max(1, Math.ceil(root.overflowItems.length / columns))
        readonly property int gridWidth: columns * root.iconSize + (columns - 1) * Space.m
        readonly property int gridHeight: rows * root.iconSize + (rows - 1) * Space.m

        contentWidth: (root.overflowItems.length > 0 ? gridWidth : hintLabel.implicitWidth) + popupPadding * 2
        contentHeight: (root.overflowItems.length > 0 ? gridHeight : hintLabel.implicitHeight) + popupPadding * 2

        // A nested tray menu must not clear this popup's focus grab
        extraGrabWindows: root.activeChildMenu ? [root.activeChildMenu] : []

        onIsOpenChanged: {
            if (isOpen)
                return;
            const child = root.activeChildMenu;
            root.activeChildMenu = null;
            if (child)
                child.close();
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Space.s

            Grid {
                id: iconsGrid
                visible: root.overflowItems.length > 0
                columns: overflowPopup.columns
                spacing: Space.m

                Repeater {
                    model: root.overflowItems

                    SysTrayItem {
                        required property SystemTrayItem modelData
                        bar: root.bar
                        item: modelData
                        trayItemSize: root.iconSize
                        inOverflow: true
                        overflowPopupRef: overflowPopup
                    }
                }
            }

            KitText {
                id: hintLabel
                visible: root.overflowItems.length === 0
                role: "caption"
                text: I18n.t("bar.systray.overflow_empty")
            }
        }

        // Drop zone for hiding bar icons: dropping a visible item
        // over the popup card moves it into the overflow grid
        DropArea {
            id: popupDropArea
            anchors.fill: parent
            keys: ["text/x-" + Brand.appId + "-tray-item"]

            onDropped: drop => {
                const id = drop.getDataAsString("text/x-" + Brand.appId + "-tray-item");
                if (id && !root.hiddenIds.includes(id))
                    root.hideItem(id);
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Space.controlRadius
            color: Type.accent
            opacity: popupDropArea.containsDrag ? KitStates.TINT : 0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }
    }
}
