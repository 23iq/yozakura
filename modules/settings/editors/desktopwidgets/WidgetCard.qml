pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import "../../../desktop/widgets/WidgetRegistry.js" as Registry
import "../../Ui.js" as Ui
import qs.modules.components.kit

// One placed widget in settings: live preview, its options (generic, from
// the registry), the monitor it lives on and remove.
Item {
    id: root

    property var widget: null
    property real screenW: 2560
    property real screenH: 1440
    property var screenNames: []

    signal optionSet(string key, var value)
    signal monitorSet(string name)
    signal removeRequested

    readonly property var type: widget ? Registry.get(widget.type) : null
    readonly property var opts: Registry.options(widget)

    objectName: "widgetCard:" + (widget?.id ?? "")
    implicitHeight: Math.max(previewBox.height, details.implicitHeight) + 24

    Rectangle {
        anchors.fill: parent
        radius: Look.radius("box")
        color: Ui.alpha(Colors.overBackground, 0.035)
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.8)
    }

    Rectangle {
        id: previewBox
        x: 12
        y: 12
        width: Math.min(240, root.width * 0.4)
        height: 140
        radius: Look.radius("box")
        color: Ui.alpha(Colors.surfaceContainerLowest, 0.75)
        clip: true

        WidgetPreview {
            anchors.fill: parent
            anchors.margins: Space.m
            widget: root.widget
            screenW: root.screenW
            screenH: root.screenH
        }
    }

    ColumnLayout {
        id: details
        anchors.left: previewBox.right
        anchors.leftMargin: Space.l
        anchors.right: removeButton.left
        anchors.rightMargin: Space.s
        y: 12
        spacing: Space.s

        RowLayout {
            spacing: Space.s
            Icon {
                role: "secondary"
                tone: "accent"
                icon: Icons[root.type?.icon ?? ""] ?? ""
            }
            KitText {
                Layout.fillWidth: true
                text: root.type ? I18n.t(root.type.labelKey) : ""
                elide: Text.ElideRight
                font.weight: Font.DemiBold
            }
        }

        KitText {
            role: "caption"
            Layout.fillWidth: true
            text: root.type ? I18n.t(root.type.descKey) : ""
            wrapMode: Text.WordWrap
            color: Colors.overSurfaceVariant
        }

        Repeater {
            model: root.type ? root.type.options : []

            delegate: RowLayout {
                id: opt
                required property var modelData
                Layout.fillWidth: true
                spacing: Space.m

                ToggleControl {
                    visible: opt.modelData.type === "toggle"
                    checked: !!root.opts[opt.modelData.key]
                    onToggled: v => root.optionSet(opt.modelData.key, v)
                }
                KitText {
                    role: "secondary"
                    text: I18n.t(opt.modelData.labelKey)
                    color: Colors.overBackground
                }
                SelectorControl {
                    visible: opt.modelData.type === "select"
                    Layout.fillWidth: true
                    options: (opt.modelData.choices ?? []).map(c => ({
                                value: c.value,
                                label: c.labelKey
                            }))
                    value: root.opts[opt.modelData.key]
                    onSelected: v => root.optionSet(opt.modelData.key, v)
                }
            }
        }

        RowLayout {
            visible: root.screenNames.length > 1
            Layout.fillWidth: true
            spacing: Space.m
            KitText {
                role: "secondary"
                text: I18n.t("desktop.widgets.monitor")
                color: Colors.overBackground
            }
            SelectorControl {
                Layout.fillWidth: true
                options: root.screenNames.map(n => ({
                            value: n,
                            label: n
                        }))
                value: root.screenNames.indexOf(root.widget?.monitor ?? "") !== -1 ? root.widget.monitor : root.screenNames[0]
                onSelected: v => root.monitorSet(v)
            }
        }
    }

    PillButton {
        id: removeButton
        anchors.right: parent.right
        anchors.rightMargin: Space.m
        y: 12
        kind: "ghost"
        icon: "trash"
        text: I18n.t("desktop.widgets.remove")
        onClicked: root.removeRequested()
    }
}
