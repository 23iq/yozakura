import QtQuick
import qs.modules.theme

// The surface of a bar popup (BarPopup, and the settings' preview of a
// menu): theme.popup's entry motion toward its anchor (PopupMotion: `shown`,
// `dir`, `anchorAlong`), its tail (theme.popup.tail), the cursor lantern and
// the box (StyledRect in `variant`, the popups' glass, the kit surface
// radius, the `tab` corner toward the anchor). Content: default children,
// `padding` inside the box.
PopupMotion {
    id: root

    property string variant: "popup"
    property real padding: 0
    default property alias contentData: contentContainer.data
    // the box (a popup's input region)
    readonly property Item box: background

    tailVariant: root.variant

    // Pointer of the cursor lantern for the popup's surface
    LanternScope {}

    StyledRect {
        id: background
        anchors.fill: parent
        variant: root.variant
        glassSurface: "popups"
        enableShadow: true
        radius: Styling.radius(0) // the kit surface radius (Space.surfaceRadius)
        anchorEdge: root.anchorEdge

        Item {
            id: contentContainer
            anchors.fill: parent
            anchors.margins: root.padding
        }
    }
}
