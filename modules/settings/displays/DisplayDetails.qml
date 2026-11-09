import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import "../Ui.js" as Ui
import "../../services/DisplayModel.js" as DisplayModel
import "DisplayFormat.js" as DisplayFormat
import qs.modules.components.kit

// Settings of the selected monitor: enable, resolution, refresh rate, scale,
// rotation, VRR, plus Identify / Discard / Apply. It edits nothing itself:
// every change is a `patch` the page merges into the draft layout.
Group {
    id: root

    property var config: null
    property var output: null
    property bool dirty: false
    property bool busy: false

    signal patch(var values)
    signal resolutionPicked(int width, int height)
    signal identify
    signal discard
    signal apply

    // The live output with the draft's mode, for refresh lookups
    readonly property var draftOutput: output && config ? Object.assign({}, output, config) : null
    readonly property var refreshChoices: draftOutput ? DisplayFormat.refreshOptions(output, config) : []
    readonly property bool upgrade: !!draftOutput && DisplayModel.canUpgradeRefresh(draftOutput)
    readonly property real bestHz: draftOutput ? DisplayModel.bestRefresh(draftOutput) : 0
    readonly property bool active: !!config && config.enabled !== false

    Column {
        id: column
        width: parent.width

        // Header: icon, name, enable switch
        Item {
            width: parent.width
            height: Space.controlL + Space.m

            // Neutral icon tile: the accent stays for active state
            StyledRect {
                id: icon
                x: Look.rowInset
                anchors.verticalCenter: parent.verticalCenter
                width: Space.controlM
                height: Space.controlM
                variant: "common"
                enableShadow: false
                radius: Look.radius("control", height)
                Icon {
                    role: "title"
                    tone: "secondary"
                    anchors.centerIn: parent
                    icon: Icons.monitor
                }
            }
            Column {
                anchors.left: icon.right
                anchors.leftMargin: Space.l
                anchors.right: toggle.left
                anchors.rightMargin: Space.l
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.xs / 2
                KitText {
                    role: "title"
                    width: parent.width
                    text: root.config ? DisplayFormat.title(root.output, root.config) : ""
                    elide: Text.ElideRight
                    font.weight: Font.Bold
                }
                KitText {
                    role: "secondary"
                    width: parent.width
                    text: root.config ? root.config.name + (root.output ? "  ·  " + DisplayFormat.formatResolution(root.output.width, root.output.height) + "  ·  " + DisplayFormat.formatHz(root.output.refresh) : "") : ""
                    elide: Text.ElideRight
                }
            }
            ToggleControl {
                id: toggle
                objectName: "enabledToggle"
                anchors.right: parent.right
                anchors.rightMargin: Look.rowInset
                anchors.verticalCenter: parent.verticalCenter
                checked: root.active
                onToggled: value => root.patch({
                        "enabled": value
                    })
            }
        }

        DisplayRow {
            width: parent.width
            visible: root.active
            label: I18n.t("prefs.displays.resolution")
            SelectorControl {
                objectName: "resolutionSelector"
                width: parent.width
                translate: false
                options: root.output ? DisplayFormat.resolutionOptions(root.output) : []
                value: root.config ? DisplayFormat.resolutionKey(root.config.width, root.config.height) : ""
                onSelected: v => {
                    const r = DisplayFormat.parseResolution(v);
                    root.resolutionPicked(r.width, r.height);
                }
            }
        }

        DisplayRow {
            width: parent.width
            visible: root.active
            label: I18n.t("prefs.displays.refresh")
            hint: I18n.t("prefs.displays.refresh.desc")
            Column {
                width: parent.width
                spacing: Space.m
                DisplayChips {
                    objectName: "refreshChips"
                    width: parent.width
                    options: root.refreshChoices
                    value: root.config ? root.config.refresh : 0
                    onSelected: v => root.patch({
                            "refresh": v
                        })
                }
                Item {
                    objectName: "upgradeHint"
                    visible: root.upgrade
                    width: hintRow.implicitWidth + 24
                    height: visible ? 30 : 0
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Ui.alpha(Colors.tertiary, hintArea.containsMouse ? 0.28 : 0.18)
                        border.width: 1
                        border.color: Ui.alpha(Colors.tertiary, 0.5)
                    }
                    Row {
                        id: hintRow
                        anchors.centerIn: parent
                        spacing: Space.s
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: Icons.lightning
                            color: Colors.tertiary
                        }
                        KitText {
                            role: "secondary"
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.t("prefs.displays.refresh_upgrade", DisplayFormat.formatHz(root.bestHz))
                            color: Colors.overBackground
                        }
                    }
                    MouseArea {
                        id: hintArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.patch({
                            "refresh": root.bestHz
                        })
                    }
                }
            }
        }

        DisplayRow {
            width: parent.width
            visible: root.active
            label: I18n.t("prefs.displays.scale")
            hint: I18n.t("prefs.displays.scale.desc")
            Column {
                width: parent.width
                spacing: Space.m
                DisplayChips {
                    objectName: "scaleChips"
                    width: parent.width
                    accentIcon: "sparkle"
                    options: root.config ? DisplayFormat.scaleOptions(root.config.scale, DisplayModel.suggestScale(root.output || {})) : []
                    value: root.config ? root.config.scale : 1
                    onSelected: v => root.patch({
                            "scale": v
                        })
                }
                NumberControl {
                    objectName: "scaleCustom"
                    value: root.config ? root.config.scale : 1
                    from: 0.5
                    to: 4
                    stepSize: 0.05
                    unit: "\u00d7"
                    onChanged: v => root.patch({
                            "scale": Math.round(v * 100) / 100
                        })
                }
            }
        }

        DisplayRow {
            width: parent.width
            visible: root.active
            label: I18n.t("prefs.displays.rotation")
            SelectorControl {
                objectName: "rotationSelector"
                width: parent.width
                options: DisplayFormat.rotationOptions()
                value: root.config ? root.config.transform : 0
                onSelected: v => root.patch({
                        "transform": v
                    })
            }
        }

        DisplayRow {
            width: parent.width
            visible: root.active
            label: I18n.t("prefs.displays.vrr")
            hint: I18n.t("prefs.displays.vrr.desc")
            SelectorControl {
                objectName: "vrrSelector"
                width: parent.width
                options: DisplayFormat.vrrOptions()
                value: root.config ? root.config.vrr : 0
                onSelected: v => root.patch({
                        "vrr": v
                    })
            }
        }

        // Actions
        Item {
            width: parent.width
            height: 68

            Divider {
                x: Look.rowInset
                width: parent.width - Look.rowInset * 2
            }
            PillButton {
                objectName: "identifyButton"
                x: Look.rowInset
                anchors.verticalCenter: parent.verticalCenter
                icon: "eye"
                kind: "ghost"
                text: I18n.t("prefs.displays.identify")
                onClicked: root.identify()
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: Look.rowInset
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.m
                PillButton {
                    objectName: "discardButton"
                    visible: root.dirty
                    icon: "arrowCounterClockwise"
                    kind: "ghost"
                    text: I18n.t("prefs.displays.discard")
                    onClicked: root.discard()
                }
                PillButton {
                    objectName: "applyButton"
                    kind: "filled"
                    enabled: root.dirty && !root.busy
                    icon: "accept"
                    text: I18n.t("prefs.displays.apply")
                    onClicked: root.apply()
                }
            }
        }
    }
}
