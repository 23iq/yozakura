pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.controls

// One field of a surface variant (SurfaceRoles.js FIELDS entry `def`):
// label (+ description) and its control. Toggles, sliders and selectors sit
// beside the label; colors and fills below it. Emits the control's value.
ColumnLayout {
    id: root

    property var def: ({})
    property var value
    signal edited(var value)

    readonly property bool inline: def.kind === "toggle" || def.kind === "slider" || def.kind === "selector"

    objectName: "surfaceField:" + (def.field || "")
    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: !root.inline || root.def.kind === "toggle"
            Layout.preferredWidth: root.inline && root.def.kind !== "toggle" ? 150 : -1
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.def.label ? I18n.t(root.def.label) : ""
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overBackground
            }
            Text {
                Layout.fillWidth: true
                visible: !!root.def.description
                text: root.def.description ? I18n.t(root.def.description) : ""
                wrapMode: Text.WordWrap
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                color: Colors.overSurfaceVariant
            }
        }

        Loader {
            active: root.inline
            visible: active
            Layout.fillWidth: root.def.kind !== "toggle"
            sourceComponent: root.def.kind === "toggle" ? toggleComponent : (root.def.kind === "selector" ? selectorComponent : sliderComponent)
        }
    }

    Loader {
        active: !root.inline
        visible: active
        Layout.fillWidth: true
        sourceComponent: colorComponent
    }

    Component {
        id: toggleComponent
        ToggleControl {
            checked: !!root.value
            onToggled: v => root.edited(v)
        }
    }

    Component {
        id: sliderComponent
        SliderControl {
            value: Number(root.value ?? 0)
            from: root.def.min ?? 0
            to: root.def.max ?? 100
            stepSize: root.def.step ?? 1
            unit: root.def.unit ?? ""
            onMoved: v => root.edited(v)
        }
    }

    Component {
        id: selectorComponent
        SelectorControl {
            options: root.def.options || []
            value: root.value
            onSelected: v => root.edited(v)
        }
    }

    Component {
        id: colorComponent
        ColorRoleControl {
            value: root.value
            gradient: root.def.kind === "fill"
            onEdited: v => root.edited(v)
        }
    }
}
