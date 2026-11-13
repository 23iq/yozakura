pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../Registry.js" as Registry

// A selector shown as cards (schema `display: "cards"`): one ChoiceCard per
// option with a small picture of it, drawn by the entry's `thumb`
// (Registry.THUMBS; the thumb gets `value` = the option's value and
// `entry`). Option `description` (i18n) is the card's second line.
Item {
    id: root

    property var entry
    property var options: []
    property var value
    signal selected(var value)

    // A strip (in a card of the page row, SettingRow.fillHeight): one
    // horizontal row of equal pictures with the title inside, scrolling
    // sideways with an edge fade when they do not fit.
    property real fillHeight: 0
    readonly property bool strip: root.fillHeight > 0
    readonly property int stripCount: root.options.length
    // all whole when they fit at a small picture each (three or fewer: always),
    // else as many as fit at a regular size and a peek of the next
    readonly property real stripWidth: root.stripCount <= 3 || root.stripCount * Space.px(60) + Space.m * (root.stripCount + 1) <= root.width ? (root.width - Space.m * (root.stripCount + 1)) / Math.max(1, root.stripCount) : (root.width - Space.m * 2) / (Math.max(1, Math.floor((root.width - Space.m * 2) / Space.px(96))) + 0.4) - Space.m
    readonly property int columns: root.strip ? root.stripCount : Math.max(2, Math.min(root.options.length, Math.floor((width + grid.columnSpacing) / (Space.px(150) + grid.columnSpacing))))
    // A few options do not stretch into huge cards.
    readonly property real cardWidth: Math.min((width - grid.columnSpacing * (columns - 1)) / columns, Space.px(240))
    readonly property string thumbUrl: entry && entry.thumb ? Qt.resolvedUrl("../" + Registry.thumb(entry.thumb)) : ""

    implicitHeight: root.strip ? root.fillHeight : grid.implicitHeight

    Flickable {
        id: stripFlick
        objectName: "pictureStrip"
        width: parent.width
        height: grid.height + (root.strip ? Space.m * 2 : 0)
        contentWidth: grid.width + (root.strip ? Space.m * 2 : 0)
        interactive: root.strip && contentWidth > width
        clip: root.strip
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        Grid {
            id: grid
            width: root.strip ? implicitWidth : stripFlick.width
            // inset: the ring, glow and lift of a picture never clip
            x: root.strip ? Space.m : 0
            y: root.strip ? Space.m : 0
            columns: root.columns
            rowSpacing: Space.l
            columnSpacing: root.strip ? Space.m : Space.l

            Repeater {
                model: root.options

                delegate: ChoiceCard {
                    id: card
                    required property var modelData
                    objectName: "card:" + card.modelData.value
                    width: root.strip ? root.stripWidth : root.cardWidth
                    previewHeight: root.strip ? root.fillHeight - Space.m * 2 : Math.round(width * 0.56)
                    inset: root.strip
                    selected: root.value === card.modelData.value
                    title: I18n.t(card.modelData.label)
                    subtitle: card.modelData.description ? I18n.t(card.modelData.description) : ""
                    onClicked: root.selected(card.modelData.value)

                    // Pictures are built off the frame (asynchronous): the cards
                    // show at once, each picture fades in when ready.
                    Loader {
                        id: picture
                        anchors.fill: parent
                        asynchronous: true
                        opacity: status === Loader.Ready ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Motion.micro.duration
                            }
                        }
                        Component.onCompleted: setSource(root.thumbUrl, {
                            "entry": root.entry,
                            "value": card.modelData.value
                        })
                    }
                }
            }
        }
    }
    StripFade {
        flick: stripFlick
        visible: root.strip
    }
}
