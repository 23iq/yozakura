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
        radius: Math.min(Styling.radius(4), 22)
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
        radius: Math.min(Styling.radius(2), 16)
        color: Ui.alpha(Colors.surfaceContainerLowest, 0.75)
        clip: true

        WidgetPreview {
            anchors.fill: parent
            anchors.margins: 10
            widget: root.widget
            screenW: root.screenW
            screenH: root.screenH
        }
    }

    ColumnLayout {
        id: details
        anchors.left: previewBox.right
        anchors.leftMargin: 16
        anchors.right: removeButton.left
        anchors.rightMargin: 8
        y: 12
        spacing: 8

        RowLayout {
            spacing: 8
            Text {
                text: Icons[root.type?.icon ?? ""] ?? ""
                font.family: Icons.font
                font.pixelSize: 15
                color: Colors.primary
            }
            Text {
                Layout.fillWidth: true
                text: root.type ? I18n.t(root.type.labelKey) : ""
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                font.weight: Font.DemiBold
                color: Colors.overBackground
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.type ? I18n.t(root.type.descKey) : ""
            wrapMode: Text.WordWrap
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
        }

        Repeater {
            model: root.type ? root.type.options : []

            delegate: RowLayout {
                id: opt
                required property var modelData
                Layout.fillWidth: true
                spacing: 10

                ToggleControl {
                    visible: opt.modelData.type === "toggle"
                    checked: !!root.opts[opt.modelData.key]
                    onToggled: v => root.optionSet(opt.modelData.key, v)
                }
                Text {
                    text: I18n.t(opt.modelData.labelKey)
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
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
            spacing: 10
            Text {
                text: I18n.t("desktop.widgets.monitor")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
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
        anchors.rightMargin: 12
        y: 12
        kind: "ghost"
        icon: "trash"
        text: I18n.t("desktop.widgets.remove")
        onClicked: root.removeRequested()
    }
}
