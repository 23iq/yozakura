pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.settings.displays
import qs.config
import "../settings/Ui.js" as Ui
import "../services/DisplayModel.js" as DisplayModel
import "../settings/displays/DisplayFormat.js" as DisplayFormat
import "OnboardingModel.js" as Model

// One monitor in the Displays step: what it runs now, a one-click upgrade
// to its best refresh rate, the recommended scale, and "More" with the full
// editor of Settings > Displays inline. Every change is emitted as the
// monitor's whole config (`apply`); the step runs it live with the
// keep/revert prompt.
StyledRect {
    id: root

    property var output: null
    property bool busy: false
    property bool expanded: false
    // Unapplied edits from "More" (null = the live mode)
    property var draft: null

    signal apply(var config)

    readonly property var live: output ? DisplayModel.outputToConfig(output) : null
    readonly property var config: draft || live
    readonly property bool upgrade: !!output && DisplayModel.canUpgradeRefresh(output)
    readonly property real bestHz: output ? DisplayModel.bestRefresh(output) : 0
    readonly property real suggestedScale: output ? DisplayModel.suggestScale(output) : 1
    readonly property bool scaleOff: !!output && Math.abs(suggestedScale - (Number(output.scale) || 1)) > 0.01
    readonly property bool good: !upgrade && !scaleOff
    readonly property real inches: Model.diagonalInches(output)
    readonly property int pad: Math.round(Styling.fontSize(0) * 1.2)

    function summary() {
        if (!output)
            return "";
        const parts = [output.name];
        if (inches > 0)
            parts.push(I18n.t("onboarding.displays.inches", inches));
        parts.push(DisplayFormat.formatResolution(output.width, output.height));
        parts.push(DisplayFormat.formatHz(output.refresh));
        parts.push(I18n.t("onboarding.displays.scale", DisplayFormat.formatScale(Number(output.scale) || 1)));
        return parts.join("  ·  ");
    }

    function withValues(values) {
        return Object.assign({}, live, values);
    }

    function patch(values) {
        root.draft = Object.assign({}, root.config, values);
    }

    function pickResolution(w, h) {
        const mode = Object.assign({}, output, {
            "width": w,
            "height": h
        });
        patch({
            "width": w,
            "height": h,
            "refresh": DisplayModel.bestRefresh(mode)
        });
    }

    variant: "pane"
    enableShadow: false
    radius: Styling.radius(4)
    implicitHeight: column.implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: root.upgrade ? Ui.alpha(Colors.primary, 0.6) : Ui.alpha(Colors.outlineVariant, 0.55)
        z: 10
    }

    onOutputChanged: if (root.draft && root.output && JSON.stringify(root.draft) === JSON.stringify(root.live))
        root.draft = null

    Column {
        id: column
        width: parent.width

        Item {
            width: parent.width
            height: Math.max(head.implicitHeight, actions.implicitHeight) + root.pad * 2

            Row {
                id: head
                x: root.pad
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - root.pad * 2 - actions.width - root.pad
                spacing: Math.round(Styling.fontSize(0) * 0.9)

                StyledRect {
                    id: chip
                    variant: root.upgrade ? "primary" : "common"
                    enableShadow: false
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(Styling.fontSize(0) * 3)
                    height: width
                    radius: Math.min(width / 2, Styling.radius(2))
                    Text {
                        anchors.centerIn: parent
                        text: Icons.monitor
                        font.family: Icons.font
                        font.pixelSize: Styling.fontSize(4)
                        color: root.upgrade ? Colors.overPrimary : Colors.primary
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: head.width - chip.width - head.spacing
                    spacing: 3
                    Text {
                        width: parent.width
                        text: root.output ? DisplayFormat.title(root.output, root.live) : ""
                        elide: Text.ElideRight
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(2)
                        font.weight: Font.Bold
                        color: Colors.overBackground
                    }
                    Text {
                        width: parent.width
                        text: root.summary()
                        elide: Text.ElideRight
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overSurfaceVariant
                    }
                    Text {
                        objectName: "upgradeLine"
                        width: parent.width
                        visible: root.upgrade
                        text: I18n.t("onboarding.displays.can_do", DisplayFormat.formatHz(root.output ? root.output.refresh : 0), DisplayFormat.formatHz(root.bestHz))
                        elide: Text.ElideRight
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.Medium
                        color: Colors.primary
                    }
                }
            }

            Row {
                id: actions
                anchors.right: parent.right
                anchors.rightMargin: root.pad
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                StyledRect {
                    objectName: "looksGood"
                    visible: root.good
                    variant: "common"
                    enableShadow: false
                    anchors.verticalCenter: parent.verticalCenter
                    width: goodRow.implicitWidth + 28
                    height: Math.round(Styling.fontSize(0) * 2.4)
                    radius: height / 2
                    Row {
                        id: goodRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.checkCircle
                            font.family: Icons.font
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.primary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.t("onboarding.displays.good")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overBackground
                        }
                    }
                }

                NavButton {
                    objectName: "scaleButton"
                    visible: root.scaleOff
                    enabled: !root.busy
                    kind: "tonal"
                    icon: "sparkle"
                    text: I18n.t("onboarding.displays.use_scale", DisplayFormat.formatScale(root.suggestedScale))
                    onClicked: root.apply(root.withValues({
                        "scale": root.suggestedScale
                    }))
                }

                NavButton {
                    objectName: "upgradeButton"
                    visible: root.upgrade
                    enabled: !root.busy
                    kind: "filled"
                    icon: "lightning"
                    text: I18n.t("onboarding.displays.use_hz", DisplayFormat.formatHz(root.bestHz))
                    onClicked: root.apply(root.withValues({
                        "refresh": root.bestHz
                    }))
                }

                NavButton {
                    objectName: "moreButton"
                    kind: "ghost"
                    trailingIcon: root.expanded ? "caretUp" : "caretDown"
                    text: I18n.t("onboarding.displays.more")
                    onClicked: root.expanded = !root.expanded
                }
            }
        }

        Loader {
            width: parent.width
            active: root.expanded
            visible: active
            sourceComponent: DisplayDetails {
                objectName: "monitorDetails"
                width: parent ? parent.width : 0
                config: root.config
                output: root.output
                dirty: root.draft !== null && JSON.stringify(root.draft) !== JSON.stringify(root.live)
                busy: root.busy
                onPatch: values => root.patch(values)
                onResolutionPicked: (w, h) => root.pickResolution(w, h)
                onIdentify: DisplaysService.identify()
                onDiscard: root.draft = null
                onApply: root.apply(root.config)
            }
        }
    }
}
