import QtQuick
import Quickshell
import qs.config
import qs.modules.theme
import qs.modules.services
import "AppNames.js" as AppNames

// Focused window: app icon, app name (bold) and title. moduleOptions:
// show ("both" | "app" | "title"), showIcon, maxWidth (px of the title).
BarModuleBase {
    id: root

    moduleKey: "windowTitle"

    readonly property var client: YozdService.focusedClient
    readonly property string appId: client ? (client["class"] || "") : ""
    readonly property var entry: appId !== "" ? DesktopEntries.heuristicLookup(appId) : null
    readonly property string appName: appId === "" ? I18n.t("bar.window_title.desktop") : (entry && entry.name ? entry.name : AppNames.pretty(appId))
    readonly property string title: client && client.title ? client.title : ""
    readonly property string show: options.show !== undefined ? options.show : "both"
    readonly property bool showIcon: options.showIcon !== false && appId !== ""
    readonly property real maxTitle: options.maxWidth !== undefined ? options.maxWidth : 420
    readonly property string iconName: entry && entry.icon ? entry.icon : AppSearch.guessIcon(appId)

    contentLength: vertical ? moduleSize : row.implicitWidth + (flat ? 12 : 24)

    BarModuleSurface {
        id: surface
        module: root
        hovered: hover.hovered
    }

    HoverHandler {
        id: hover
    }

    Row {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 8

        Image {
            visible: root.showIcon
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(root.moduleSize * 0.55)
            height: width
            source: root.appId !== "" ? "image://icon/" + root.iconName : ""
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectFit
            mipmap: true
        }

        Text {
            visible: root.show !== "title"
            anchors.verticalCenter: parent.verticalCenter
            text: root.appName
            font.family: Config.theme.font
            font.pixelSize: root.textSize
            font.weight: Font.Bold
            color: surface.foreground
        }

        Text {
            visible: root.show !== "app" && root.title !== "" && root.title !== root.appName
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.maxTitle)
            text: root.title
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: root.textSize
            color: surface.foreground
            opacity: root.show === "both" ? 0.7 : 1
        }
    }

    // Vertical panels: the app icon only
    Image {
        visible: root.vertical && root.appId !== ""
        anchors.centerIn: parent
        width: Math.round(root.moduleSize * 0.6)
        height: width
        source: visible ? "image://icon/" + root.iconName : ""
        sourceSize: Qt.size(width * 2, height * 2)
        mipmap: true
    }
}
