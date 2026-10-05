pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "ClipboardView.js" as ClipboardView

// Options menu of an expanded row: Copy, Open (files, images, URLs), Pin,
// Alias, Delete. Keyboard selection lives in tab.selectedOptionIndex.
RowLayout {
    id: options

    required property ClipboardTabBase tab
    required property var entry
    property bool shown: false

    spacing: 4
    visible: options.shown
    opacity: options.shown ? 1 : 0

    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    ClippingRectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: ClipboardView.optionsListHeight(options.entry)
        color: Colors.background
        radius: Styling.radius(0)

        Behavior on Layout.preferredHeight {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }

        ListView {
            id: optionsListView
            anchors.fill: parent
            clip: true
            interactive: true
            boundsBehavior: Flickable.StopAtBounds

            property bool isScrolling: dragging || flicking

            model: {
                const tab = options.tab;
                const entry = options.entry;
                var list = [
                    {
                        text: I18n.t("common.copy"),
                        icon: Icons.copy,
                        highlightColor: Styling.srItem("overprimary"),
                        textColor: Styling.srItem("primary"),
                        action: function () {
                            tab.copyToClipboard(entry.id);
                            Visibilities.setActiveModule("");
                        }
                    }
                ];

                if (ClipboardView.canOpen(entry)) {
                    list.push({
                        text: I18n.t("common.open"),
                        icon: Icons.popOpen,
                        highlightColor: Styling.srItem("overprimary"),
                        textColor: Styling.srItem("primary"),
                        action: function () {
                            tab.openItem(entry.id);
                        }
                    });
                }

                list.push({
                    text: entry.pinned ? I18n.t("clipboard.unpin") : I18n.t("clipboard.pin"),
                    icon: entry.pinned ? Icons.unpin : Icons.pin,
                    highlightColor: Styling.srItem("overprimary"),
                    textColor: Styling.srItem("primary"),
                    action: function () {
                        tab.pendingItemIdToSelect = entry.id;
                        ClipboardService.togglePin(entry.id);
                        tab.expandedItemIndex = -1;
                    }
                }, {
                    text: I18n.t("clipboard.alias"),
                    icon: Icons.edit,
                    highlightColor: Colors.secondary,
                    textColor: Styling.srItem("secondary"),
                    action: function () {
                        tab.enterAliasMode(entry.id);
                        tab.expandedItemIndex = -1;
                    }
                }, {
                    text: I18n.t("common.delete"),
                    icon: Icons.trash,
                    highlightColor: Colors.error,
                    textColor: Styling.srItem("error"),
                    action: function () {
                        tab.enterDeleteMode(entry.id);
                        tab.expandedItemIndex = -1;
                    }
                });

                return list;
            }
            currentIndex: options.tab.selectedOptionIndex
            highlightFollowsCurrentItem: true
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: 0
            preferredHighlightEnd: height

            highlight: StyledRect {
                variant: {
                    if (optionsListView.currentIndex >= 0 && optionsListView.currentIndex < optionsListView.count) {
                        var item = optionsListView.model[optionsListView.currentIndex];
                        if (item && item.highlightColor) {
                            if (item.highlightColor === Colors.error)
                                return "error";
                            if (item.highlightColor === Colors.secondary)
                                return "secondary";
                            return "primary";
                        }
                    }
                    return "primary";
                }
                radius: Styling.radius(0)
                visible: optionsListView.currentIndex >= 0
                z: -1

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutQuart
                    }
                }
            }

            highlightMoveDuration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
            highlightMoveVelocity: -1
            highlightResizeDuration: Config.animDuration / 2
            highlightResizeVelocity: -1

            delegate: Item {
                id: option

                required property var modelData
                required property int index

                readonly property bool current: optionsListView.currentIndex === option.index
                readonly property color labelColor: option.current && option.modelData && option.modelData.textColor ? option.modelData.textColor : Colors.overSurface

                width: optionsListView.width
                height: 36

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Text {
                            text: option.modelData && option.modelData.icon ? option.modelData.icon : ""
                            font.family: Icons.font
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            textFormat: Text.RichText
                            color: option.labelColor

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutQuart
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: option.modelData && option.modelData.text ? option.modelData.text : ""
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize
                            font.weight: option.current ? Font.Bold : Font.Normal
                            color: option.labelColor
                            elide: Text.ElideRight
                            maximumLineCount: 1

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutQuart
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: !optionsListView.isScrolling
                        cursorShape: Qt.PointingHandCursor

                        onEntered: {
                            if (optionsListView.isScrolling)
                                return;
                            optionsListView.currentIndex = option.index;
                            options.tab.selectedOptionIndex = option.index;
                            options.tab.keyboardNavigation = false;
                        }

                        onClicked: {
                            if (optionsListView.isScrolling)
                                return;
                            if (option.modelData && option.modelData.action) {
                                option.modelData.action();
                            }
                        }
                    }
                }
            }
        }

        // Wheel scrolling of the options list
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            acceptedButtons: Qt.NoButton

            onWheel: wheel => {
                if (optionsListView.contentHeight > optionsListView.height) {
                    const delta = wheel.angleDelta.y;
                    optionsListView.contentY = Math.max(0, Math.min(optionsListView.contentHeight - optionsListView.height, optionsListView.contentY - delta));
                    wheel.accepted = true;
                } else {
                    wheel.accepted = false;
                }
            }
        }
    }

    ScrollBar {
        Layout.preferredWidth: 8
        Layout.preferredHeight: Math.max(0, ClipboardView.optionsListHeight(options.entry) - 32)
        Layout.alignment: Qt.AlignVCenter
        orientation: Qt.Vertical
        visible: ClipboardView.optionsCount(options.entry) > ClipboardView.MAX_VISIBLE_OPTIONS

        position: optionsListView.contentY / optionsListView.contentHeight
        size: optionsListView.height / optionsListView.contentHeight

        background: Rectangle {
            color: Colors.background
            radius: Styling.radius(0)
        }

        contentItem: Rectangle {
            color: Styling.srItem("overprimary")
            radius: Styling.radius(0)
        }

        property bool scrollBarPressed: false

        onPressedChanged: {
            scrollBarPressed = pressed;
        }

        onPositionChanged: {
            if (scrollBarPressed && optionsListView.contentHeight > optionsListView.height) {
                optionsListView.contentY = position * optionsListView.contentHeight;
            }
        }
    }
}
