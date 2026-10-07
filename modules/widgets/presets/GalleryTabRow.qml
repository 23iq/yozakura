pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "GalleryTabs.js" as GalleryTabs

// The gallery tabs (GalleryTabs.TABS: Sets | Layout | Style | Palette) as
// kit chips; `tab` is the current id, selected(id) on click.
Row {
    id: root

    property string tab: GalleryTabs.TABS[0].id

    signal selected(string id)

    spacing: Space.s

    Repeater {
        model: GalleryTabs.TABS

        delegate: Chip {
            required property var modelData
            objectName: "galleryTab:" + modelData.id
            active: root.tab === modelData.id
            icon: Icons[modelData.icon] ?? ""
            text: I18n.t(modelData.labelKey)
            onClicked: root.selected(modelData.id)
        }
    }
}
