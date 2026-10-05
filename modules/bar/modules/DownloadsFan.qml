pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import "Downloads.js" as Downloads

// The fanned-out recent files of DownloadsStack: tiles rising along an arc
// with their names, plus a link to the folder. Clicking opens the file.
Item {
    id: fan

    property var files: []
    property string folder: ""
    property real tileSize: 48
    signal opened

    readonly property real step: tileSize * 0.92
    readonly property var spots: Downloads.fan(files.length, step, 1)
    readonly property real labelSpace: 220
    readonly property real drift: spots.length > 0 ? spots[spots.length - 1].x : 0
    // The tile column starts at the center, right above the stack
    readonly property real column: width / 2 - tileSize / 2

    width: 2 * (labelSpace + tileSize + drift)
    height: (files.length + 1) * step + tileSize * 0.6

    // Folder link at the top of the fan
    StyledRect {
        id: openFolder
        variant: link.containsMouse ? "primary" : "popup"
        radius: height / 2
        height: 28
        width: folderText.implicitWidth + 28
        x: fan.column + fan.drift + fan.tileSize / 2 - width / 2
        y: 0
        Text {
            id: folderText
            anchors.centerIn: parent
            text: I18n.t("bar.downloads.open_folder")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.weight: Font.Medium
            color: openFolder.item
        }
        MouseArea {
            id: link
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Qt.openUrlExternally("file://" + fan.folder);
                fan.opened();
            }
        }
    }

    Repeater {
        model: fan.files
        delegate: Item {
            id: entry
            required property var modelData
            required property int index
            readonly property var spot: fan.spots[index] || ({
                    "x": 0,
                    "y": 0,
                    "rotation": 0
                })
            width: fan.width
            height: fan.tileSize
            y: fan.height - fan.tileSize + spot.y + fan.step * 0.4

            StyledRect {
                id: name
                variant: tileMouse.containsMouse ? "primary" : "popup"
                radius: height / 2
                height: 24
                width: Math.min(fan.labelSpace - 16, nameText.implicitWidth + 22)
                anchors.verticalCenter: tile.verticalCenter
                x: tile.x - width - 10
                Text {
                    id: nameText
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, fan.labelSpace - 38)
                    elide: Text.ElideMiddle
                    text: entry.modelData.name
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: name.item
                }
            }

            Item {
                id: tile
                width: fan.tileSize
                height: fan.tileSize
                x: fan.column + entry.spot.x
                rotation: entry.spot.rotation
                scale: tileMouse.containsMouse ? 1.08 : 1

                Rectangle {
                    anchors.fill: parent
                    visible: Downloads.isImage(entry.modelData.name)
                    radius: 6
                    color: "white"
                    Image {
                        anchors.fill: parent
                        anchors.margins: 3
                        source: parent.visible ? entry.modelData.url : ""
                        sourceSize: Qt.size(fan.tileSize * 2, fan.tileSize * 2)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                Image {
                    anchors.fill: parent
                    visible: !Downloads.isImage(entry.modelData.name)
                    source: visible ? "image://icon/" + Downloads.iconFor(entry.modelData.name) : ""
                    sourceSize: Qt.size(fan.tileSize * 2, fan.tileSize * 2)
                }
            }

            MouseArea {
                id: tileMouse
                x: name.x
                width: tile.x + tile.width - name.x
                height: parent.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Qt.openUrlExternally(entry.modelData.url);
                    fan.opened();
                }
            }
        }
    }
}
