import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.config

// A bar module's icon as its button draws it: the launcher logo
// (`bar.launcherIcon`, a glyph or an image path, else the app's logo) for a
// module whose registry entry has `logo`, its Icons glyph otherwise.
Item {
    id: root

    property var info: ({})
    property string role: "caption"
    property color color: Colors.primary

    readonly property string logo: info.logo ? (Config.bar.launcherIcon || Qt.resolvedUrl("../../../assets/yozakura/yozakura-icon.svg").toString().replace("file://", "")) : ""
    readonly property bool isImage: logo.indexOf("/") >= 0
    readonly property real side: Type.iconSize(role)

    implicitWidth: side
    implicitHeight: side

    Icon {
        anchors.centerIn: parent
        visible: !root.isImage
        role: root.role
        icon: root.info.logo ? root.logo : (Icons[root.info.icon] ?? "")
        color: root.color
    }
    Image {
        anchors.fill: parent
        visible: root.isImage
        source: root.isImage ? "file://" + root.logo : ""
        sourceSize: Qt.size(root.side * 2, root.side * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
