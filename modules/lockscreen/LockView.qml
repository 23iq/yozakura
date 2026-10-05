pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.modules.components
import qs.modules.services
import qs.modules.theme
import qs.config
import "styles"
import "styles/LockStyleRegistry.js" as Registry
import "LockLayout.js" as LockLayout

// Everything the lock surface draws: the wallpaper (blurred as the style
// asks) and the active style's backdrop, clock, status strip, media card and
// password field, placed by the style's arrangement.
// It holds no authentication logic; LockScreen.qml drives it. The settings
// gallery renders it with `preview: true` (no focus grabs, no cava).
Item {
    id: root

    property bool startAnim: false
    property bool authenticating: false
    property string errorMessage: ""
    property int failLockSecondsLeft: 0
    property bool capsLock: false
    property string username: ""
    property string hostname: ""
    property string wallpaperSource: ""
    property bool tintEnabled: false

    // Style and tone; the settings gallery overrides them per card.
    property string styleId: Config.lockscreen?.style ?? Registry.DEFAULT_ID
    property string tone: Config.lockscreen?.tone ?? "style"
    property bool preview: false

    readonly property var styleEntry: Registry.get(styleId)
    readonly property bool light: Registry.resolveTone(styleEntry.id, tone, Config.lightMode ?? false) === "light"
    // The active LockStyle (var: the styles import this module).
    readonly property var style: styleLoader.item

    readonly property alias wallpaper: wallpaperBackground
    readonly property LockPasswordBase passwordPill: passwordLoader.item as LockPasswordBase
    readonly property TextField passwordField: passwordPill ? passwordPill.field : null
    readonly property LockMediaBase mediaCard: mediaLoader.item as LockMediaBase

    readonly property bool atTop: (Config.lockscreen?.position ?? "bottom") === "top"
    readonly property bool hasMedia: MprisController.activePlayer !== null && MprisController.activePlayer !== undefined
    readonly property bool showMedia: Config.lockscreen?.showMedia ?? true
    readonly property bool showVisualizer: Config.lockscreen?.showVisualizer ?? true
    readonly property bool showStatus: Config.lockscreen?.showStatus ?? true
    readonly property real wallpaperBlur: Registry.blurFor(Config.lockscreen?.blur ?? -1, style ? style.wallpaperBlur : 0.7)
    readonly property real edgeMargin: Math.round(Math.max(32, height * 0.05))
    readonly property int revealDuration: Math.max(1, Config.animDuration * 2)

    // Shared clock for every style (one timer per lock surface).
    property date now: new Date()
    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // 0 -> 1 as the lock screen comes in; drives fade/scale of the chrome.
    property real reveal: startAnim ? 1 : 0
    Behavior on reveal {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: root.revealDuration
            easing.type: Easing.OutCubic
        }
    }

    function focusPassword() {
        if (!preview && passwordField)
            passwordField.forceActiveFocus();
    }

    // A style switch while locked swaps the field: keep typing focus.
    onPasswordFieldChanged: {
        if (startAnim)
            Qt.callLater(focusPassword);
    }

    Loader {
        id: styleLoader
        source: Qt.resolvedUrl("styles/" + root.styleEntry.file)
        onLoaded: root.style.view = root
    }
    Binding {
        target: root.style
        property: "light"
        value: root.light
        when: root.style !== null
    }

    // ── Backdrop ────────────────────────────────────────────────────────
    TintedWallpaper {
        id: wallpaperBackground
        anchors.fill: parent
        radius: 0
        source: root.wallpaperSource
        tintEnabled: root.tintEnabled
        visible: targetOpacity > 0
        readonly property real targetOpacity: root.style ? root.style.wallpaperOpacity : 1
        opacity: root.startAnim ? targetOpacity : 0

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: root.revealDuration
                easing.type: Easing.OutQuint
            }
        }

        // The style decides how much of the art survives: moderate blur keeps
        // it recognisable while details stop competing with the clock.
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: root.wallpaperBlur > 0
            blur: root.startAnim ? root.wallpaperBlur : 0
            blurMax: 64
            saturation: root.style ? root.style.wallpaperSaturation : 0
            Behavior on blur {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: root.revealDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Slight zoom also pushes the soft blurred edges off screen.
        property real zoomScale: root.startAnim ? (root.style ? root.style.wallpaperZoom : 1.08) : 1.0
        transform: Scale {
            origin.x: wallpaperBackground.width / 2
            origin.y: wallpaperBackground.height / 2
            xScale: wallpaperBackground.zoomScale
            yScale: wallpaperBackground.zoomScale
        }
        Behavior on zoomScale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: root.revealDuration
                easing.type: Easing.OutExpo
            }
        }
    }

    Loader {
        id: backdropLoader
        anchors.fill: parent
        opacity: root.reveal
        sourceComponent: root.style ? root.style.backdrop : null
    }

    // ── Foreground ──────────────────────────────────────────────────────
    Item {
        id: foreground
        anchors.fill: parent
        opacity: root.reveal
        scale: 0.96 + 0.04 * root.reveal

        // Clicking anywhere empty returns focus to the password field.
        MouseArea {
            anchors.fill: parent
            onClicked: root.focusPassword()
        }

        Loader {
            id: statusLoader
            x: root.edgeMargin * 0.75
            width: parent.width - root.edgeMargin * 1.5
            height: item ? (item as Item).implicitHeight : 0
            y: root.atTop ? parent.height - height - root.edgeMargin * 0.75 : root.edgeMargin * 0.75
            active: root.showStatus
            sourceComponent: root.style ? root.style.status : null
        }

        readonly property var layout: LockLayout.place({
            "arrangement": root.style ? root.style.arrangement : "stack",
            "clockSide": root.style ? root.style.clockSide : "left",
            "atTop": root.atTop,
            "width": width,
            "height": height,
            "margin": root.edgeMargin,
            "clockW": clockLoader.width,
            "clockH": clockLoader.height,
            "clusterW": cluster.width,
            "clusterH": cluster.height,
            "statusH": statusLoader.active ? statusLoader.height : 0
        })

        Loader {
            id: clockLoader
            x: foreground.layout.clockX
            y: foreground.layout.clockY
            width: item ? (item as Item).implicitWidth : 0
            height: item ? (item as Item).implicitHeight : 0
            sourceComponent: root.style ? root.style.clock : null
        }

        Column {
            id: cluster
            x: foreground.layout.clusterX
            y: foreground.layout.clusterY
            width: root.style ? root.style.clusterWidth : 420
            spacing: root.style ? root.style.clusterSpacing : 18

            Loader {
                id: mediaLoader
                width: parent.width
                height: item ? (item as Item).implicitHeight : 0
                visible: root.hasMedia && root.showMedia
                sourceComponent: root.style ? root.style.mediaCard : null
                onLoaded: root.mediaCard.view = root
            }
            Binding {
                target: mediaLoader.item
                property: "shown"
                value: root.startAnim && !root.preview
                when: mediaLoader.item !== null
            }
            Binding {
                target: mediaLoader.item
                property: "visualizerEnabled"
                value: root.showVisualizer
                when: mediaLoader.item !== null
            }

            Loader {
                id: passwordLoader
                width: parent.width
                height: item ? (item as Item).implicitHeight : 0
                sourceComponent: root.style ? root.style.passwordField : null
                onLoaded: root.passwordPill.view = root
            }
        }
    }
}
