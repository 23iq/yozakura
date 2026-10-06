import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "SurfaceRoles.js" as Roles

// Live swatch of the current surface variant: drawn by StyledRect with that
// variant, so fill, gradient, halftone, border, opacity and item color show
// exactly as the shell renders them.
RowLayout {
    id: root

    property string prop: "srBg"
    property string label: ""

    spacing: 12

    StyledRect {
        objectName: "surfacePreview"
        variant: Roles.variantId(root.prop)
        Layout.preferredWidth: 120
        Layout.preferredHeight: 56
        radius: Styling.radius(-1)
        enableShadow: true

        Text {
            anchors.centerIn: parent
            text: "Aa"
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(2)
            font.bold: true
            color: parent.item
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Text {
            Layout.fillWidth: true
            text: root.label
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            font.bold: true
            color: Colors.overBackground
        }
        Text {
            Layout.fillWidth: true
            text: I18n.t("prefs.surfaces.preview_hint")
            wrapMode: Text.WordWrap
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-3)
            color: Colors.overSurfaceVariant
        }
    }
}
