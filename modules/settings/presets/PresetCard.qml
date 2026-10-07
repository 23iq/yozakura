pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.store
import "PresetModel.js" as PresetModel
import "../Ui.js" as Ui
import "../../globals/Urls.js" as Urls

// Gallery card: live thumbnail, name, author, tags, active / built-in
// badges; Apply and Try on hover, everything else in the ⋯ menu. A click
// opens the preset's detail/editor view. Actions are signals: the studio
// page owns dialogs and the store.
Item {
    id: card

    required property var preset
    readonly property bool official: preset.official
    // A user preset named like a built-in: unusable until renamed.
    readonly property bool shadowed: !!preset.shadowed
    readonly property bool active: preset.active
    readonly property bool busy: PresetStudio.pending === preset.name
    readonly property bool locked: PresetStudio.trial !== null || PresetStudio.edit !== null

    signal opened
    signal action(string id)

    implicitHeight: thumbFrame.height + info.implicitHeight + 22
    objectName: "presetCard:" + preset.name

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Math.min(Styling.radius(4), 22)
        color: hover.hovered ? Colors.surfaceContainerHigh : Colors.surfaceContainer
        border.width: card.active ? 2 : 1
        border.color: card.active ? Colors.primary : Ui.alpha(Colors.outlineVariant, 0.6)
        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Motion.morph.duration
            }
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: card.shadowed ? card.action("rename") : card.opened()
    }

    ClippingRectangle {
        id: thumbFrame
        x: 8
        y: 8
        width: parent.width - 16
        height: Math.round(width * 9 / 16)
        radius: Math.max(4, bg.radius - 6)
        color: Colors.surfaceContainerHigh

        PresetThumb {
            anchors.fill: parent
            look: card.preset.look || null
        }

        // Hover actions
        Rectangle {
            anchors.fill: parent
            color: Ui.alpha(Colors.shadow, 0.35)
            opacity: hover.hovered && !card.locked ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Motion.enter.duration
                }
            }
            Row {
                anchors.centerIn: parent
                spacing: 8
                PillButton {
                    visible: card.shadowed
                    kind: "filled"
                    icon: "textAa"
                    text: I18n.t("prefs.presets.rename")
                    onClicked: card.action("rename")
                }
                PillButton {
                    objectName: "applyPreset"
                    visible: !card.shadowed
                    kind: "filled"
                    icon: "accept"
                    text: card.active ? I18n.t("prefs.presets.reapply") : I18n.t("prefs.presets.apply")
                    onClicked: card.action("apply")
                }
                PillButton {
                    objectName: "tryPreset"
                    kind: "solid"
                    icon: "timer"
                    text: I18n.t("prefs.presets.try", PresetStudio.trialSeconds)
                    visible: !card.active && !card.shadowed
                    onClicked: card.action("try")
                }
            }
        }

        Row {
            x: 8
            y: 8
            spacing: 6
            PresetChip {
                visible: card.active
                tone: "primary"
                icon: "checkCircle"
                text: I18n.t("prefs.presets.badge.active")
            }
            PresetChip {
                visible: card.shadowed
                solid: true
                tone: "soft"
                icon: "warning"
                text: I18n.t("prefs.presets.badge.shadowed")
            }
            PresetChip {
                visible: card.busy
                solid: true
                icon: "hourglass"
                text: I18n.t("prefs.presets.badge.applying")
            }
        }
        PresetChip {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            visible: card.official
            solid: true
            icon: "lock"
            text: I18n.t("prefs.presets.badge.builtin")
        }
    }

    Column {
        id: info
        anchors.top: thumbFrame.bottom
        anchors.topMargin: 10
        x: 14
        width: parent.width - 28
        spacing: 6

        Item {
            width: parent.width
            height: nameCol.implicitHeight
            Column {
                id: nameCol
                anchors.left: parent.left
                anchors.right: more.left
                anchors.rightMargin: 6
                spacing: 1
                Text {
                    width: parent.width
                    text: card.preset.name
                    elide: Text.ElideRight
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.Bold
                    color: Colors.overBackground
                }
                Text {
                    width: parent.width
                    text: I18n.t("prefs.presets.by", card.preset.author && card.preset.author !== "Unknown" ? card.preset.author : I18n.t("presets.unknown_author"))
                    elide: Text.ElideRight
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overSurfaceVariant
                }
            }
            Rectangle {
                id: more
                objectName: "presetMenuButton"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                radius: 15
                color: moreArea.containsMouse || menu.visible ? Ui.alpha(Colors.overBackground, 0.1) : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: Icons.dotsThree
                    font.family: Icons.font
                    font.pixelSize: 18
                    color: Colors.overSurfaceVariant
                }
                MouseArea {
                    id: moreArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: menu.open()
                }

                Popup {
                    id: menu
                    x: more.width - width
                    y: more.height + 4
                    width: 230
                    padding: 6
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    background: Rectangle {
                        radius: Math.min(Styling.radius(2), 16)
                        color: Colors.surfaceContainerHighest
                        border.width: 1
                        border.color: Ui.alpha(Colors.outline, 0.4)
                    }
                    contentItem: Column {
                        spacing: 2
                        Repeater {
                            model: [
                                {
                                    "id": "open",
                                    "icon": card.official ? "eye" : "pencil",
                                    "label": card.official ? "prefs.presets.menu.details" : "prefs.presets.menu.edit",
                                    "show": !card.shadowed
                                },
                                {
                                    "id": "duplicate",
                                    "icon": "copy",
                                    "label": card.official ? "prefs.presets.duplicate_to_edit" : "prefs.presets.duplicate",
                                    "show": !card.shadowed
                                },
                                {
                                    "id": "rename",
                                    "icon": "textAa",
                                    "label": "prefs.presets.rename",
                                    "show": !card.official
                                },
                                {
                                    "id": "update",
                                    "icon": "arrowsClockwise",
                                    "label": "prefs.presets.update_from_current",
                                    "show": !card.official && !card.shadowed
                                },
                                {
                                    "id": "export",
                                    "icon": "arrowSquareOut",
                                    "label": "prefs.presets.export",
                                    "show": !card.shadowed
                                },
                                {
                                    "id": "author",
                                    "icon": "link",
                                    "label": "presets.visit_author",
                                    "show": Urls.isWeb(card.preset.authorUrl)
                                },
                                {
                                    "id": "delete",
                                    "icon": "trash",
                                    "label": "prefs.presets.delete",
                                    "show": !card.official
                                }
                            ].filter(m => m.show)
                            delegate: Rectangle {
                                id: item
                                required property var modelData
                                width: 218
                                height: 34
                                radius: Math.min(Styling.radius(0), 10)
                                color: itemArea.containsMouse ? Ui.alpha(modelData.id === "delete" ? Colors.error : Colors.primary, 0.14) : "transparent"
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10
                                    Text {
                                        text: Icons[item.modelData.icon] ?? ""
                                        font.family: Icons.font
                                        font.pixelSize: 14
                                        color: item.modelData.id === "delete" ? Colors.error : Colors.overSurfaceVariant
                                    }
                                    Text {
                                        text: I18n.t(item.modelData.label)
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        color: item.modelData.id === "delete" ? Colors.error : Colors.overBackground
                                    }
                                }
                                MouseArea {
                                    id: itemArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        menu.close();
                                        if (item.modelData.id === "author") {
                                            if (Urls.isWeb(card.preset.authorUrl))
                                                Qt.openUrlExternally(card.preset.authorUrl);
                                        } else if (item.modelData.id === "open")
                                            card.opened();
                                        else
                                            card.action(item.modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Flow {
            width: parent.width
            spacing: 5
            Repeater {
                model: card.preset.tags || []
                PresetChip {
                    required property string modelData
                    text: I18n.t(PresetModel.tagLabel(modelData))
                }
            }
        }
    }
}
