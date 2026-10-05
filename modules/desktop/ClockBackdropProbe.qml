import QtQuick

// Luminance-only placement grid measured in QML, for when the depth mask
// script has no data (venv not installed): same format as the grid from
// scripts/depth_mask.py, with zero subject coverage. Lets the clock still
// pick dark or light ink. Draws the wallpaper once, cropped like
// PreserveAspectCrop, into a tiny invisible canvas.
Canvas {
    id: probe

    // Local image path ("" disables the probe).
    property string source: ""
    property int screenW: 1
    property int screenH: 1
    readonly property int rows: 54
    readonly property int cols: Math.max(1, Math.round(screenW * rows / Math.max(1, screenH)))
    // { cols, rows, cover, lum } or null until measured.
    property var grid: null

    readonly property string url: source ? "file://" + source : ""
    property string _loaded: ""

    function hex(v) {
        const s = Math.max(0, Math.min(255, Math.round(v))).toString(16);
        return s.length < 2 ? "0" + s : s;
    }

    width: cols
    height: rows
    opacity: 0
    renderStrategy: Canvas.Immediate

    onUrlChanged: {
        grid = null;
        if (_loaded)
            unloadImage(_loaded);
        _loaded = url;
        if (url)
            loadImage(url);
    }
    onImageLoaded: requestPaint()
    onColsChanged: requestPaint()

    onPaint: {
        if (!url || !isImageLoaded(url))
            return;
        const ctx = getContext("2d");
        const img = ctx.createImageData(url);
        if (!img || img.width <= 0 || img.height <= 0)
            return;
        // PreserveAspectCrop: scale to cover, centre crop.
        const scale = Math.max(cols / img.width, rows / img.height);
        const sw = cols / scale, sh = rows / scale;
        ctx.clearRect(0, 0, cols, rows);
        ctx.drawImage(url, (img.width - sw) / 2, (img.height - sh) / 2, sw, sh, 0, 0, cols, rows);
        const px = ctx.getImageData(0, 0, cols, rows).data;
        let lum = "";
        for (let i = 0; i < cols * rows; i++)
            lum += hex(0.299 * px[i * 4] + 0.587 * px[i * 4 + 1] + 0.114 * px[i * 4 + 2]);
        grid = {
            cols: cols,
            rows: rows,
            cover: "00".repeat(cols * rows),
            lum: lum
        };
    }
}
