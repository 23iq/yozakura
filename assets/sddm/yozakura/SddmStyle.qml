import QtQuick
import "Layout.js" as Layout

// Base of every SDDM lock screen style (see Styles.js). Main.qml creates
// the active style with `greeter` set to itself (state, palette, fonts,
// icons and the login actions) and draws the wallpaper under it and the
// status chips/menus over it in the style's chip look.
//
// A style provides:
//   backdrop        items over the wallpaper (scrims, paper, tube...)
//   clock, cluster  its clock and its password block (children of the
//                   style); placed here by `arrangement` (Layout.js)
//   passwordField   the TextField inside the cluster; it calls submit(),
//                   cancel() and edited() and shows `hint`
//   shakeOffset     read by the password block for the wrong-password shake
//   palette, chip look and wallpaper treatment properties below
Item {
    id: skin

    required property Item greeter
    readonly property QtObject pal: greeter.pal
    property bool light: greeter.styleTone === "light"

    // ── Outputs ────────────────────────────────────────────────────────
    property Item passwordField: null
    property Item clock: null
    property Item cluster: null
    // "stack" | "center" | "split" | "column" (as in the shell)
    property string arrangement: "stack"
    property string clockSide: "left"

    // ── Wallpaper treatment (Main.qml) ─────────────────────────────────
    property real wallpaperBlur: 0.7
    property real wallpaperOpacity: 1
    property real wallpaperSaturation: 0
    property real wallpaperZoom: 1.08

    // ── Palette (fixed roles: same look in light and dark schemes) ─────
    property color ink: light ? pal.overSecondaryFixed : pal.secondaryFixed
    property color inkSoft: light ? pal.overSecondaryFixedVariant : pal.secondaryFixedDim
    property color accent: light ? pal.overPrimaryFixedVariant : pal.primaryFixedDim
    property color overAccent: light ? pal.primaryFixed : pal.overPrimaryFixed
    property color error: Qt.hsla(Math.max(0, pal.error.hslHue), 0.75, light ? 0.42 : 0.74, 1)
    property string font: greeter.uiFont

    // ── Chip and menu look (Main.qml status chips) ─────────────────────
    property color chipSurface: light ? Qt.lighter(pal.secondaryFixed, 1.08) : pal.black
    property color chipFill: alpha(chipSurface, 0.58)
    property color chipBorder: alpha(chipInk, 0.10)
    property real chipBorderWidth: 1
    property color chipInk: ink
    // Corner radius as a share of half the chip height.
    property real chipRoundness: greeter.roundnessFactor
    property string chipFont: font
    property int chipFontSize: greeter.fontSize - 1
    property bool chipCaps: false
    property real chipLetterSpacing: 0
    property color menuFill: alpha(chipSurface, 0.86)

    // ── Password state ─────────────────────────────────────────────────
    property real shakeOffset: 0
    property real shakeAmplitude: 1
    readonly property bool hasText: passwordField !== null && passwordField.text.length > 0
    readonly property bool errorShown: greeter.showError || greeter.message !== ""
    readonly property string hint: {
        if (greeter.showError)
            return "Wrong password";
        if (greeter.message !== "")
            return greeter.message;
        if (greeter.authenticating)
            return "Signing in…";
        if (greeter.capsLock)
            return "Caps Lock is on";
        return "";
    }

    property alias backdrop: backdropLayer.data
    default property alias content: foregroundLayer.data

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, c.a * a);
    }
    function submit() {
        greeter.doLogin(passwordField ? passwordField.text : "");
    }
    function cancel() {
        greeter.escapePressed();
    }
    function edited() {
        greeter.passwordEdited(passwordField ? passwordField.text : "");
    }
    function playWrongPassword() {
        wrongPasswordAnim.restart();
    }

    readonly property var placement: Layout.place({
        "arrangement": arrangement,
        "clockSide": clockSide,
        "atTop": greeter.atTop,
        "width": width,
        "height": height,
        "margin": greeter.edgeMargin,
        "clockW": clock ? clock.width : 0,
        "clockH": clock ? clock.height : 0,
        "clusterW": cluster ? cluster.width : 0,
        "clusterH": cluster ? cluster.height : 0,
        "statusH": 36
    })

    Item {
        id: backdropLayer
        anchors.fill: parent
        opacity: skin.greeter.loginOk ? 1 : skin.greeter.reveal
    }
    Item {
        id: foregroundLayer
        anchors.fill: parent
        opacity: skin.greeter.reveal
        scale: 0.96 + 0.04 * skin.greeter.reveal
    }

    // Secondary screens show the clock alone, centred.
    Binding {
        target: skin.clock
        property: "x"
        value: skin.greeter.isPrimary ? skin.placement.clockX : Math.round((skin.width - skin.clock.width) / 2)
        when: skin.clock !== null
    }
    Binding {
        target: skin.clock
        property: "y"
        value: skin.greeter.isPrimary ? skin.placement.clockY : Math.round((skin.height - skin.clock.height) / 2)
        when: skin.clock !== null
    }
    Binding {
        target: skin.cluster
        property: "x"
        value: skin.placement.clusterX
        when: skin.cluster !== null
    }
    Binding {
        target: skin.cluster
        property: "y"
        value: skin.placement.clusterY
        when: skin.cluster !== null
    }
    Binding {
        target: skin.cluster
        property: "visible"
        value: skin.greeter.isPrimary
        when: skin.cluster !== null
    }

    SequentialAnimation {
        id: wrongPasswordAnim
        ScriptAction {
            script: skin.greeter.showError = true
        }
        NumberAnimation {
            target: skin
            property: "shakeOffset"
            to: 14 * skin.shakeAmplitude
            duration: 45
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: skin
            property: "shakeOffset"
            to: -12 * skin.shakeAmplitude
            duration: 80
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: skin
            property: "shakeOffset"
            to: 9 * skin.shakeAmplitude
            duration: 70
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: skin
            property: "shakeOffset"
            to: -5 * skin.shakeAmplitude
            duration: 60
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: skin
            property: "shakeOffset"
            to: 0
            duration: 50
            easing.type: Easing.OutQuad
        }
        ScriptAction {
            script: skin.greeter.wrongPasswordDone()
        }
    }
}
