pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.config
import "OnboardingModel.js" as Model

// Terminal (general.terminal; installed ones are detected) and interface
// language (system.language; "auto" follows the system locale).
Item {
    id: root

    property OnboardingState wizard

    readonly property string terminal: wizard ? String(wizard.get("general.terminal") || "") : ""
    readonly property string language: wizard ? String(wizard.get("system.language") || "auto") : "auto"
    readonly property var terminals: Model.terminalChoices(wizard ? wizard.detected.terminals : [], terminal)
    readonly property var languages: Model.languageChoices(I18n.availableLanguages)
    readonly property int gap: Math.round(Styling.fontSize(0) * 1.6)

    Row {
        anchors.fill: parent
        spacing: root.gap

        Column {
            id: termCol
            width: (parent.width - root.gap) / 2
            height: parent.height
            spacing: 10

            SectionLabel {
                width: parent.width
                icon: "terminalWindow"
                text: I18n.t("onboarding.system.terminal")
                hint: I18n.t("onboarding.system.terminal.desc")
            }

            ListView {
                objectName: "terminalList"
                width: parent.width
                height: parent.height - y
                clip: true
                spacing: 8
                model: root.terminals
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: ChoiceRow {
                    required property string modelData
                    width: ListView.view.width
                    icon: "terminal"
                    title: modelData
                    badge: (root.wizard && root.wizard.detected.terminals.indexOf(modelData) !== -1) ? I18n.t("onboarding.installed") : I18n.t("onboarding.not_found")
                    badgeOk: root.wizard && root.wizard.detected.terminals.indexOf(modelData) !== -1
                    checked: modelData === root.terminal
                    onClicked: root.wizard.set("general.terminal", modelData)
                }
                footer: Text {
                    width: ListView.view ? ListView.view.width : 0
                    visible: root.wizard && root.wizard.detecting
                    topPadding: 8
                    text: I18n.t("onboarding.detecting")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.outline
                }
            }
        }

        Column {
            width: (parent.width - root.gap) / 2
            height: parent.height
            spacing: 10

            SectionLabel {
                width: parent.width
                icon: "translate"
                text: I18n.t("onboarding.system.language")
                hint: I18n.t("onboarding.system.language.desc")
            }

            ListView {
                objectName: "languageList"
                width: parent.width
                height: parent.height - y
                clip: true
                spacing: 8
                model: root.languages
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: ChoiceRow {
                    required property var modelData
                    width: ListView.view.width
                    icon: modelData.code === "auto" ? "globe" : ""
                    title: modelData.code === "auto" ? I18n.t("onboarding.system.language.auto") : modelData.name
                    subtitle: modelData.code === "auto" ? I18n.t("onboarding.system.language.auto.desc") : modelData.code
                    checked: modelData.code === root.language
                    onClicked: root.wizard.set("system.language", modelData.code)
                }
            }
        }
    }
}
