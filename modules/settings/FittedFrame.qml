import QtQuick
import qs.modules.components.kit

// The measures of a fitted page (modules/settings/AGENTS.md, PAGE
// COMPOSITION), shared by the schema pages (SettingsPage) and the
// hand-written ones (Displays, Keyboard, About, Changes, Extras, Mods,
// Presets: their root is a FittedFrame). At the default window the page is
// exactly the hero (a 16:9 stage, or the list form's short band), one hint
// line and one row of cards at the foot, inside the page padding.
// In a narrow window a page that says `stackable` stacks its row of cards
// under the hero instead (`stacked`), one card a line, and scrolls: it
// sets `stackedHeight` (where its last card ends).
Flickable {
    id: frame

    property bool stackable: false
    readonly property bool stacked: frame.stackable && frame.width < Space.px(820)
    property real stackedHeight: 0
    contentWidth: width
    contentHeight: frame.stacked ? Math.max(frame.height, frame.stackedHeight) : frame.height
    interactive: contentHeight > height + 1
    clip: interactive
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    // the list form: a short band over tall cards
    property bool listForm: false
    // a hint line under the hero
    property bool hasHint: true
    // a band (list form) at all: a list page without one gives the row the
    // whole height
    property bool band: true
    // the band is at least this tall (its side columns)
    property real bandMin: 0

    readonly property real margin: Space.xl
    readonly property real gap: Space.l
    readonly property real pad: Space.l
    // the side columns beside the hero
    readonly property real sideW: Math.min(Space.px(220), frame.width * 0.19)
    readonly property real hintH: frame.hasHint ? Space.xl : 0
    // the share of the page the band takes (a category's `bandShare`: a band
    // that is the page's main control, such as Sound's two big sliders)
    property real bandShare: 0.24
    readonly property real bandH: frame.listForm && frame.band ? Math.round(Math.max(Space.px(120), frame.height * frame.bandShare, frame.bandMin)) : 0
    // the row of cards: one card height, or (list form) the rest of the page
    // the height the cards of the row want (a page sets it from its cards'
    // content): the row grows to it, the hero gives up the room, so a card
    // never scrolls inside itself while the window has room for it
    property real rowNeed: 0
    readonly property real rowH: frame.listForm ? Math.max(Look.cardRowHeight, frame.height - Space.s - frame.bandH - frame.hintH - frame.gap - frame.pad) : Math.max(Look.cardRowHeight, Math.min(frame.rowNeed, frame.height - Space.s - frame.hintH - frame.gap - frame.pad - Space.px(200)))
    readonly property real rowY: frame.height - frame.rowH - frame.pad
    // the stage form's hero: the height the hint and the row leave
    readonly property real heroH: Math.max(Space.px(160), frame.height - Space.s - frame.hintH - frame.gap - frame.rowH - frame.pad)
}
