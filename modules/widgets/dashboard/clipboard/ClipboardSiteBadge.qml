import QtQuick
import qs.modules.theme
import qs.config
import "clipboard_utils.js" as ClipboardUtils

// Favicon + site name line of a link embed. The favicon of the preview
// metadata is tried first, then Google's favicon service for the URL.
Row {
    id: badge

    property var preview: null
    property string url: ""

    width: parent.width
    spacing: 8
    visible: badge.preview && badge.preview.site_name

    Item {
        id: favicon
        width: 16
        height: 16
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

    Text {
        text: badge.preview ? badge.preview.site_name : ""
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        font.weight: Font.Medium
        color: Colors.outline
        elide: Text.ElideRight
        width: parent.width - 24
    }
}
