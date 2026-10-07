import QtQuick
import QtQuick.Effects
import Quickshell
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.config
import qs.modules.globals

// About: name, version, a couple of useful shortcuts and the legal row.
Item {
    id: page

    required property var category

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - Space.xxl * 2, Space.px(520))
        spacing: Space.xl

        // The mark: the brand glyph in the language's control box (no
        // accent: it is not a state).
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Space.controlXL
            height: Space.controlXL

            ControlBox {
                radius: Look.squareControls ? Space.controlRadius : Space.surfaceRadius
            }
            Image {
                anchors.centerIn: parent
                width: Math.round(parent.width * 0.6)
                height: width
                source: Qt.resolvedUrl("../../assets/yozakura/yozakura-icon.svg")
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                fillMode: Image.PreserveAspectFit
                mipmap: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    brightness: 1.0
                    colorization: 1.0
                    colorizationColor: Type.text
                }
            }
        }

        Column {
            width: parent.width
            spacing: Space.xs

            KitText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                role: "display"
                tabular: false
                text: Brand.displayName
            }
            KitText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                role: "secondary"
                text: I18n.t("prefs.about.version", Config.version)
            }
        }

        KitText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "body"
            wrapMode: Text.WordWrap
            text: I18n.t("prefs.about.blurb")
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Space.s

            PillButton {
                objectName: "aboutRunSetup"
                icon: "seal"
                text: I18n.t("onboarding.run_again")
                onClicked: {
                    GlobalStates.settingsWindowVisible = false;
                    OnboardingService.open();
                }
            }
            PillButton {
                icon: "folder"
                text: I18n.t("prefs.about.open_config")
                onClicked: Quickshell.execDetached(["xdg-open", Config.configDir])
            }
            PillButton {
                icon: "code"
                text: I18n.t("prefs.about.source")
                onClicked: Quickshell.execDetached(["xdg-open", Brand.repoUrl])
            }
        }

        LegalNotice {
            width: parent.width
        }
    }
}
