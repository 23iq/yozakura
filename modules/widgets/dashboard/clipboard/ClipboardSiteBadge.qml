import QtQuick
import qs.modules.components.kit
import "clipboard_utils.js" as ClipboardUtils

// Favicon + site name line of a link embed. The favicon of the preview
// metadata is tried first, then Google's favicon service for the URL.
Row {
    id: badge

    property var preview: null
    property string url: ""

    width: parent.width
    spacing: Space.s
    visible: !!(badge.preview && badge.preview.site_name)

    Item {
        id: favicon
        width: Type.iconSize("caption")
        height: Type.iconSize("caption")
        anchors.verticalCenter: parent.verticalCenter
        visible: primary.status === Image.Ready || fallback.status === Image.Ready

        property bool triedFallback: false

        Image {
            id: primary
            mipmap: true
            anchors.fill: parent
            sourceSize.width: 40
            sourceSize.height: 40
            source: badge.preview && badge.preview.favicon ? (badge.preview.favicon || "") : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
            visible: status === Image.Ready

            onStatusChanged: {
                if (status === Image.Error && !favicon.triedFallback) {
                    favicon.triedFallback = true;
                }
            }
        }

        Image {
            id: fallback
            mipmap: true
            anchors.fill: parent
            sourceSize.width: 40
            sourceSize.height: 40
            source: favicon.triedFallback && badge.url ? ClipboardUtils.getFaviconFallbackUrl(badge.url) : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
            visible: favicon.triedFallback && status === Image.Ready && primary.status !== Image.Ready
        }
    }

    KitText {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - favicon.width - parent.spacing
        role: "caption"
        text: badge.preview?.site_name ?? ""
    }
}
