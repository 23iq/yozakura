.pragma library

// The card width of a sideways strip of pictures (PromptStrip,
// GreetingChips) that does not fit its room: the cards are resized (never
// more than `give` either way) so the edge cuts the last one about in half
// (a clear "more this way" under the strip's fade), never a sliver.
// room: the strip's width; inset: the first card's x; gap: between cards;
// natural: the card width it would have; count: the cards. A strip that
// fits keeps `natural`.
function cardWidth(room, inset, gap, natural, count, give) {
    const g = give === undefined ? 0.3 : give;
    if (!(room > 0) || !(natural > 0) || count <= 0)
        return natural;
    if (inset * 2 + count * natural + (count - 1) * gap <= room)
        return natural;
    // whole cards shown at the natural width
    const shown = (room - inset + gap) / (natural + gap);
    let best = natural;
    let bestCut = 1;
    for (let k = Math.max(1, Math.floor(shown) - 1); k <= Math.ceil(shown) + 1 && k < count; k++) {
        // k whole cards and half of the next
        const w = (room - inset - k * gap) / (k + 0.5);
        if (w < natural * (1 - g) || w > natural * (1 + g))
            continue;
        const cut = Math.abs(w - natural) / natural;
        if (cut < bestCut) {
            best = w;
            bestCut = cut;
        }
    }
    return Math.round(best);
}
