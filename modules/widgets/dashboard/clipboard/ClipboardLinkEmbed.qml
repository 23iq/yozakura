import QtQuick
import Quickshell.Widgets
import qs.modules.theme
import qs.config

// Discord-style embed of a link preview: a large thumbnail layout for videos,
// otherwise text with a small thumbnail. Clicking opens the URL.
Rectangle {
    id: embed

    // Link preview metadata (title, description, image, site_name, favicon,
    // type) and the URL it belongs to.
    property var preview: null
    property string url: ""

    width: parent.width
    height: {
        // Videos (YouTube) use the larger layout
        if (embed.preview && embed.preview.type === 'video' && embed.preview.image) {
            return videoEmbedContent.height + 24;
        }
        return linkEmbedContent.height + 24;
    }
    visible: embed.preview && !embed.preview.error && (embed.preview.title || embed.preview.description || embed.preview.image)
    color: linkPreviewMouseArea.containsMouse ? Colors.surfaceBright : Colors.surface

    // Rounded corners only on the right side
    topLeftRadius: 0
    topRightRadius: Config.roundness > 0 ? Config.roundness + 4 : 0
    bottomLeftRadius: 0
    bottomRightRadius: Config.roundness > 0 ? Config.roundness + 4 : 0

    Behavior on color {
        enabled: Config.animDuration > 0
        ColorAnimation {
            duration: Config.animDuration / 2
            easing.type: Easing.OutQuart
        }
    }

    MouseArea {
        id: linkPreviewMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (embed.url) {
                Qt.openUrlExternally(embed.url.trim());
            }
        }
    }

    // Left accent bar
    Rectangle {
        x: 0
        y: 0
        width: 4
        height: parent.height
        color: Styling.srItem("overprimary")

        // Rounded corners only on the left side
        topLeftRadius: Config.roundness > 0 ? Config.roundness + 4 : 0
        topRightRadius: 0
        bottomLeftRadius: Config.roundness > 0 ? Config.roundness + 4 : 0
        bottomRightRadius: 0
    }

    // Video layout (YouTube, etc.)
    Column {
        id: videoEmbedContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        anchors.leftMargin: 16
        spacing: 10
        visible: embed.preview && embed.preview.type === 'video'

        ClipboardSiteBadge {
            preview: embed.preview
            url: embed.url
        }

        // Thumbnail with play overlay
        ClippingRectangle {
            id: videoThumbnailContainer
            width: parent.width
            height: width * 9 / 16
            color: Colors.surfaceBright
            radius: Styling.radius(-4)
            visible: embed.preview && embed.preview.image

            Image {
                id: videoThumbnail
                mipmap: true
                anchors.fill: parent
                source: embed.preview && embed.preview.image ? embed.preview.image : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true

                // Dark overlay
                Rectangle {
                    anchors.fill: parent
                    color: "#40000000"
                    radius: videoThumbnailContainer.radius
                }

                // Play button
                Rectangle {
                    anchors.centerIn: parent
                    width: 60
                    height: 60
                    radius: 30
                    color: Styling.srItem("overprimary")
                    opacity: 0.9

                    Text {
                        anchors.centerIn: parent
                        text: Icons.play
                        font.family: Icons.font
                        font.pixelSize: 28
                        color: Colors.overPrimary
                        textFormat: Text.RichText
                    }
                }

                // Loading indicator
                Rectangle {
                    id: imageLoadingRect
                    anchors.fill: parent
                    color: Colors.surfaceBright
                    radius: videoThumbnailContainer.radius
                    visible: videoThumbnail.status === Image.Loading

                    Text {
                        anchors.centerIn: parent
                        text: Icons.spinnerGap
                        font.family: Icons.font
                        font.pixelSize: 32
                        color: Styling.srItem("overprimary")
                        textFormat: Text.RichText

                        RotationAnimator on rotation {
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: imageLoadingRect.visible
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            text: embed.preview && embed.preview.title ? embed.preview.title : ""
            font.family: Config.theme.font
            font.pixelSize: Config.theme.fontSize + 1
            font.weight: Font.Bold
            color: Colors.overBackground
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            visible: text.length > 0
        }

        Text {
            width: parent.width
            text: embed.preview && embed.preview.description ? embed.preview.description : ""
            font.family: Config.theme.font
            font.pixelSize: Config.theme.fontSize
            color: Colors.outline
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            visible: text.length > 0
        }
    }

    // Regular link layout
    Row {
        id: linkEmbedContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        anchors.leftMargin: 16
        spacing: 12
        visible: !embed.preview || embed.preview.type !== 'video'

        Column {
            width: embed.preview && embed.preview.image ? parent.width - 100 - parent.spacing : parent.width
            spacing: 6

            ClipboardSiteBadge {
                preview: embed.preview
                url: embed.url
            }

            Text {
                width: parent.width
                text: embed.preview && embed.preview.title ? embed.preview.title : ""
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize + 1
                font.weight: Font.Bold
                color: Colors.overBackground
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                visible: text.length > 0
            }

            Text {
                width: parent.width
                text: embed.preview && embed.preview.description ? embed.preview.description : ""
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize
                color: Colors.outline
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }

        // Thumbnail
        Rectangle {
            id: linkThumbnailContainer
            width: 100
            height: 100
            color: Colors.surfaceBright
            radius: Styling.radius(-4)
            visible: embed.preview && embed.preview.image
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: linkThumbnail
                mipmap: true
                anchors.fill: parent
                source: embed.preview && embed.preview.image ? embed.preview.image : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true

                Rectangle {
                    anchors.fill: parent
                    color: Colors.surfaceBright
                    radius: linkThumbnailContainer.radius
                    visible: linkThumbnail.status === Image.Loading

                    Text {
                        anchors.centerIn: parent
                        text: Icons.spinnerGap
                        font.family: Icons.font
                        font.pixelSize: 24
                        color: Styling.srItem("overprimary")
                        textFormat: Text.RichText
                    }
                }
            }
        }
    }
}
