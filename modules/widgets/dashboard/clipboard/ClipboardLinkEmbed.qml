import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Embed of a link preview on a ClipboardCard: a large 16:9 thumbnail with a
// play action for videos, otherwise the text beside a small thumbnail.
// Clicking opens the URL.
ClipboardCard {
    id: embed

    // Link preview metadata (title, description, image, site_name, favicon,
    // type) and the URL it belongs to.
    property var preview: null
    property string url: ""
    readonly property bool isVideo: !!embed.preview && embed.preview.type === 'video'
    readonly property string image: embed.preview && embed.preview.image ? embed.preview.image : ""
    readonly property string title: embed.preview && embed.preview.title ? embed.preview.title : ""
    readonly property string description: embed.preview && embed.preview.description ? embed.preview.description : ""

    function open() {
        if (embed.url)
            Qt.openUrlExternally(embed.url.trim());
    }

    // Title (two lines) and description of either layout.
    component EmbedText: Column {
        id: texts

        property string title: ""
        property string description: ""
        property int descriptionLines: 2

        spacing: Space.xs

        KitText {
            width: parent.width
            visible: text.length > 0
            role: "body"
            font.weight: Font.DemiBold
            text: texts.title
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }

        KitText {
            width: parent.width
            visible: text.length > 0
            role: "secondary"
            text: texts.description
            wrapMode: Text.Wrap
            maximumLineCount: texts.descriptionLines
        }
    }

    objectName: "linkEmbed"
    width: parent.width
    height: (embed.isVideo ? videoContent.height : linkContent.height) + Look.boxPadding * 2
    visible: embed.preview && !embed.preview.error && (embed.preview.title || embed.preview.description || embed.preview.image)
    onClicked: embed.open()

    // Video layout (YouTube, etc.)
    Column {
        id: videoContent
        x: Look.boxPadding
        y: Look.boxPadding
        width: parent.width - Look.boxPadding * 2
        spacing: Space.s
        visible: embed.isVideo

        ClipboardSiteBadge {
            preview: embed.preview
            url: embed.url
        }

        Art {
            width: parent.width
            height: width * 9 / 16
            visible: embed.image !== ""
            source: embed.image
            icon: Icons.play

            IconButton {
                anchors.centerIn: parent
                visible: parent.ready
                size: "l"
                primary: true
                icon: Icons.play
                onClicked: embed.open()
            }
        }

        EmbedText {
            width: parent.width
            title: embed.title
            description: embed.description
        }
    }

    // Regular link layout
    Row {
        id: linkContent
        x: Look.boxPadding
        y: Look.boxPadding
        width: parent.width - Look.boxPadding * 2
        spacing: Space.m
        visible: !embed.isVideo

        Column {
            width: embed.image ? parent.width - thumb.width - parent.spacing : parent.width
            spacing: Space.s

            ClipboardSiteBadge {
                preview: embed.preview
                url: embed.url
            }

            EmbedText {
                width: parent.width
                title: embed.title
                description: embed.description
                descriptionLines: 3
            }
        }

        Art {
            id: thumb
            width: Space.controlXL
            height: Space.controlXL
            anchors.verticalCenter: parent.verticalCenter
            visible: embed.image !== ""
            source: embed.image
        }
    }
}
