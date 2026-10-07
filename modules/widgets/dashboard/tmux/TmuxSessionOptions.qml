pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.components.kit
import "TmuxModel.js" as TmuxModel

// Expanded options of a session row (Open, Rename, Quit) as compact kit
// ListRows. The highlighted option follows `tab.selectedOptionIndex`
// (keyboard) and the mouse.
Column {
    id: options

    required property var tab
    property string sessionName: ""
    property bool shown: false

    readonly property var entries: [
        {
            text: I18n.t("common.open"),
            icon: Icons.popOpen
        },
        {
            text: I18n.t("common.rename"),
            icon: Icons.edit
        },
        {
            text: I18n.t("tmux.quit"),
            icon: Icons.alert,
            error: true
        }
    ]

    function run(index) {
        if (index === 0) {
            options.tab.attachToSession(options.sessionName);
        } else if (index === 1) {
            options.tab.enterRenameMode(options.sessionName);
            options.tab.expandedItemIndex = -1;
        } else {
            options.tab.enterDeleteMode(options.sessionName);
            options.tab.expandedItemIndex = -1;
        }
    }

    visible: opacity > 0
    opacity: options.shown ? 1 : 0

    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Motion.morph.easing
        }
    }

    Repeater {
        model: options.entries

        ListRow {
            id: option
            required property var modelData
            required property int index

            width: options.width
            height: TmuxModel.OPTION_HEIGHT
            title: option.modelData.text
            highlighted: options.tab.selectedOptionIndex === option.index
            onClicked: options.run(option.index)
            onHoveredChanged: {
                if (option.hovered && !option.highlighted) {
                    options.tab.selectedOptionIndex = option.index;
                    options.tab.keyboardNavigation = false;
                }
            }

            leading: Component {
                Text {
                    width: Type.iconSize("body")
                    horizontalAlignment: Text.AlignHCenter
                    text: option.modelData.icon
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("caption")
                    color: option.modelData.error ? Colors.error : Type.secondary
                }
            }

            trailing: Component {
                KeyHint {
                    visible: option.index === 0
                    icon: Icons.arrowElbowDownLeft
                }
            }
        }
    }
}
