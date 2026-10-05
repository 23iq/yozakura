import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "clipboard_utils.js" as ClipboardUtils
import "ClipboardView.js" as ClipboardView

// Compact card for a URL without embed data: favicon (Google's service, then
// /favicon.ico, then a globe) and the host name. Clicking opens the item.
Rectangle {
    id: card

    property var item: null
    property string url: ""

    signal openRequested(string itemId)

    height: 60
    color: urlPreviewMouseArea.containsMouse ? Colors.surfaceBright : Colors.surface
    radius: Styling.radius(4)

    Behavior on color {
        enabled: Config.animDuration > 0
        ColorAnimation {
            duration: Config.animDuration / 2
            easing.type: Easing.OutQuart
        }
    }

    MouseArea {
        id: urlPreviewMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (card.item) {
                card.openRequested(card.item.id);
            }
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
            width: 36
            height: 36
            color: Colors.surfaceBright
            radius: Styling.radius(-4)

            Image {
                id: previewFavicon
                mipmap: true
                anchors.centerIn: parent
                width: 24
                height: 24
                visible: card.item !== null && status === Image.Ready
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true

                property bool triedFallback: false
                // Google service (PNG) first to avoid ICO decode errors
                property string primarySource: card.item ? ClipboardUtils.getFaviconFallbackUrl(card.url) : ""

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

            Text {
                anchors.centerIn: parent
                visible: !previewFavicon.visible
                text: Icons.globe
                font.family: Icons.font
                font.pixelSize: 20
                color: Styling.srItem("overprimary")
                textFormat: Text.RichText
            }
        }

        Column {
            width: parent.width - 48 - parent.spacing
            height: parent.height
            spacing: 4

            Text {
                text: I18n.t("clipboard.link")
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize - 1
                font.weight: Font.Medium
                color: Colors.outline
            }

            Text {
                text: card.item ? ClipboardView.hostLabel(card.url) : ""
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize
                font.weight: Font.Bold
                color: Colors.overBackground
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }
}
