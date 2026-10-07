pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.modules.corners
import qs.modules.theme
import qs.modules.globals
import qs.config

// Lock surface - shown on each screen when locked.
// Visuals live in LockView.qml; this file owns the session lock surface,
// the frozen screen capture, wallpaper video sync and PAM authentication.
WlSessionLockSurface {
    id: root

    property bool startAnim: false
    property bool authenticating: false
    property string errorMessage: ""
    property int failLockSecondsLeft: 0
    property bool capsLock: false

    // Presentation handles, kept under their previous names so the auth flow
    // below is unchanged.
    readonly property alias passwordInput: lockView.passwordField
    readonly property alias passwordInputBox: lockView.passwordPill
    readonly property alias wallpaperBackground: lockView.wallpaper

    // Always transparent - the view draws the background
    color: "transparent"

    function backgroundWallpaper() {
        return root.screen ? GlobalStates.wallpaperForScreen(root.screen.name) : GlobalStates.wallpaperManager;
    }

    function syncLockscreenVideo() {
        if (!wallpaperBackground.isVideo)
            return;
        var wp = backgroundWallpaper();
        var targetPos = (wp && wp.activeVideo) ? wp.activeVideo.positionMs : 0;
        wallpaperBackground.videoPlayAt(targetPos);
    }

    onStartAnimChanged: {
        if (startAnim)
            syncLockscreenVideo();
    }

    // Screen capture background (fondo absoluto con zoom sincronizado)
    ScreencopyView {
        id: screencopyBackground
        anchors.fill: parent
        captureSource: root.screen
        live: false
        paintCursor: false
        visible: startAnim  // Visible solo cuando startAnim es true
        z: 0  // Capa más baja - fondo absoluto

        // Matches the wallpaper zoom in LockView
        property real zoomScale: startAnim ? 1.08 : 1.0

        transform: Scale {
            origin.x: screencopyBackground.width / 2
            origin.y: screencopyBackground.height / 2
            xScale: screencopyBackground.zoomScale
            yScale: screencopyBackground.zoomScale
        }

        Behavior on zoomScale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration * 2
                easing.type: Motion.morph.easing
            }
        }
    }

    LockView {
        id: lockView
        anchors.fill: parent
        z: 1

        startAnim: root.startAnim
        authenticating: root.authenticating
        errorMessage: root.errorMessage
        failLockSecondsLeft: root.failLockSecondsLeft
        capsLock: root.capsLock
        username: usernameCollector.text.trim()
        hostname: hostnameCollector.text.trim()
        tintEnabled: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.tintEnabled : false
        wallpaperSource: {
            var wp = root.backgroundWallpaper();
            var path = wp ? wp.effectiveWallpaper : "";
            return path ? "file://" + path : "";
        }

        // Deferred so the wallpaper item has picked up the new source first.
        onWallpaperSourceChanged: {
            if (root.startAnim)
                Qt.callLater(root.syncLockscreenVideo);
        }
    }

    // Follow the background video while locked (seek to 0 on wallpaper sync)
    Connections {
        target: GlobalStates
        function onVideoSyncTickChanged() {
            if (!wallpaperBackground.isVideo)
                return;
            wallpaperBackground.videoSeek(0);
            wallpaperBackground.videoPlay();
        }
    }

    // Soft drift correction against the background video. The background
    // holds playback while locked, so only follow it while it is running.
    Timer {
        id: videoDriftTimer
        interval: 15000
        running: startAnim && wallpaperBackground.isVideo
        repeat: true
        onTriggered: {
            var wp = backgroundWallpaper();
            if (!wp || !wp.activeVideo || wp.activeVideo.paused || !wallpaperBackground.isVideo)
                return;
            var diff = Math.abs(wallpaperBackground.videoPosition - wp.activeVideo.positionMs);
            if (diff > 1500)
                wallpaperBackground.videoSeek(wp.activeVideo.positionMs);
        }
    }

    // Password submit (Enter or the pill's arrow button)
    Connections {
        target: root.passwordInput
        function onAccepted() {
            if (passwordInput.text.trim() === "")
                return;

            // Guardar contraseña y limpiar campo inmediatamente
            authPasswordHolder.password = passwordInput.text;
            passwordInput.text = "";

            authenticating = true;
            errorMessage = "";
            pamAuth.start();
        }
    }

    // End of the wrong-password shake: same reset as before the redesign
    Connections {
        target: root.passwordInputBox
        function onWrongPasswordFinished() {
            passwordInput.text = "";
            authenticating = false;
            passwordInputBox.showError = false;
            passwordInput.forceActiveFocus();
        }
        function onCapsLockToggled() {
            root.refreshCapsLock();
        }
    }

    // Caps Lock state from the keyboard LEDs (any keyboard counts)
    function refreshCapsLock() {
        if (!capsLockCheck.running)
            capsLockCheck.running = true;
    }

    Process {
        id: capsLockCheck
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.capsLock = text.split("\n").some(line => parseInt(line) > 0);
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.startAnim
        triggeredOnStart: true
        onTriggered: root.refreshCapsLock()
    }

    // Timer to unlock after exit animation
    Timer {
        id: unlockTimer
        // A Timer with interval 0 never fires in Qt; ensure a minimum interval
        interval: Config.animDuration > 0 ? Config.animDuration * 2 : 1
        onTriggered: {
            GlobalStates.lockscreenVisible = false;
        }
    }

    // Processes for user info
    Process {
        id: usernameProc
        command: ["whoami"]
        running: true

        stdout: StdioCollector {
            id: usernameCollector
            waitForEnd: true
        }
    }

    Process {
        id: hostnameProc
        command: ["hostname"]
        running: true

        stdout: StdioCollector {
            id: hostnameCollector
            waitForEnd: true
        }
    }

    // Holder temporal para la contraseña durante autenticación
    QtObject {
        id: authPasswordHolder
        property string password: ""
    }

    // Proceso para verificar tiempo de faillock
    Process {
        id: failLockCheck
        command: ["sh", "-c", 'faillock --user "$1" 2>/dev/null | grep -oP "left \\K[0-9]+" | head -1', "faillock-check", usernameCollector.text.trim()]
        running: false

        stdout: StdioCollector {
            id: failLockCollector

            onStreamFinished: {
                const output = text.trim();
                const seconds = parseInt(output);

                if (!isNaN(seconds) && seconds > 0) {
                    failLockSecondsLeft = seconds;
                    failLockCountdown.start();
                } else {
                    failLockSecondsLeft = 0;
                }
            }
        }
    }

    // Timer para actualizar el countdown de faillock
    Timer {
        id: failLockCountdown
        interval: 1000
        repeat: true
        running: false

        onTriggered: {
            if (failLockSecondsLeft > 0) {
                failLockSecondsLeft--;
            } else {
                stop();
                errorMessage = "";
            }
        }
    }

    // PAM authentication process
    PamContext {
        id: pamAuth
        // Use custom PAM config for lockscreen authentication
        configDirectory: Qt.resolvedUrl("../../config/pam").toString().replace("file://", "")
        config: "password.conf"

        onPamMessage: {
            console.log("PAM Message:", this.message, "Type:", this.messageType, "Required:", this.responseRequired);
            if (this.responseRequired) {
                // pam_unix asks for password, respond with stored password
                this.respond(authPasswordHolder.password);
            }
        }

        onCompleted: result => {
            // Limpiar contraseña
            authPasswordHolder.password = "";

            if (result === PamResult.Success) {
                // Autenticación exitosa - trigger exit animation
                startAnim = false;

                // Wait for exit animation, then unlock
                unlockTimer.start();

                errorMessage = "";
                authenticating = false;
            } else {
                // Error de autenticación
                errorMessage = "Authentication failed";
                console.warn("PAM auth failed with result:", result);
                if (Config.animDuration > 0) {
                    passwordInputBox.playWrongPassword();
                } else {
                    passwordInput.text = "";
                    authenticating = false;
                    passwordInputBox.showError = false;
                }
            }
        }
    }

    // Screen corners
    RoundCorner {
        id: topLeft
        size: Styling.radius(4)
        anchors.left: parent.left
        anchors.top: parent.top
        corner: RoundCorner.CornerEnum.TopLeft
        z: 100
    }

    RoundCorner {
        id: topRight
        size: Styling.radius(4)
        anchors.right: parent.right
        anchors.top: parent.top
        corner: RoundCorner.CornerEnum.TopRight
        z: 100
    }

    RoundCorner {
        id: bottomLeft
        size: Styling.radius(4)
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        corner: RoundCorner.CornerEnum.BottomLeft
        z: 100
    }

    RoundCorner {
        id: bottomRight
        size: Styling.radius(4)
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        corner: RoundCorner.CornerEnum.BottomRight
        z: 100
    }

    // Initialize when component is created (when lock becomes active)
    Component.onCompleted: {
        // Capture screen immediately
        screencopyBackground.captureFrame();

        // Start animations
        startAnim = true;
        passwordInput.forceActiveFocus();
    }
}
