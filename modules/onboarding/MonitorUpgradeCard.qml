pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.settings.displays
import qs.modules.components.kit
import "../services/DisplayModel.js" as DisplayModel
import "../settings/displays/DisplayFormat.js" as DisplayFormat
import "OnboardingModel.js" as Model
import "../../config/JsonUtil.js" as JsonUtil

// One monitor in the Displays step (a block of the step's "Monitors"
// group): what it runs now, a one-click upgrade to its best refresh rate,
// the recommended scale, and "More" with the full editor of Settings >
// Displays inline. Every change is emitted as the monitor's whole config
// (`apply`); the step runs it live with the keep/revert prompt.
Item {
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

    implicitHeight: column.implicitHeight

    onOutputChanged: if (root.draft && root.output && JsonUtil.deepEqual(root.draft, root.live))
        root.draft = null

    Column {
        id: column
        width: parent.width
        spacing: Space.m

        Item {
            width: parent.width
            height: Math.max(head.implicitHeight, actions.implicitHeight)

            Row {
                id: head
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - actions.width - Space.l
                spacing: Space.m

                Text {
                    id: glyph
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.monitor
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("title")
                    color: Type.secondary
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: head.width - glyph.width - head.spacing
                    spacing: Space.xs
                    KitText {
                        width: parent.width
                        role: "title"
                        text: root.output ? DisplayFormat.title(root.output, root.live) : ""
                    }
                    KitText {
                        width: parent.width
                        role: "secondary"
                        text: root.summary()
                    }
                    KitText {
                        objectName: "upgradeLine"
                        width: parent.width
                        visible: root.upgrade
                        role: "secondary"
                        color: Type.text
                        text: I18n.t("onboarding.displays.can_do", DisplayFormat.formatHz(root.output ? root.output.refresh : 0), DisplayFormat.formatHz(root.bestHz))
                    }
                }
            }

            Row {
                id: actions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.s

                Row {
                    objectName: "looksGood"
                    visible: root.good
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Space.s
                    rightPadding: Space.s
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.checkCircle
                        font.family: Icons.font
                        font.pixelSize: Type.iconSize("secondary")
                        color: Type.secondary
                    }
                    KitText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "secondary"
                        text: I18n.t("onboarding.displays.good")
                    }
                }

                FocusChip {
                    objectName: "scaleButton"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.scaleOff
                    enabled: !root.busy
                    icon: Icons.sparkle
                    text: I18n.t("onboarding.displays.use_scale", DisplayFormat.formatScale(root.suggestedScale))
                    onClicked: root.apply(root.withValues({
                        "scale": root.suggestedScale
                    }))
                }

                FocusChip {
                    objectName: "upgradeButton"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.upgrade
                    enabled: !root.busy
                    icon: Icons.lightning
                    text: I18n.t("onboarding.displays.use_hz", DisplayFormat.formatHz(root.bestHz))
                    onClicked: root.apply(root.withValues({
                        "refresh": root.bestHz
                    }))
                }

                FocusChip {
                    objectName: "moreButton"
                    anchors.verticalCenter: parent.verticalCenter
                    active: root.expanded
                    icon: root.expanded ? Icons.caretUp : Icons.caretDown
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
                dirty: root.draft !== null && !JsonUtil.deepEqual(root.draft, root.live)
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
