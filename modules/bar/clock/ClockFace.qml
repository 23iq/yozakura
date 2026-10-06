pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import "ClockFaces.js" as ClockFaces

// The bar clock time, drawn by one face of ClockFaces.js (faces/*.qml).
// Faces read this item as `clock`: parts {hours, minutes, suffix}, kanji,
// textColor, fontSize, fontFamily, vertical.
Item {
    id: root

    property string face: "digital"
    property bool vertical: false
    property bool use12h: false
    property date now: new Date()
    property color textColor: "white"
    property int fontSize: Config.theme.fontSize
    property string fontFamily: Config.theme.font

    readonly property var entry: ClockFaces.resolve(root.face, root.vertical)
    readonly property string faceId: root.entry.id
    readonly property var parts: ClockFaces.parts(root.now.getHours(), root.now.getMinutes(), root.use12h)
    readonly property string kanji: ClockFaces.kanjiTime(root.now.getHours(), root.now.getMinutes(), root.use12h)

    implicitWidth: (loader.item as Item)?.implicitWidth ?? 0
    implicitHeight: (loader.item as Item)?.implicitHeight ?? 0

    function reload() {
        loader.setSource(Qt.resolvedUrl(root.entry.url), {
            "clock": root
        });
    }

    onEntryChanged: root.reload()
    Component.onCompleted: root.reload()

    Loader {
        id: loader
        objectName: "clockFaceLoader"
        anchors.centerIn: parent
    }
}
