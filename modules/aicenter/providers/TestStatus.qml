pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// Result line of a connection test: spinner while testing, model count on
// success ("key saved" when the provider cannot be checked for free), the
// error otherwise.
StyledRect {
    id: root

    property bool testing: false
    property var result: null       // ProviderConnect.summarize() or null
    property bool local: false

    readonly property bool ok: !!result && result.ok
    readonly property string message: {
        if (testing)
            return I18n.t("ai.connect.testing");
        if (!result)
            return "";
        if (!result.ok)
            return I18n.t("ai.connect.failed").arg(result.error || "?");
        if (!result.verified)
            return I18n.t("ai.connect.ok_unverified");
        if (result.count === 0)
            return local ? I18n.t("ai.connect.no_models") : I18n.t("ai.connect.ok_empty");
        return I18n.t("ai.connect.ok_models").arg(result.count) + (result.version ? "  ·  v" + result.version : "");
    }

    visible: testing || result !== null
    implicitHeight: row.implicitHeight + 2 * Space.s
    radius: Look.radius("control")
    variant: testing ? "internalbg" : (ok ? "common" : "error")
    opacity: visible ? 1 : 0

    Behavior on opacity {
        enabled: BarLook.animDuration > 0
        NumberAnimation {
            duration: BarLook.animDuration / 3
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: Space.m
        anchors.rightMargin: Space.m
        spacing: Space.s
        Spinner {
            visible: root.testing
            running: root.testing
        }
        Icon {
            role: "body"
            visible: !root.testing
            icon: root.ok ? Icons.checkCircle : Icons.warning
            size: BarLook.size("body")
            color: root.ok ? Colors.success : Styling.srItem("error")
        }
        AiText {
            objectName: "connectStatusText"
            role: "caption"
            Layout.fillWidth: true
            text: root.message
            wrapMode: Text.Wrap
            color: root.testing ? Colors.overSurfaceVariant : (root.ok ? Colors.overSurface : Styling.srItem("error"))
        }
    }
}
