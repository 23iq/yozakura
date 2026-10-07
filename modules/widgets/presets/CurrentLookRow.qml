import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.widgets.presets.store
import "GalleryTabs.js" as GalleryTabs

// "Current: Yozakura · Sakura · Plum" (the live layout, style and palette,
// PresetParts.parts.current) with "Save as…", which saves them as a set.
Item {
    id: root

    property var parts: PresetParts.parts
    readonly property string text: GalleryTabs.currentText(root.parts, I18n.t("presets.current.custom"))

    signal saveRequested

    objectName: "currentLook"
    implicitHeight: Math.max(Space.chip, label.implicitHeight)

    KitText {
        id: label
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        role: "caption"
        text: I18n.t("presets.current.label")
    }

    KitText {
        objectName: "currentLookText"
        anchors.left: label.right
        anchors.leftMargin: Space.s
        anchors.right: save.left
        anchors.rightMargin: Space.s
        anchors.verticalCenter: parent.verticalCenter
        role: "body"
        text: root.text
    }

    Chip {
        id: save
        objectName: "saveAsSet"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.plus
        text: I18n.t("presets.current.save_as")
        onClicked: root.saveRequested()
    }
}
