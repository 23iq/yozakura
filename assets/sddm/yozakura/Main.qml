// Yozakura SDDM theme.
//
// Mirrors the shell lock screen and its styles (modules/lockscreen): the
// style chosen in the shell (config `style`, written by
// scripts/sddm-sync.sh) is loaded from styles/ (see Styles.js and
// SddmStyle.qml) and draws the backdrop, clock and password field; this
// file owns the SDDM side: config, palette, fonts, wallpaper, login,
// users/sessions/keyboard layouts, status chips and menus (StatusChips.qml)
// and screen corners.
// Only plain QtQuick 6 is used: the greeter cannot import Quickshell or
// qs.* modules.
//
// All dynamic values come from SDDM's `config` map (theme.conf, overridden by
// theme.conf.user -> /var/lib/yozakura-sddm/theme.conf written by
// scripts/sddm-sync.sh). Every value has a built-in fallback so a missing or
// broken sync never leaves the login screen unusable; an unknown style or
// one that fails to load falls back to glass.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "Styles.js" as Styles

Rectangle {
    id: root

    width: 1920
    height: 1080
    color: pal.background

    // ------------------------------------------------------------ config --

    function cfg(key, fallback) {
        var v = (typeof config !== "undefined" && config) ? config[key] : undefined;
        if (v === undefined || v === null)
            return fallback;
        v = String(v).trim();
        return v === "" ? fallback : v;
    }
    function cfgBool(key, fallback) {
        var v = cfg(key, "");
        if (v === "")
            return fallback;
        return v === "true" || v === "1" || v === "yes";
    }
    function cfgNum(key, fallback) {
        var n = parseFloat(cfg(key, ""));
        return isNaN(n) ? fallback : n;
    }
    function cfgColor(key, fallback) {
        var v = cfg(key, "");
        return /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(v) ? v : fallback;
    }
    function fileUrl(path) {
        if (!path)
            return "";
        return path.indexOf("file://") === 0 ? path : "file://" + path;
    }
    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, c.a * a);
    }

    // Palette roles the styles use; defaults match the fallback palette in
    // modules/theme/Colors.qml.
    QtObject {
        id: colors
        readonly property color background: root.cfgColor("color_background", "#1a1111")
        readonly property color primary: root.cfgColor("color_primary", "#ffb3ae")
        readonly property color overPrimary: root.cfgColor("color_overPrimary", "#571d1c")
        readonly property color primaryContainer: root.cfgColor("color_primaryContainer", "#733331")
        readonly property color error: root.cfgColor("color_error", "#ffb4ab")
        readonly property color red: root.cfgColor("color_red", "#ffb4ab")
        readonly property color black: root.cfgColor("color_shadow", "#000000")
        readonly property color primaryFixed: root.cfgColor("color_primaryFixed", "#ffdad7")
        readonly property color primaryFixedDim: root.cfgColor("color_primaryFixedDim", "#ffb3ae")
        readonly property color overPrimaryFixed: root.cfgColor("color_overPrimaryFixed", "#3b0909")
        readonly property color overPrimaryFixedVariant: root.cfgColor("color_overPrimaryFixedVariant", "#733331")
        readonly property color secondaryFixed: root.cfgColor("color_secondaryFixed", "#ffdad7")
        readonly property color secondaryFixedDim: root.cfgColor("color_secondaryFixedDim", "#e7bdb9")
        readonly property color overSecondaryFixed: root.cfgColor("color_overSecondaryFixed", "#2c1513")
        readonly property color overSecondaryFixedVariant: root.cfgColor("color_overSecondaryFixedVariant", "#5d3f3d")
        readonly property color tertiaryFixed: root.cfgColor("color_tertiaryFixed", "#fbdfa6")
        readonly property color tertiaryFixedDim: root.cfgColor("color_tertiaryFixedDim", "#dec48c")
        readonly property color overTertiaryFixedVariant: root.cfgColor("color_overTertiaryFixedVariant", "#564419")
    }
    readonly property QtObject pal: colors

    readonly property real roundness: cfgNum("roundness", 16)
    readonly property real roundnessFactor: roundness > 0 ? Math.min(1, roundness / 16) : 0
    readonly property int fontSize: Math.max(cfgNum("fontSize", 14), 8)
    readonly property bool use12h: cfgBool("use12h", false)
    readonly property bool atTop: cfg("position", "bottom") === "top"
    readonly property bool corners: cfgBool("enableCorners", true)
    readonly property int animDuration: 300
    readonly property int revealDuration: animDuration * 2

    // Style: the synced id when known, else glass; the synced tone when the
    // style has it, else its own. `styleFailed` = the style file did not load.
    property bool styleFailed: false
    readonly property string styleId: styleFailed ? Styles.DEFAULT_ID : Styles.resolve(cfg("style", Styles.DEFAULT_ID))
    readonly property string styleTone: Styles.tone(styleId, cfg("tone", ""))
    readonly property real blurOverride: cfgNum("blur", -1)

    // ------------------------------------------------------------- fonts --

    component FontFile: FontLoader {
        property string fallback: ""
        readonly property string family: status === FontLoader.Ready ? name : fallback
    }
    FontFile {
        id: uiFontLoader
        source: root.fileUrl(root.cfg("fontFile", ""))
        fallback: root.cfg("font", "Google Sans Flex")
    }
    FontFile {
        id: iconFontLoader
        source: root.fileUrl(root.cfg("iconFontFile", ""))
        fallback: root.cfg("iconFont", "Phosphor-Bold")
    }
    FontFile {
        id: monoFontLoader
        source: root.fileUrl(root.cfg("monoFontFile", ""))
        fallback: root.cfg("monoFont", "monospace")
    }
    FontFile {
        id: minchoLoader
        source: root.fileUrl(root.cfg("minchoFile", ""))
        fallback: "Shippori Mincho B1"
    }
    FontFile {
        id: minchoRegularLoader
        source: root.fileUrl(root.cfg("minchoRegularFile", ""))
        fallback: minchoLoader.family
    }
    FontFile {
        id: minchoBoldLoader
        source: root.fileUrl(root.cfg("minchoBoldFile", ""))
        fallback: minchoLoader.family
    }
    FontFile {
        id: gothicLoader
        source: root.fileUrl(root.cfg("gothicFile", ""))
        fallback: "League Gothic"
    }
    FontFile {
        id: groteskLoader
        source: root.fileUrl(root.cfg("groteskFile", ""))
        fallback: root.uiFont
    }
    FontFile {
        id: groteskBoldLoader
        source: root.fileUrl(root.cfg("groteskBoldFile", ""))
        fallback: groteskLoader.family
    }
    readonly property string uiFont: uiFontLoader.family
    readonly property string iconFont: iconFontLoader.family
    readonly property string monoFont: monoFontLoader.family
    readonly property string minchoFont: minchoLoader.family
    readonly property string minchoRegularFont: minchoRegularLoader.family
    readonly property string minchoBoldFont: minchoBoldLoader.family
    readonly property string gothicFont: gothicLoader.family
    readonly property string groteskFont: groteskLoader.family
    readonly property string groteskBoldFont: groteskBoldLoader.family

    // Phosphor-Bold glyphs (see modules/theme/Icons.qml).
    readonly property string iconUser: ""
    readonly property string iconLock: ""
    readonly property string iconCapsLock: ""
    readonly property string iconArrowRight: ""
    readonly property string iconSpinner: ""
    readonly property string iconKeyReturn: ""
    readonly property string iconSuspend: ""
    readonly property string iconReboot: ""
    readonly property string iconShutdown: ""
    readonly property string iconSession: ""
    readonly property string iconKeyboard: ""
    readonly property string iconCaretDown: ""

    // ------------------------------------------------------------- state --

    readonly property bool isPrimary: typeof primaryScreen === "undefined" ? true : primaryScreen
    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software
    readonly property real edgeMargin: Math.round(Math.max(32, height * 0.05))
    readonly property string hostName: typeof sddm !== "undefined" && sddm && sddm.hostName ? sddm.hostName : ""
    property bool startAnim: false
    property bool authenticating: false
    property bool loginOk: false
    property bool showError: false
    property string message: ""
    property int userIndex: (userModel.lastIndex >= 0 && userModel.lastIndex < usersRepeater.count) ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string openMenu: ""   // "", "session", "user", "layout"
    property date now: new Date()

    readonly property var currentUser: usersRepeater.count > 0 && userIndex < usersRepeater.count ? usersRepeater.itemAt(userIndex) : null
    readonly property string userName: currentUser ? currentUser.uName : ""
    readonly property var currentSession: sessionsRepeater.count > 0 && sessionIndex < sessionsRepeater.count ? sessionsRepeater.itemAt(sessionIndex) : null
    readonly property bool capsLock: typeof keyboard !== "undefined" && keyboard ? keyboard.capsLock : false
    readonly property var layouts: typeof keyboard !== "undefined" && keyboard && keyboard.layouts ? keyboard.layouts : []

    readonly property int userCount: usersRepeater.count
    readonly property int sessionCount: sessionsRepeater.count
    readonly property Item style: styleLoader.item
    readonly property Item passwordField: style ? style.passwordField : fallbackField.item

    // 0 -> 1 as the screen comes in; drives fade/scale of the chrome.
    property real reveal: startAnim ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.revealDuration
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // Model mirrors (SDDM models are only reachable through delegates).
    Item {
        visible: false
        Repeater {
            id: usersRepeater
            model: userModel
            delegate: Item {
                required property int index
                required property var model
                readonly property string uName: model.name || ""
                readonly property string uRealName: model.realName || ""
                readonly property string uIcon: model.icon || ""
                readonly property bool uNeedsPassword: model.needsPassword !== false
            }
        }
        Repeater {
            id: sessionsRepeater
            model: sessionModel
            delegate: Item {
                required property int index
                required property var model
                readonly property string sName: model.name || ""
            }
        }
    }

    // ------------------------------------------------------ login actions --
    // Called by the style (SddmStyle.submit/escape/edited, wrong-password
    // animation end).

    function focusPassword() {
        if (isPrimary && passwordField)
            passwordField.forceActiveFocus();
    }

    function doLogin(password) {
        if (authenticating || !userName)
            return;
        var needsPw = currentUser ? currentUser.uNeedsPassword : true;
        if (needsPw && password === "")
            return;
        openMenu = "";
        message = "";
        authenticating = true;
        sddm.login(userName, password, sessionIndex);
    }

    function escapePressed() {
        if (openMenu !== "")
            openMenu = "";
        else if (passwordField)
            passwordField.text = "";
    }

    function passwordEdited(text) {
        if (text !== "" && !authenticating) {
            message = "";
            showError = false;
        }
    }

    function wrongPasswordDone() {
        if (passwordField)
            passwordField.text = "";
        authenticating = false;
        focusPassword();
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.message = "";
            if (root.style)
                root.style.playWrongPassword();
            else
                root.wrongPasswordDone();
        }
        function onLoginSucceeded() {
            root.loginOk = true;
            root.startAnim = false;
        }
        function onInformationMessage(msg) {
            root.message = msg;
        }
    }

    // Safety net: never leave the field locked if the daemon never answers.
    Timer {
        interval: 30000
        running: root.authenticating && !root.loginOk
        onTriggered: {
            root.authenticating = false;
            root.message = "No response from the display manager";
            root.focusPassword();
        }
    }

    Timer {
        // Start the entry animation once the first frame is up.
        interval: 60
        running: true
        onTriggered: {
            root.startAnim = true;
            root.focusPassword();
        }
    }

    // --------------------------------------------------------- backdrop --

    // Fallback when no wallpaper was synced: palette gradient.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.tint(pal.background, root.withAlpha(pal.primaryContainer, 0.45))
            }
            GradientStop {
                position: 1.0
                color: pal.background
            }
        }
    }

    Item {
        id: wallpaperLayer
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.style ? root.style.wallpaperOpacity : 1

        // Blur: the configured one, else the style's. Strong blurs use the
        // pre-blurred frame; light ones blur the sharp frame live.
        readonly property real blur: root.blurOverride >= 0 ? Math.min(1, root.blurOverride) : (root.style ? root.style.wallpaperBlur : 0.7)
        readonly property bool preblurred: blur >= 0.45 && blurWall.status === Image.Ready
        readonly property real liveBlur: preblurred || root.softwareRendering ? 0 : blur
        readonly property real saturation: root.style ? root.style.wallpaperSaturation : 0

        // Slight zoom also pushes the soft blurred edges off screen.
        property real zoomScale: root.startAnim ? (root.style ? root.style.wallpaperZoom : 1.08) : 1.0
        Behavior on zoomScale {
            NumberAnimation {
                duration: root.revealDuration
                easing.type: Easing.OutExpo
            }
        }
        transform: Scale {
            origin.x: wallpaperLayer.width / 2
            origin.y: wallpaperLayer.height / 2
            xScale: wallpaperLayer.zoomScale
            yScale: wallpaperLayer.zoomScale
        }

        layer.enabled: !root.softwareRendering && (liveBlur > 0 || saturation !== 0)
        layer.effect: MultiEffect {
            blurEnabled: wallpaperLayer.liveBlur > 0
            blur: root.startAnim ? wallpaperLayer.liveBlur : 0
            blurMax: 64
            saturation: wallpaperLayer.saturation
            Behavior on blur {
                NumberAnimation {
                    duration: root.revealDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        Image {
            id: sharpWall
            anchors.fill: parent
            source: root.fileUrl(root.cfg("background", ""))
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(root.width, root.height)
            asynchronous: false
            cache: false
            smooth: true
            visible: status === Image.Ready
        }

        Image {
            id: blurWall
            anchors.fill: parent
            source: root.fileUrl(root.cfg("backgroundBlurred", ""))
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: false
            smooth: true
            visible: status === Image.Ready && opacity > 0
            // Cross-fade from the sharp frame, like the lockscreen blur-in.
            opacity: wallpaperLayer.preblurred && (root.startAnim || sharpWall.status !== Image.Ready) ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: root.revealDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    // Clicking anywhere empty closes menus and refocuses the password.
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.openMenu = "";
            root.focusPassword();
        }
    }

    // ------------------------------------------------------------ style --

    Loader {
        id: styleLoader
        anchors.fill: parent

        function load() {
            setSource(Qt.resolvedUrl("styles/" + Styles.file(root.styleId)), {
                "greeter": root
            });
        }

        Component.onCompleted: load()
        onStatusChanged: {
            if (status === Loader.Error && !root.styleFailed) {
                console.warn("yozakura sddm: style", root.styleId, "failed to load, using", Styles.DEFAULT_ID);
                root.styleFailed = true;
                load();
            }
        }
        onLoaded: Qt.callLater(root.focusPassword)
    }

    // Last resort when even the default style fails to load: a plain field
    // that still logs in.
    Loader {
        id: fallbackField
        anchors.centerIn: parent
        active: root.styleFailed && styleLoader.status === Loader.Error
        sourceComponent: TextField {
            width: 360
            echoMode: TextInput.Password
            placeholderText: "Password"
            focus: true
            onAccepted: root.doLogin(text)
        }
    }

    // Logged in: dim everything while the session starts.
    Rectangle {
        anchors.fill: parent
        color: pal.black
        opacity: root.loginOk ? 0.7 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: root.revealDuration
            }
        }
    }

    // ------------------------------------------------------ status chips --

    // Built once the style is loaded: chips and menus wear its look.
    Loader {
        anchors.fill: parent
        active: root.isPrimary && root.style !== null
        sourceComponent: StatusChips {
            greeter: root
        }
    }

    function sessionNames() {
        var a = [];
        for (var i = 0; i < sessionsRepeater.count; i++)
            a.push(sessionsRepeater.itemAt(i).sName);
        return a;
    }
    function userNames() {
        var a = [];
        for (var i = 0; i < usersRepeater.count; i++) {
            var u = usersRepeater.itemAt(i);
            a.push(u.uRealName !== "" ? u.uRealName + "  (" + u.uName + ")" : u.uName);
        }
        return a;
    }
    function layoutNames() {
        var a = [];
        for (var i = 0; i < layouts.length; i++)
            a.push(layouts[i].longName || layouts[i].shortName || ("Layout " + (i + 1)));
        return a;
    }

    // ------------------------------------------------------ screen corners --

    ScreenCorner {
        visible: root.corners
        z: 100
        size: Math.max(root.roundness + 4, 0)
        which: 0
        anchors.left: parent.left
        anchors.top: parent.top
    }
    ScreenCorner {
        visible: root.corners
        z: 100
        size: Math.max(root.roundness + 4, 0)
        which: 1
        anchors.right: parent.right
        anchors.top: parent.top
    }
    ScreenCorner {
        visible: root.corners
        z: 100
        size: Math.max(root.roundness + 4, 0)
        which: 2
        anchors.left: parent.left
        anchors.bottom: parent.bottom
    }
    ScreenCorner {
        visible: root.corners
        z: 100
        size: Math.max(root.roundness + 4, 0)
        which: 3
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }

    Component.onCompleted: focusPassword()
}
