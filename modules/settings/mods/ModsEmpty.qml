import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Mods with nothing installed: one centred card, the puzzle piece on a
// tonal plate, one sentence, and the package source field as the one
// action (installing still asks for the trust confirmation first:
// `installRequested(source)`). The status banner stays reachable (a failed
// install or a pending restart is said here too).
Card {
    id: root

    signal installRequested(string source)

    padding: Look.boxPadding + Space.s

    Item {
        id: room
        width: root.contentWidth
        height: root.height - root.padding * 2
        // what must show: the words, the banner, the field; the plate only
        // where the card holds it too (a short window)
        readonly property real need: words.height + banner.height + field.height + stack.spacing * 2
        readonly property bool platePlace: room.height >= room.need + plate.height + stack.spacing

        Column {
            id: stack
            width: Math.min(parent.width, Space.px(520))
            anchors.horizontalCenter: parent.horizontalCenter
            // centred, but never above the card's top when it is short
            y: Math.max(0, Math.round((room.height - height) / 2))
            spacing: Space.l

            Mark {
                id: plate
                visible: room.platePlace
                anchors.horizontalCenter: parent.horizontalCenter
                width: Space.controlL + Space.l
                height: width
                color: Look.tonal(Type.accent)

                Icon {
                    anchors.centerIn: parent
                    icon: Icons.puzzlePiece
                    size: Space.controlL - Space.l
                    tone: "accent"
                }
            }
            Column {
                id: words
                width: parent.width
                spacing: Space.xs
                KitText {
                    objectName: "modsEmptyTitle"
                    width: parent.width
                    role: "title"
                    horizontalAlignment: Text.AlignHCenter
                    text: I18n.t("mods.empty_title")
                }
                KitText {
                    width: parent.width
                    role: "secondary"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: I18n.t("mods.empty_hint")
                }
            }
            ModsStatusBanner {
                id: banner
                width: parent.width
            }
            ModsInstallSource {
                id: field
                objectName: "modsEmptySource"
                width: parent.width
                onInstallRequested: source => root.installRequested(source)
            }
        }
    }
}
