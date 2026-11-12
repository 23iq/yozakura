pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.previews

// Card picture of an interface language (system.language): a greeting in
// that language over today's date as it writes it. Auto shows the
// detected language faintly with a wand.
ScreenBackdrop {
    id: root

    property var entry
    property var value: "auto"
    readonly property bool auto: root.value === "auto"
    readonly property string code: root.auto ? (typeof I18n.detectSystemLanguage === "function" ? I18n.detectSystemLanguage() : "en") : String(root.value)
    // each language's own word for hello (as a language names itself)
    readonly property var hello: ({
            "en": "Hello",
            "es": "Hola",
            "ru": "Привет"
        })
    readonly property real u: Math.min(width, height) / 10

    Column {
        anchors.centerIn: parent
        width: root.width - root.u * 2
        spacing: Math.round(root.u * 0.3)
        opacity: root.auto ? 0.75 : 1
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(root.u * 0.4)
            Icon {
                visible: root.auto
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.magicWand
                size: Math.round(root.u * 1.4)
                tone: "accent"
            }
            KitText {
                anchors.verticalCenter: parent.verticalCenter
                role: "title"
                font.pixelSize: Math.round(root.u * 2)
                text: root.hello[root.code] || (I18n.availableLanguages || {})[root.code] || root.code
            }
        }
        KitText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "caption"
            font.pixelSize: Math.round(root.u * 0.95)
            color: Type.secondary
            elide: Text.ElideRight
            text: Qt.locale(root.code).toString(new Date(), "dddd, d MMMM")
        }
    }
}
