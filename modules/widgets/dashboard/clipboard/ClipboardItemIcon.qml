import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Leading slot of a history row: the type glyph, or the site favicon for
// URLs (cached preview favicon, then Google's PNG service, then
// /favicon.ico). Delete / alias modes show the trash / edit glyph.
Item {
    id: icon

    required property ClipboardTabBase tab
    required property var entry
    property bool isInDeleteMode: false
    property bool isInAliasMode: false

    readonly property string iconType: {
        if (icon.isInDeleteMode)
            return "trash";
        if (icon.isInAliasMode)
            return "edit";
        return icon.tab.getIconForItem(icon.entry);
    }
    readonly property string faviconUrl: {
        // Rebind when new previews are fetched
        var _rev = icon.tab.linkPreviewCacheRevision;
        if (icon.iconType !== "link")
            return "";
        var url = icon.tab.getFaviconUrl(icon.entry);
        return (url && url !== "") ? url : "";
    }
    readonly property string faviconFallbackUrl: icon.iconType === "link" ? icon.tab.getFaviconFallbackUrl(icon.entry) : ""
    property bool faviconLoaded: false
    property bool triedFallback: false

    implicitWidth: Metrics.iconSize
    implicitHeight: Metrics.iconSize

    onFaviconUrlChanged: {
        if (faviconUrl !== "" && faviconUrl !== faviconImage.source) {
            faviconLoaded = false;
            triedFallback = false;
            faviconImage.source = faviconUrl;
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !faviconImage.visible
        text: ({
                "trash": Icons.trash,
                "edit": Icons.edit,
                "image": Icons.image,
                "file": Icons.file,
                "link": Icons.globe // URL without (working) favicon
            })[icon.iconType] || Icons.clip
        color: icon.isInDeleteMode ? Colors.error : Type.secondary
        font.family: Icons.font
        font.pixelSize: Type.iconSize("body")
    }

    Image {
        id: faviconImage
        anchors.centerIn: parent
        width: Type.iconSize("body") + 2
        height: width
        mipmap: true
        sourceSize.width: 32
        sourceSize.height: 32
        visible: icon.iconType === "link" && icon.faviconLoaded && status === Image.Ready
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        onStatusChanged: {
            if (status === Image.Ready) {
                icon.faviconLoaded = true;
            } else if (status === Image.Error) {
                // Try the fallback URL once
                if (!icon.triedFallback && icon.faviconFallbackUrl !== "") {
                    icon.triedFallback = true;
                    faviconImage.source = icon.faviconFallbackUrl;
                } else {
                    icon.faviconLoaded = false;
                }
            } else if (status === Image.Null || status === Image.Loading) {
                icon.faviconLoaded = false;
            }
        }
    }

    Timer {
        interval: 1
        running: icon.iconType === "link" && icon.faviconUrl !== "" && faviconImage.source === ""
        onTriggered: {
            if (icon.faviconUrl !== "") {
                icon.triedFallback = false;
                faviconImage.source = icon.faviconUrl;
            }
        }
    }
}
