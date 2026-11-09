import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.globals
import qs.modules.components.kit

Item {
    id: root

    required property string itemName
    required property string itemPath
    required property string itemType
    required property string itemIcon
    property bool isDesktopFile: false

    readonly property string thumbnailPath: {
        const ext = itemPath.substring(itemPath.lastIndexOf('.') + 1).toLowerCase();
        const videoExts = ['mp4', 'webm', 'mov', 'avi', 'mkv', 'gif'];
        const imageExts = ['jpg', 'jpeg', 'png', 'webp', 'tif', 'tiff', 'bmp'];

        if (itemType === 'folder' || isDesktopFile) {
            return '';
        }

        if (videoExts.includes(ext) || imageExts.includes(ext)) {
            const fileName = itemPath.substring(itemPath.lastIndexOf('/') + 1);
            // QUICKSHELL-GIT: return Quickshell.cacheDir + "/desktop_thumbnails/" + fileName + ".jpg";
            return Brand.cacheDir + "/desktop_thumbnails/" + fileName + ".jpg";
        }

        return '';
    }

    readonly property bool hasThumbnail: thumbnailPath !== '' && Qt.platform.os !== "windows"
    property int thumbnailRefresh: 0

    FileView {
        path: root.thumbnailPath
        watchChanges: root.hasThumbnail

        onFileChanged: {
            root.thumbnailRefresh++;
        }
    }

    signal activated
    signal contextMenuRequested

    width: Config.desktop.iconSize * 1.5
    // Desktop.qml / DepthClock.qml lay the grid out with the same + 40.
    height: Config.desktop.iconSize + 40

    // Hover box: the language's raised control fill (a soft ink wash where
    // controls are ghosts).
    Rectangle {
        id: background
        anchors.fill: root
        color: Look.raisedFill(true)
        radius: Look.radius("control")
        opacity: hoverHandler.hovered ? 1 : 0

        Behavior on opacity {
            enabled: Motion.micro.duration > 0
            NumberAnimation {
                duration: Motion.micro.duration
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onDoubleTapped: {
            root.activated();

            if (root.isDesktopFile) {
                console.log("Executing desktop file:", root.itemPath);
                DesktopService.executeDesktopFile(root.itemPath);
            } else if (root.itemType === 'folder') {
                console.log("Opening folder:", root.itemPath);
                DesktopService.openFile(root.itemPath);
            } else {
                console.log("Opening file:", root.itemPath);
                DesktopService.openFile(root.itemPath);
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
            root.contextMenuRequested();
        }
    }

    HoverHandler {
        id: hoverHandler
    }

    ColumnLayout {
        id: contentLayout
        anchors.fill: root
        anchors.margins: Space.s
        spacing: Space.xs
        layer.enabled: true
        layer.effect: Shadow {}

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Config.desktop.iconSize
            Layout.preferredHeight: Config.desktop.iconSize

            Loader {
                id: iconLoader
                anchors.centerIn: parent
                width: Config.desktop.iconSize
                height: Config.desktop.iconSize
                sourceComponent: Config.tintIcons && !root.hasThumbnail ? tintedIconComponent : normalIconComponent
            }

            // Fallback glyph when the (untinted) icon image fails to load.
            Icon {
                anchors.centerIn: parent
                visible: (iconLoader.item as Image)?.status === Image.Error
                icon: root.itemType === 'folder' ? Icons.folder : Icons.file
                size: Config.desktop.iconSize / 2
                tone: "secondary"
            }
        }

        KitText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            text: root.itemName
            color: Config.resolveColor(Config.desktop.textColor)
            font.weight: Look.activeLabelWeight
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }
    }

    Component {
        id: normalIconComponent
        Image {
            mipmap: true
            property bool thumbnailExists: false
            source: {
                root.thumbnailRefresh;
                if (root.hasThumbnail) {
                    return "file://" + root.thumbnailPath;
                }
                return "image://icon/" + root.itemIcon;
            }
            fillMode: Image.PreserveAspectFit
            // Decode at the shown size (x2 for HiDPI), not the file's size
            sourceSize: Qt.size(Config.desktop.iconSize * 2, Config.desktop.iconSize * 2)
            asynchronous: true
            smooth: true
            cache: false

            onStatusChanged: {
                if (status === Image.Ready && root.hasThumbnail) {
                    thumbnailExists = true;
                } else if (status === Image.Error && root.hasThumbnail) {
                    thumbnailExists = false;
                    source = "image://icon/" + root.itemIcon;
                }
            }
        }
    }

    Component {
        id: tintedIconComponent
        Tinted {
            sourceItem: Image {
                mipmap: true
                property bool thumbnailExists: false
                source: {
                    root.thumbnailRefresh;
                    if (root.hasThumbnail) {
                        return "file://" + root.thumbnailPath;
                    }
                    return "image://icon/" + root.itemIcon;
                }
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(Config.desktop.iconSize * 2, Config.desktop.iconSize * 2)
                asynchronous: true
                smooth: true
                cache: false

                onStatusChanged: {
                    if (status === Image.Ready && root.hasThumbnail) {
                        thumbnailExists = true;
                    } else if (status === Image.Error && root.hasThumbnail) {
                        thumbnailExists = false;
                        source = "image://icon/" + root.itemIcon;
                    }
                }
            }
        }
    }
}
