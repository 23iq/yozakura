import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "SurfaceRoles.js" as Roles
import qs.modules.components.kit

// Live swatch of the current surface variant: drawn by StyledRect with that
// variant, so fill, gradient, halftone, border, opacity and item color show
// exactly as the shell renders them.
RowLayout {
    id: root

    property string prop: "srBg"
    property string label: ""

    spacing: Space.m

    StyledRect {
        id: preview
        objectName: "surfacePreview"
        variant: Roles.variantId(root.prop)
        Layout.preferredWidth: 120
        Layout.preferredHeight: 56
        radius: Look.radius("control")
        enableShadow: true

        KitText {
            role: "title"
            anchors.centerIn: parent
            text: "Aa"
            font.bold: true
            color: preview.item
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Space.xs / 2

        KitText {
            Layout.fillWidth: true
            text: root.label
            elide: Text.ElideRight
            font.bold: true
        }
        KitText {
            role: "caption"
            Layout.fillWidth: true
            text: I18n.t("prefs.surfaces.preview_hint")
            wrapMode: Text.WordWrap
            color: Colors.overSurfaceVariant
        }
    }
}
