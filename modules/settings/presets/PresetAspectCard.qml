pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import "PresetModel.js" as PresetModel
import "../Ui.js" as Ui
import "../schema/Categories.js" as Categories

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
    radius: Math.min(Styling.radius(3), 18)
    color: Colors.surfaceContainer
    border.width: 1
    border.color: Ui.alpha(Colors.outlineVariant, 0.5)

    Column {
        id: body
        x: 16
        y: 14
        width: parent.width - 32
        spacing: 10

        Item {
            width: parent.width
            height: Math.max(40, head.implicitHeight)
            Rectangle {
                id: tile
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: Math.min(Styling.radius(2), 14)
                color: Ui.alpha(Colors.primary, aspect.count > 0 ? 0.16 : 0.07)
                Text {
                    anchors.centerIn: parent
                    text: Icons[PresetModel.aspectIcon(aspect.modelData.id)] ?? ""
                    font.family: Icons.font
                    font.pixelSize: 19
                    color: aspect.count > 0 ? Colors.primary : Colors.overSurfaceVariant
                }
            }
            Column {
                id: head
                anchors.left: tile.right
                anchors.leftMargin: 12
                anchors.right: jump.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    text: I18n.t("prefs.presets.aspect." + aspect.modelData.id)
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.DemiBold
                    color: Colors.overBackground
                }
                Text {
                    width: parent.width
                    text: !aspect.modelData.carried ? I18n.t("prefs.presets.aspect_not_set") : (aspect.count === 0 ? I18n.t(aspect.against === "defaults" ? "prefs.presets.aspect_default" : "prefs.presets.aspect_same", aspect.against) : I18n.t("prefs.presets.aspect_changes", aspect.count))
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overSurfaceVariant
                    wrapMode: Text.WordWrap
                }
                Flow {
                    width: parent.width
                    spacing: 5
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
                Text {
                    id: keyText
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.42
                    text: change.modelData.title || change.modelData.key
                    elide: Text.ElideRight
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overBackground
                }
                Row {
                    anchors.left: keyText.right
                    anchors.leftMargin: 8
                    anchors.right: go.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    clip: true
                    Text {
                        text: PresetModel.formatValue(change.modelData.from)
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overSurfaceVariant
                        font.strikeout: true
                    }
                    Text {
                        text: Icons.arrowRight
                        font.family: Icons.font
                        font.pixelSize: 11
                        color: Colors.overSurfaceVariant
                    }
                    Text {
                        text: PresetModel.formatValue(change.modelData.to)
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(-2)
                        font.weight: Font.Bold
                        color: Colors.primary
                    }
                }
                Text {
                    id: go
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !aspect.official
                    text: Icons.caretRight
                    font.family: Icons.font
                    font.pixelSize: 13
                    color: Colors.overSurfaceVariant
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
