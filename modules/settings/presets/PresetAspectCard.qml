pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import "PresetModel.js" as PresetModel
import "../Ui.js" as Ui
import "../schema/Categories.js" as Categories
import qs.modules.components.kit

// One aspect of a preset in the editor (`preset show` report): status
// against the reference, presets sharing it, the changed keys (4, then
// "show all") and, for user presets, jumps into the settings page.
Rectangle {
    id: aspect

    required property var modelData
    required property bool official
    required property bool locked // a trial or another edit runs
    required property string against
    property bool open: false

    signal edit(string category, string section, string entry)
    readonly property int count: modelData.changes.length
    readonly property var visibleChanges: open ? modelData.changes : modelData.changes.slice(0, 4)
    objectName: "editorAspect:" + modelData.id
    height: body.implicitHeight + 28
    radius: Look.radius("box")
    color: Colors.surfaceContainer
    border.width: 1
    border.color: Ui.alpha(Colors.outlineVariant, 0.5)

    Column {
        id: body
        x: 16
        y: 14
        width: parent.width - 32
        spacing: Space.m

        Item {
            width: parent.width
            height: Math.max(40, head.implicitHeight)
            Rectangle {
                id: tile
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: Look.radius("box")
                color: Ui.alpha(Colors.primary, aspect.count > 0 ? 0.16 : 0.07)
                Icon {
                    anchors.centerIn: parent
                    icon: Icons[PresetModel.aspectIcon(aspect.modelData.id)] ?? ""
                    color: aspect.count > 0 ? Colors.primary : Colors.overSurfaceVariant
                }
            }
            Column {
                id: head
                anchors.left: tile.right
                anchors.leftMargin: Space.m
                anchors.right: jump.left
                anchors.rightMargin: Space.m
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.xs
                KitText {
                    text: I18n.t("prefs.presets.aspect." + aspect.modelData.id)
                    font.weight: Font.DemiBold
                }
                KitText {
                    role: "caption"
                    width: parent.width
                    text: !aspect.modelData.carried ? I18n.t("prefs.presets.aspect_not_set") : (aspect.count === 0 ? I18n.t(aspect.against === "defaults" ? "prefs.presets.aspect_default" : "prefs.presets.aspect_same", aspect.against) : I18n.t("prefs.presets.aspect_changes", aspect.count))
                    color: Colors.overSurfaceVariant
                    wrapMode: Text.WordWrap
                }
                Flow {
                    width: parent.width
                    spacing: Space.xs
                    visible: (aspect.modelData.sameAs || []).length > 0
                    PresetChip {
                        tone: "soft"
                        icon: "gitDiff"
                        text: I18n.t("prefs.presets.same_as")
                    }
                    Repeater {
                        model: (aspect.modelData.sameAs || []).slice(0, 4)
                        PresetChip {
                            required property string modelData
                            text: modelData
                        }
                    }
                    PresetChip {
                        visible: (aspect.modelData.sameAs || []).length > 4
                        text: "+" + ((aspect.modelData.sameAs || []).length - 4)
                    }
                }
            }
            PillButton {
                id: jump
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !aspect.official && aspect.modelData.id !== "other"
                enabled: !aspect.locked
                icon: "pencil"
                text: I18n.t("prefs.presets.edit_aspect")
                onClicked: aspect.edit(aspect.modelData.category, "", "")
            }
        }

        Repeater {
            model: aspect.visibleChanges
            delegate: Rectangle {
                id: change
                required property var modelData
                width: body.width
                height: 36
                radius: Math.min(Styling.radius(0), 10)
                color: changeArea.containsMouse && !aspect.official ? Ui.alpha(Colors.primary, 0.08) : Ui.alpha(Colors.overBackground, 0.03)
                KitText {
                    id: keyText
                    role: "secondary"
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.42
                    text: change.modelData.title || change.modelData.key
                    elide: Text.ElideRight
                    color: Colors.overBackground
                }
                Row {
                    anchors.left: keyText.right
                    anchors.leftMargin: Space.s
                    anchors.right: go.left
                    anchors.rightMargin: Space.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Space.s
                    clip: true
                    KitText {
                        role: "caption"
                        text: PresetModel.formatValue(change.modelData.from)
                        font.family: Config.theme.monoFont
                        color: Colors.overSurfaceVariant
                        font.strikeout: true
                    }
                    Icon {
                        role: "label"
                        tone: "secondary"
                        icon: Icons.arrowRight
                    }
                    KitText {
                        role: "caption"
                        text: PresetModel.formatValue(change.modelData.to)
                        font.family: Config.theme.monoFont
                        font.weight: Font.Bold
                        color: Colors.primary
                    }
                }
                Icon {
                    id: go
                    role: "caption"
                    tone: "secondary"
                    anchors.right: parent.right
                    anchors.rightMargin: Space.m
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !aspect.official
                    icon: Icons.caretRight
                }
                MouseArea {
                    id: changeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !aspect.official && !aspect.locked
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const t = PresetModel.jumpTarget(change.modelData, aspect.modelData, id => Categories.byId(id) !== null);
                        aspect.edit(t.category, t.section, t.entry);
                    }
                }
            }
        }

        PillButton {
            visible: aspect.count > 4
            kind: "ghost"
            icon: aspect.open ? "caretUp" : "caretDown"
            text: aspect.open ? I18n.t("prefs.presets.show_less") : I18n.t("prefs.presets.show_all", aspect.count)
            onClicked: aspect.open = !aspect.open
        }
    }
}
