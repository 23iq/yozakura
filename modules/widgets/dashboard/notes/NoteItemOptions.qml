pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// Options list of an expanded note row: Edit / Rename / Delete for a note,
// Rich text / Markdown for the "create" row. The highlighted option follows
// tab.selectedOptionIndex (keyboard) and the mouse.
RowLayout {
    id: options

    // The NotesTab (state + actions) and the row's note entry
    required property var tab
    required property var note

    spacing: 4

    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Motion.enter.easing
        }
    }

    property var noteOptions: [
        {
            text: I18n.t("common.edit"),
            icon: Icons.edit,
            highlightColor: Styling.srItem("overprimary"),
            textColor: Styling.srItem("primary"),
            action: function () {
                options.tab.openNoteInEditor(options.note.id);
            }
        },
        {
            text: I18n.t("common.rename"),
            icon: Icons.edit,
            highlightColor: Colors.secondary,
            textColor: Styling.srItem("secondary"),
            action: function () {
                options.tab.enterRenameMode(options.note.id);
                options.tab.expandedItemIndex = -1;
            }
        },
        {
            text: I18n.t("common.delete"),
            icon: Icons.trash,
            highlightColor: Colors.error,
            textColor: Styling.srItem("error"),
            action: function () {
                options.tab.enterDeleteMode(options.note.id);
                options.tab.expandedItemIndex = -1;
            }
        }
    ]

    property var createOptions: [
        {
            text: I18n.t("notes.rich_text"),
            icon: Icons.file,
            highlightColor: Styling.srItem("overprimary"),
            textColor: Styling.srItem("primary"),
            action: function () {
                options.tab.expandedItemIndex = -1;
                options.tab.createNewNote(options.note.noteNameToCreate || "", false);
            }
        },
        {
            text: I18n.t("notes.markdown"),
            icon: Icons.markdown,
            highlightColor: Colors.secondary,
            textColor: Styling.srItem("secondary"),
            action: function () {
                options.tab.expandedItemIndex = -1;
                options.tab.createNewNote(options.note.noteNameToCreate || "", true);
            }
        }
    ]

    ClippingRectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 36 * (options.note.isCreateButton ? 2 : 3)
        color: Colors.background
        radius: Styling.radius(0)

        Behavior on Layout.preferredHeight {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Motion.morph.easing
            }
        }

        ListView {
            id: optionsListView
            anchors.fill: parent
            clip: true
            interactive: false
            boundsBehavior: Flickable.StopAtBounds
            model: options.note.isCreateButton ? options.createOptions : options.noteOptions
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
                        easing.type: Motion.enter.easing
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
                readonly property bool isCurrent: optionsListView.currentIndex === option.index
                readonly property color itemColor: option.isCurrent && option.modelData && option.modelData.textColor ? option.modelData.textColor : Colors.overSurface

                width: optionsListView.width
                height: 36

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
                                easing.type: Motion.morph.easing
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: option.modelData && option.modelData.text ? option.modelData.text : ""
                        font.family: Config.theme.font
                        font.pixelSize: Config.theme.fontSize
                        font.weight: option.isCurrent ? Font.Bold : Font.Normal
                        color: option.itemColor
                        elide: Text.ElideRight
                        maximumLineCount: 1

                        Behavior on color {
                            enabled: Config.animDuration > 0
                            ColorAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Motion.morph.easing
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
                        if (option.modelData && option.modelData.action) {
                            option.modelData.action();
                        }
                    }
                }
            }
        }
    }
}
