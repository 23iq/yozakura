import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "clipboard_utils.js" as ClipboardUtils
import "ClipboardView.js" as ClipboardView

// Compact card for a URL without embed data: favicon (Google's service, then
// /favicon.ico, then a globe) and the host name. Clicking opens the item.
ClipboardCard {
    id: card

    property var clipItem: null
    property string url: ""

    signal openRequested(string itemId)

    objectName: "urlCard"
    height: row.implicitHeight + Look.boxPadding * 2
    onClicked: {
        if (card.clipItem)
            card.openRequested(card.clipItem.id);
    }

    Row {
        id: row
        x: Look.boxPadding
        y: Look.boxPadding
        width: parent.width - Look.boxPadding * 2
        spacing: Space.m

        Item {
            id: badge
            width: Space.controlS
            height: Space.controlS
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: previewFavicon
                mipmap: true
                anchors.centerIn: parent
                width: Type.iconSize("title")
                height: Type.iconSize("title")
                sourceSize: Qt.size(width * 2, height * 2)
                visible: card.clipItem !== null && status === Image.Ready
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true

                property bool triedFallback: false
                // Google service (PNG) first to avoid ICO decode errors
                property string primarySource: card.clipItem ? ClipboardUtils.getFaviconFallbackUrl(card.url) : ""

                source: primarySource

                onPrimarySourceChanged: {
                    triedFallback = false;
                    source = primarySource;
                }

                onStatusChanged: {
                    if (status === Image.Error && !triedFallback) {
                        triedFallback = true;
                        // Then the site's own /favicon.ico
                        source = ClipboardUtils.getFaviconUrl(card.url);
                    }
                }
            }

            Icon {
                anchors.centerIn: parent
                visible: !previewFavicon.visible
                icon: Icons.globe
                role: "title"
                tone: "secondary"
            }
        }

        Column {
            width: parent.width - badge.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.xs

            KitText {
                role: "caption"
                text: I18n.t("clipboard.link")
            }

            KitText {
                width: parent.width
                role: "body"
                font.weight: Font.DemiBold
                text: card.clipItem ? ClipboardView.hostLabel(card.url) : ""
            }
        }
    }
}
