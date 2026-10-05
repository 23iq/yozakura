pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "TmuxModel.js" as TmuxModel

// Expanded options of a session row (Open, Rename, Quit). The highlighted
// option follows `tab.selectedOptionIndex` (keyboard) and the mouse.
RowLayout {
    id: options

    required property var tab
    property string sessionName: ""
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
        Layout.preferredHeight: TmuxModel.OPTION_HEIGHT * TmuxModel.OPTION_COUNT
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
            interactive: false
            boundsBehavior: Flickable.StopAtBounds
            model: [
                {
                    text: I18n.t("common.open"),
                    icon: Icons.popOpen,
                    highlightColor: Styling.srItem("overprimary"),
                    textColor: Styling.srItem("primary"),
                    action: function () {
                        options.tab.attachToSession(options.sessionName);
                    }
                },
                {
                    text: I18n.t("common.rename"),
                    icon: Icons.edit,
                    highlightColor: Colors.secondary,
                    textColor: Styling.srItem("secondary"),
                    action: function () {
                        options.tab.enterRenameMode(options.sessionName);
                        options.tab.expandedItemIndex = -1;
                    }
                },
                {
                    text: I18n.t("tmux.quit"),
                    icon: Icons.alert,
                    highlightColor: Colors.error,
                    textColor: Styling.srItem("error"),
                    action: function () {
                        options.tab.enterDeleteMode(options.sessionName);
                        options.tab.expandedItemIndex = -1;
                    }
                }
            ]
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
                readonly property color itemColor: option.current && option.modelData && option.modelData.textColor ? option.modelData.textColor : Colors.overSurface

                width: optionsListView.width
                height: TmuxModel.OPTION_HEIGHT

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
                            color: option.itemColor

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
                            color: option.itemColor
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
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: {
                            optionsListView.currentIndex = option.index;
                            options.tab.selectedOptionIndex = option.index;
                            options.tab.keyboardNavigation = false;
                        }

                        onClicked: {
                            if (option.modelData && option.modelData.action)
                                option.modelData.action();
                        }
                    }
                }
            }
        }
    }
}
