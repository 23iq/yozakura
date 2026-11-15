.pragma library

// Width of the landscape pictures of a strip (the Shape cards of the bar
// page): 16:10 pictures with a caption line under them, inset by `gap`
// on every side of the strip and between pictures. As tall as the strip
// allows; when they do not all fit across, three whole pictures and a
// peek of the fourth (a hint to scroll). Never under `min`.
//
// landscapeWidth(width, height, count, gap, caption, min) -> px
function landscapeWidth(width, height, count, gap, caption, min) {
    var n = Math.max(1, count);
    var avail = width - gap * 2;
    var byHeight = (height - gap * 2 - caption) * 16 / 10;
    var fitAll = (avail - gap * (n - 1)) / n;
    var byWidth = fitAll >= min ? fitAll : (avail - gap * 3) / 3.4;
    return Math.max(min, Math.min(byHeight, byWidth));
}

// contentX that shows picture `index` whole (pictures `w` wide, `gap`
// apart, the first at `gap`): unchanged when it already shows whole,
// else the least scroll that brings it in. -1 = no picture: unchanged.
function revealX(contentX, viewWidth, contentWidth, index, w, gap) {
    if (index < 0)
        return contentX;
    var left = gap + index * (w + gap);
    var right = left + w;
    var x = contentX;
    if (left - gap < x)
        x = left - gap;
    else if (right + gap > x + viewWidth)
        x = right + gap - viewWidth;
    return Math.max(0, Math.min(Math.max(0, contentWidth - viewWidth), x));
}
