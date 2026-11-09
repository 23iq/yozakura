pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.store
import "PresetModel.js" as PresetModel
import "../Ui.js" as Ui
import "../../globals/Urls.js" as Urls
import qs.modules.components.kit

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

    implicitHeight: thumbFrame.y + thumbFrame.height + Space.m + info.implicitHeight + Space.m
    objectName: "presetCard:" + preset.name

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Look.radius("box")
        color: Look.raisedFill(hover.hovered)
        // The accent ring marks the active preset only.
        border.width: card.active ? Space.stroke - 1 : Space.hairline
        border.color: card.active ? Type.accent : Look.groupOutline
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
        x: Space.s
        y: Space.s
        width: parent.width - Space.s * 2
        height: Math.round(width * 9 / 16)
        radius: Math.max(Space.xs, bg.radius - Space.s)
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
                spacing: Space.s
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
            x: Space.s
            y: Space.s
            spacing: Space.s
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
            anchors.margins: Space.s
            visible: card.official
            solid: true
            icon: "lock"
            text: I18n.t("prefs.presets.badge.builtin")
        }
    }

    Column {
        id: info
        anchors.top: thumbFrame.bottom
        anchors.topMargin: Space.m
        x: Space.m
        width: parent.width - Space.m * 2
        spacing: Space.s

        Item {
            width: parent.width
            height: nameCol.implicitHeight
            Column {
                id: nameCol
                anchors.left: parent.left
                anchors.right: more.left
                anchors.rightMargin: Space.s
                spacing: Space.hairline
                KitText {
                    width: parent.width
                    text: card.preset.name
                    elide: Text.ElideRight
                    font.weight: Font.Bold
                }
                KitText {
                    role: "caption"
                    width: parent.width
                    text: I18n.t("prefs.presets.by", card.preset.author && card.preset.author !== "Unknown" ? card.preset.author : I18n.t("presets.unknown_author"))
                    elide: Text.ElideRight
                }
            }
            IconButton {
                id: more
                objectName: "presetMenuButton"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                size: "xs"
                icon: Icons.dotsThree
                highlighted: menu.visible
                onClicked: menu.open()

                Popup {
                    id: menu
                    x: more.width - width
                    y: more.height + Space.xs
                    width: Metrics.menuW
                    padding: Space.s
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    background: StyledRect {
                        variant: "popup"
                        radius: Look.radius("surface")
                    }
                    contentItem: Column {
                        spacing: Space.xs / 2
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
                            delegate: ListRow {
                                id: menuRow
                                required property var modelData
                                readonly property bool danger: modelData.id === "delete"
                                width: menu.availableWidth
                                title: I18n.t(modelData.label)
                                leading: Component {
                                    Icon {
                                        icon: Icons[menuRow.modelData.icon] ?? ""
                                        color: menuRow.danger ? Type.danger : Type.secondary
                                    }
                                }
                                onClicked: {
                                    menu.close();
                                    if (menuRow.modelData.id === "author") {
                                        if (Urls.isWeb(card.preset.authorUrl))
                                            Qt.openUrlExternally(card.preset.authorUrl);
                                    } else if (menuRow.modelData.id === "open")
                                        card.opened();
                                    else
                                        card.action(menuRow.modelData.id);
                                }
                            }
                        }
                    }
                }
            }
        }

        Flow {
            width: parent.width
            spacing: Space.xs
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
