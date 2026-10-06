import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.store
import "Ui.js" as Ui

// Category header: icon tile, title, description and (schema categories)
// "Reset section" when anything differs from the defaults.
RowLayout {
    id: header

    required property var category
    readonly property int modifiedCount: category && category.sections ? SettingsStore.modifiedCount(category) : 0

    spacing: 18

    Rectangle {
        Layout.preferredWidth: 56
        Layout.preferredHeight: 56
        Layout.alignment: Qt.AlignTop
        radius: Math.min(Styling.radius(4), 20)
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ui.alpha(Colors.primary, 0.28)
            }
            GradientStop {
                position: 1
                color: Ui.alpha(Colors.tertiary, 0.14)
            }
        }
        border.width: 1
        border.color: Ui.alpha(Colors.primary, 0.3)

        Text {
            anchors.centerIn: parent
            text: Icons[header.category.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: 26
            color: Colors.primary
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            Layout.fillWidth: true
            text: Styling.heading(I18n.t(header.category.title))
            font.family: Styling.headingFont
            font.pixelSize: Styling.fontSize(12)
            font.weight: Font.Bold
            color: Colors.overBackground
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            text: header.category.description ? I18n.t(header.category.description) : ""
            visible: text !== ""
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overSurfaceVariant
            wrapMode: Text.WordWrap
        }
    }

    PillButton {
        Layout.alignment: Qt.AlignTop
        visible: header.modifiedCount > 0
        icon: "arrowCounterClockwise"
        text: I18n.t("prefs.common.reset_page")
        onClicked: SettingsStore.resetCategory(header.category)
    }
}
