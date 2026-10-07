pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import "../../services/ai/ProviderPresets.js" as Presets

// "Connect a provider": step 1 picks a provider (ProviderGrid), step 2
// enters its key and/or URL, tests and saves it (ProviderForm). Inline in
// the AI bar (an overlay opened with open(provider)) and `embedded` in the
// settings Providers page and the onboarding AI step.
StyledRect {
    id: root
    objectName: "connectSheet"

    property bool embedded: false
    property bool opened: embedded
    property string provider: ""

    signal closeRequested
    signal connected(string provider)

    readonly property var preset: Presets.preset(provider)

    // A sheet created already opened (onboarding loads it on demand).
    Component.onCompleted: {
        if (opened && !embedded)
            open(provider);
    }

    function open(id) {
        Ai._ensureInit();
        provider = Presets.preset(id || "") ? id : "";
        opened = true;
        forceActiveFocus();
    }
    function close() {
        if (embedded) {
            provider = "";
            return;
        }
        opened = false;
        provider = "";
        closeRequested();
    }
    function back() {
        provider = "";
    }

    variant: embedded ? "transparent" : "bg"
    radius: Styling.radius(-2)
    visible: opened || opacity > 0
    opacity: opened ? 1 : 0
    enabled: opened
    focus: opened

    Behavior on opacity {
        enabled: BarLook.animDuration > 0
        NumberAnimation {
            duration: BarLook.animDuration / 2
            easing.type: Motion.enter.easing
        }
    }

    Keys.onEscapePressed: event => {
        if (provider && !embedded)
            back();
        else
            close();
        event.accepted = true;
    }

    implicitHeight: embedded ? sheetColumn.implicitHeight : 0

    // Swallow clicks and wheel events so the transcript below gets none.
    MouseArea {
        anchors.fill: parent
        enabled: !root.embedded
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    ColumnLayout {
        id: sheetColumn
        anchors.fill: parent
        anchors.margins: root.embedded ? 0 : BarLook.pad + 4
        spacing: BarLook.groupGap

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            IconButton {
                objectName: "connectBack"
                visible: root.provider !== ""
                glyph: Icons.arrowLeft
                tooltip: I18n.t("ai.connect.back")
                onClicked: root.back()
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: root.provider ? I18n.t("ai.connect.title_provider").arg(root.preset ? root.preset.label : root.provider) : I18n.t("ai.connect.title")
                    elide: Text.ElideRight
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(root.embedded ? 1 : 2)
                    font.weight: Font.Bold
                    color: Colors.overBackground
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.provider === ""
                    text: I18n.t("ai.connect.subtitle")
                    wrapMode: Text.Wrap
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-2)
                    color: Colors.outline
                }
            }
            IconButton {
                objectName: "connectClose"
                visible: !root.embedded
                glyph: Icons.cancel
                tooltip: I18n.t("ai.close")
                onClicked: root.close()
            }
        }

        Loader {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: !root.embedded
            Layout.preferredHeight: root.embedded && item ? (item as Flickable).contentHeight : -1
            active: root.opened
            sourceComponent: root.provider ? formC : gridC
            onLoaded: {
                item.opacity = 0;
                item.opacity = 1;
            }
        }
    }

    Component {
        id: gridC
        ProviderGrid {
            interactive: !root.embedded
            Behavior on opacity {
                enabled: BarLook.animDuration > 0
                NumberAnimation {
                    duration: BarLook.animDuration / 2
                }
            }
            onPicked: id => root.provider = id
        }
    }
    Component {
        id: formC
        ProviderForm {
            provider: root.provider
            interactive: !root.embedded
            Behavior on opacity {
                enabled: BarLook.animDuration > 0
                NumberAnimation {
                    duration: BarLook.animDuration / 2
                }
            }
            onSaved: {
                root.connected(root.provider);
                if (root.embedded)
                    root.back();
                else
                    root.close();
            }
            onDisconnected: root.back()
        }
    }
}
