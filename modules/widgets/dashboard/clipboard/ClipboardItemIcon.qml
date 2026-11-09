import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Leading slot of a history row: the type glyph, or the site favicon for
// URLs (cached preview favicon, then Google's PNG service, then
// /favicon.ico). Delete / alias modes show the trash / edit glyph.
Item {
    id: itemIcon

    required property ClipboardTabBase tab
    required property var entry
    property bool isInDeleteMode: false
    property bool isInAliasMode: false

    readonly property string iconType: {
        if (itemIcon.isInDeleteMode)
            return "trash";
        if (itemIcon.isInAliasMode)
            return "edit";
        return itemIcon.tab.getIconForItem(itemIcon.entry);
    }
    readonly property string faviconUrl: {
        // Rebind when new previews are fetched
        var _rev = itemIcon.tab.linkPreviewCacheRevision;
        if (itemIcon.iconType !== "link")
            return "";
        var url = itemIcon.tab.getFaviconUrl(itemIcon.entry);
        return (url && url !== "") ? url : "";
    }
    readonly property string faviconFallbackUrl: itemIcon.iconType === "link" ? itemIcon.tab.getFaviconFallbackUrl(itemIcon.entry) : ""
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

    Icon {
        anchors.centerIn: parent
        visible: !faviconImage.visible
        role: "body"
        icon: ({
                "trash": Icons.trash,
                "edit": Icons.edit,
                "image": Icons.image,
                "file": Icons.file,
                "link": Icons.globe // URL without (working) favicon
            })[itemIcon.iconType] || Icons.clip
        color: itemIcon.isInDeleteMode ? Type.danger : Type.secondary
    }

    Image {
        id: faviconImage
        anchors.centerIn: parent
        width: Type.iconSize("body") + 2
        height: width
        mipmap: true
        sourceSize.width: 32
        sourceSize.height: 32
        visible: itemIcon.iconType === "link" && itemIcon.faviconLoaded && status === Image.Ready
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        onStatusChanged: {
            if (status === Image.Ready) {
                itemIcon.faviconLoaded = true;
            } else if (status === Image.Error) {
                // Try the fallback URL once
                if (!itemIcon.triedFallback && itemIcon.faviconFallbackUrl !== "") {
                    itemIcon.triedFallback = true;
                    faviconImage.source = itemIcon.faviconFallbackUrl;
                } else {
                    itemIcon.faviconLoaded = false;
                }
            } else if (status === Image.Null || status === Image.Loading) {
                itemIcon.faviconLoaded = false;
            }
        }
    }

    Timer {
        interval: 1
        running: itemIcon.iconType === "link" && itemIcon.faviconUrl !== "" && faviconImage.source === ""
        onTriggered: {
            if (itemIcon.faviconUrl !== "") {
                itemIcon.triedFallback = false;
                faviconImage.source = itemIcon.faviconUrl;
            }
        }
    }
}
