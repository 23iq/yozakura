pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.components.kit
import "OnboardingModel.js" as Model

// Welcome: the blossom unfolds, then the greeting, what setup covers and
// the interface language (system.language, "auto" follows the locale) fade
// up one after another.
Item {
    id: root

    property OnboardingState wizard
    readonly property string language: wizard ? String(wizard.get("system.language") || "auto") : "auto"
    readonly property var languages: Model.languageChoices(I18n.availableLanguages).map(l => ({
                "value": l.code,
                "label": l.code === "auto" ? I18n.t("onboarding.system.language.auto") : l.name
            }))
    readonly property var features: [
        {
            "icon": "monitor",
            "text": "onboarding.welcome.f_displays"
        },
        {
            "icon": "palette",
            "text": "onboarding.welcome.f_look"
        },
        {
            "icon": "terminal",
            "text": "onboarding.welcome.f_terminal"
        },
        {
            "icon": "squaresFour",
            "text": "onboarding.welcome.f_apps"
        },
        {
            "icon": "sparkle",
            "text": "onboarding.welcome.f_ai"
        }
    ]

    function pickLanguage(code) {
        wizard.set("system.language", code);
        wizard.remember("language", code);
    }

    // 0..1 progress of a part that fades up between `from` and `from + 1/k`.
    function stage(k, from) {
        return Math.min(1, Math.max(0, root.reveal * k - from));
    }

    property real reveal: Motion.emphasis.duration > 0 ? 0 : 1

    NumberAnimation on reveal {
        running: Motion.emphasis.duration > 0
        from: 0
        to: 1
        duration: Motion.emphasis.duration * 3
        easing.type: Motion.morph.easing
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width, Space.px(760))
        spacing: Space.l

        SakuraLogo {
            objectName: "welcomeLogo"
            anchors.horizontalCenter: parent.horizontalCenter
            size: Math.min(Space.px(200), Math.round(root.height * 0.3))
        }

        KitText {
            width: parent.width
            role: "display"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: I18n.t("onboarding.welcome.title", Brand.displayName)
            opacity: root.stage(2.2, 0.6)
            transform: Translate {
                y: (1 - root.stage(2.2, 0.6)) * Space.m
            }
        }

        KitText {
            width: parent.width
            role: "body"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            lineHeight: 1.25
            color: Type.secondary
            text: I18n.t("onboarding.welcome.subtitle")
            opacity: root.stage(2.2, 0.9)
        }

        // What setup covers: quiet glyph + caption pairs (not buttons).
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Space.xl
            Repeater {
                model: root.features
                delegate: Row {
                    id: feature
                    required property var modelData
                    required property int index
                    readonly property real t: root.stage(3, 1.4 + index * 0.18)
                    spacing: Space.s
                    opacity: feature.t
                    transform: Translate {
                        y: (1 - feature.t) * Space.s
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons[feature.modelData.icon] ?? ""
                        font.family: Icons.font
                        font.pixelSize: Type.iconSize("secondary")
                        color: Type.secondary
                    }
                    KitText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "secondary"
                        text: I18n.t(feature.modelData.text)
                    }
                }
            }
        }

        Divider {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, Space.px(480))
            opacity: root.stage(2.4, 1.3)
        }

        Column {
            objectName: "languageRow"
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Space.m
            opacity: root.stage(2.4, 1.3)

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Space.s
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.translate
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("secondary")
                    color: Type.secondary
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "secondary"
                    text: I18n.t("onboarding.system.language")
                }
            }

            // Exclusive language choice: the lit chip is the current one.
            Row {
                id: languageChips
                objectName: "languageChips"
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Space.s

                signal selected(string value)

                onSelected: code => root.pickLanguage(code)

                Repeater {
                    model: root.languages
                    delegate: FocusChip {
                        required property var modelData
                        text: modelData.label
                        active: modelData.value === root.language
                        Accessible.role: Accessible.RadioButton
                        onClicked: languageChips.selected(modelData.value)
                    }
                }
            }
        }

        KitText {
            width: parent.width
            role: "caption"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: I18n.t("onboarding.welcome.hint")
            opacity: root.stage(2, 1)
        }
    }
}
