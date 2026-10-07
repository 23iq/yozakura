import QtQuick
import qs.modules.theme
import qs.modules.components

// Row icon: type glyph, or the site favicon for URLs (cached preview favicon,
// then Google's PNG service, then /favicon.ico), plus the pin badge.
Item {
    id: icon

    required property ClipboardTabBase tab
    required property var entry
    property bool isInDeleteMode: false
    property bool isInAliasMode: false
    property bool isExpanded: false
    property bool isSelected: false

    StyledRect {
        id: iconBackground
        anchors.fill: parent
        visible: !faviconImage.visible
        variant: {
            if (icon.isInDeleteMode) {
                return "overerror";
            } else if (icon.isInAliasMode) {
                return "oversecondary";
            } else if (icon.isExpanded) {
                return "primary";
            } else {
                return "common";
            }
        }
        radius: Styling.radius(-4)

        property string iconType: {
            if (icon.isInDeleteMode) {
                return "trash";
            } else if (icon.isInAliasMode) {
                return "edit";
            }
            return icon.tab.getIconForItem(icon.entry);
        }

        property string faviconUrl: {
            // Rebind when new previews are fetched
            var _rev = icon.tab.linkPreviewCacheRevision;
            if (iconType !== "link")
                return "";
            var url = icon.tab.getFaviconUrl(icon.entry);
            return (url && url !== "") ? url : "";
        }

        property string faviconFallbackUrl: {
            if (iconType !== "link")
                return "";
            return icon.tab.getFaviconFallbackUrl(icon.entry);
        }

        property bool faviconLoaded: false
        property bool triedFallback: false

        // Update favicon when URL changes (e.g., from cache update)
        onFaviconUrlChanged: {
            if (faviconUrl !== "" && faviconUrl !== faviconImage.source) {
                faviconLoaded = false;
                triedFallback = false;
                faviconImage.source = faviconUrl;
            }
        }

        Text {
            anchors.centerIn: parent
            visible: (iconBackground.iconType !== "link") || (iconBackground.iconType === "link" && !iconBackground.faviconLoaded)
            text: {
                if (icon.isInDeleteMode) {
                    return Icons.trash;
                } else if (icon.isInAliasMode) {
                    return Icons.edit;
                }
                var iconStr = iconBackground.iconType;
                if (iconStr === "image")
                    return Icons.image;
                if (iconStr === "file")
                    return Icons.file;
                if (iconStr === "link")
                    return Icons.globe; // URL without (working) favicon
                return Icons.clip;
            }
            color: iconBackground.item
            font.family: Icons.font
            font.pixelSize: 16
            textFormat: Text.RichText
        }
    }

    // Favicon for URLs (outside the StyledRect for independent sizing/background)
    Image {
        id: faviconImage
        mipmap: true
        anchors.fill: parent
        sourceSize.width: 32
        sourceSize.height: 32
        visible: iconBackground.iconType === "link" && iconBackground.faviconLoaded && status === Image.Ready
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true

        onStatusChanged: {
            if (status === Image.Ready) {
                iconBackground.faviconLoaded = true;
            } else if (status === Image.Error) {
                // Try the fallback URL once
                if (!iconBackground.triedFallback && iconBackground.faviconFallbackUrl !== "") {
                    iconBackground.triedFallback = true;
                    faviconImage.source = iconBackground.faviconFallbackUrl;
                } else {
                    iconBackground.faviconLoaded = false;
                }
            } else if (status === Image.Null || status === Image.Loading) {
                iconBackground.faviconLoaded = false;
            }
        }
    }

    Timer {
        interval: 1
        running: iconBackground.iconType === "link" && iconBackground.faviconUrl !== "" && faviconImage.source === ""
        onTriggered: {
            if (iconBackground.faviconUrl !== "") {
                iconBackground.triedFallback = false;
                faviconImage.source = iconBackground.faviconUrl;
            }
        }
    }

    // Pin badge (outside the StyledRect to avoid clipping)
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -2
        anchors.rightMargin: -2
        width: 14
        height: 14
        radius: 7
        visible: icon.entry.pinned && !icon.isInDeleteMode && !icon.isInAliasMode
        color: Styling.srItem("overprimary")

        Text {
            anchors.centerIn: parent
            text: Icons.pin
            font.family: Icons.font
            font.pixelSize: 8
            color: Colors.overPrimary
            textFormat: Text.RichText
        }
    }
}
