pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.modules.settings.system
import qs.config
import "../settings/Ui.js" as Ui

// Summary step, Hyprland only: "Make Yozakura the only shell". Switched on,
// it shows what will happen (the same steps as the Settings card, compact)
// and the wizard enables it when the user finishes (OnboardingState.finish).
StyledRect {
    id: root

    property OnboardingState wizard
    // switched on: the host scrolls the steps into view
    signal expanded

    readonly property bool on: !!wizard && wizard.choices.exclusive === true
    readonly property var plan: ExclusiveService.plan ?? ({})
    readonly property var units: root.plan.units ?? []
    readonly property bool blocked: ExclusiveService.blocked !== ""

    variant: "pane"
    enableShadow: false
    radius: Styling.radius(4)
    implicitHeight: col.implicitHeight + 24

    Component.onCompleted: ExclusiveService.loadPlan()

    // outline: soft, primary while switched on
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: root.on ? Ui.alpha(Colors.primary, 0.55) : Ui.alpha(Colors.outlineVariant, 0.5)
        z: 10
        Behavior on border.color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Motion.exit.duration
            }
        }
    }

    function importLine() {
        const parts = (root.plan.monitors ?? []).slice(0, 2);
        if (root.plan.keyboard)
            parts.push(I18n.t("prefs.exclusive.step.import.keyboard", root.plan.keyboard));
        return parts.length > 0 ? parts.join("  ·  ") : I18n.t("prefs.exclusive.step.import.none");
    }

    Column {
        id: col
        x: 6
        y: 12
        width: parent.width - 12
        spacing: 10

        ChoiceRow {
            objectName: "exclusiveToggle"
            width: parent.width
            mode: "toggle"
            enabled: !root.blocked
            dimmed: root.blocked
            icon: "shield"
            title: I18n.t("onboarding.finish.exclusive", Brand.displayName)
            subtitle: root.blocked ? ExclusiveService.blocked : I18n.t("onboarding.finish.exclusive.desc")
            checked: root.on
            onToggled: v => {
                root.wizard.remember("exclusive", v);
                if (v)
                    Qt.callLater(root.expanded);
            }
        }

        Grid {
            objectName: "exclusiveSteps"
            visible: root.on
            x: 14
            width: parent.width - 28
            columns: width > 640 ? 2 : 1
            columnSpacing: 18
            rowSpacing: 12
            readonly property real cell: (width - (columns - 1) * columnSpacing) / columns

            ExclusiveStep {
                width: parent.cell
                icon: "packageBox"
                title: I18n.t("prefs.exclusive.step.backup")
                detail: I18n.t("prefs.exclusive.step.backup.detail", root.plan.backupDir ?? "")
            }
            ExclusiveStep {
                width: parent.cell
                icon: "fileText"
                title: I18n.t("prefs.exclusive.step.entry", root.plan.entry ?? "hyprland.lua")
                detail: I18n.t("prefs.exclusive.step.entry.detail", root.plan.userFile ?? "user.lua")
            }
            ExclusiveStep {
                width: parent.cell
                icon: "plugsConnected"
                title: I18n.t("prefs.exclusive.step.units")
                detail: root.units.length > 0 ? root.units.join(", ") : I18n.t("prefs.exclusive.step.units.none")
                mono: root.units.length > 0
            }
            ExclusiveStep {
                width: parent.cell
                icon: "monitor"
                title: I18n.t("prefs.exclusive.step.import")
                detail: root.importLine()
            }
        }

        Text {
            visible: root.on
            x: 14
            width: parent.width - 28
            text: I18n.t("onboarding.finish.exclusive.undo", Brand.appId + " install --restore")
            wrapMode: Text.WordWrap
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
        }
    }
}
