import QtQuick
import qs.modules.components.kit
import qs.modules.theme
import qs.modules.services
import "ClipboardView.js" as ClipboardView

// Preview of an image item or an image file: still image, animated GIF, or a
// placeholder while it loads.
Item {
    id: preview

    // Selected clipboard item (or null) and its full content.
    property var item: null
    property string content: ""

    readonly property bool isImageFile: !!preview.item && !!preview.item.isFile && ClipboardView.isImagePath(ClipboardView.filePathFromUri(preview.content))
    readonly property bool isGifImage: ClipboardView.isGif(preview.item, preview.content)

    function sourceFor(wantGif) {
        if (preview.item && preview.isGifImage === wantGif) {
            if (preview.item.isImage) {
                ClipboardService.revision;
                return ClipboardService.getImageData(preview.item.id);
            } else if (preview.isImageFile) {
                var filePath = ClipboardView.filePathFromUri(preview.content);
                return filePath ? "file://" + filePath : "";
            }
        }
        return "";
    }

    Image {
        id: previewImage
        mipmap: true
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        visible: preview.item && (preview.item.isImage || preview.isImageFile) && !preview.isGifImage
        source: preview.sourceFor(false)
        clip: true
        cache: false
        asynchronous: true
    }

    AnimatedImage {
        id: previewGif
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        visible: preview.item && (preview.item.isImage || preview.isImageFile) && preview.isGifImage
        source: preview.sourceFor(true)
        clip: true
        cache: false
        asynchronous: true
        playing: true
    }

    // Placeholder while the image is not ready
    Rectangle {
        anchors.centerIn: parent
        width: Space.controlXL
        height: Space.controlXL
        color: Type.placeholder
        radius: Space.controlRadius
        visible: {
            if (!preview.item)
                return false;
            if (!(preview.item.isImage || preview.isImageFile))
                return false;
            if (previewImage.visible) {
                return previewImage.status !== Image.Ready;
            } else if (previewGif.visible) {
                return previewGif.status !== AnimatedImage.Ready;
            }
            return false;
        }

        Text {
            anchors.centerIn: parent
            text: Icons.image
            textFormat: Text.RichText
            font.family: Icons.font
            font.pixelSize: Type.iconSize("display")
            color: Type.muted
        }
    }
}
