import QtQuick
import qs.modules.components.kit

// The measures of a fitted page (modules/settings/AGENTS.md, PAGE
// COMPOSITION), shared by the schema pages (SettingsPage) and the
// hand-written ones (Displays, Keyboard, About, Changes, Extras, Mods,
// Presets: their root is a FittedFrame). At the default window the page is
// exactly the hero (a 16:9 stage, or the list form's short band), one hint
// line and one row of cards at the foot, inside the page padding.
Item {
    id: frame

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
    readonly property real rowH: frame.listForm ? Math.max(Look.cardRowHeight, frame.height - Space.s - frame.bandH - frame.hintH - frame.gap - frame.pad) : Look.cardRowHeight
    readonly property real rowY: frame.height - frame.rowH - frame.pad
    // the stage form's hero: the height the hint and the row leave
    readonly property real heroH: Math.max(Space.px(160), frame.height - Space.s - frame.hintH - frame.gap - frame.rowH - frame.pad)
    readonly property real contentWidth: frame.width - frame.margin * 2
}
