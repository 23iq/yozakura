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
        width: root.contentWidth
        height: root.height - root.padding * 2

        Column {
            id: stack
            width: Math.min(parent.width, Space.px(520))
            anchors.centerIn: parent
            spacing: Space.l

            Mark {
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
                width: parent.width
            }
            ModsInstallSource {
                objectName: "modsEmptySource"
                width: parent.width
                onInstallRequested: source => root.installRequested(source)
            }
        }
    }
}
