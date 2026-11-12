import QtQuick
import qs.modules.theme

Canvas {
    id: root

    // =========================================================================
    // API Properties
    // =========================================================================
    property color color: Styling.srItem("overprimary")
    property real lineWidth: 2
    property real frequency: 2
    property real amplitudeMultiplier: 0.5
    property real fullLength: width
    property bool running: true

    // Legacy compatibility
    property real amplitude: lineWidth * amplitudeMultiplier
    property real speed: 5  // Not used with Date.now() technique, kept for API compat
    property bool animationsEnabled: true

    // =========================================================================
    // Rendering
    // =========================================================================
    readonly property bool shouldAnimate: running && animationsEnabled && 
                                          visible && width > 0 && opacity > 0

    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        if (width <= 0 || height <= 0) return;

        var amp = root.lineWidth * root.amplitudeMultiplier;
        var freq = root.frequency;
        var phase = Date.now() / 400.0;
        var centerY = height / 2;

        ctx.strokeStyle = root.color;
        ctx.lineWidth = root.lineWidth;
        ctx.lineCap = "round";
        ctx.beginPath();

        for (var x = ctx.lineWidth / 2; x <= root.width - ctx.lineWidth / 2; x += 1) {
            var waveY = centerY + amp * Math.sin(freq * 2 * Math.PI * x / root.fullLength + phase);
            if (x === ctx.lineWidth / 2)
                ctx.moveTo(x, waveY);
            else
                ctx.lineTo(x, waveY);
        }

        ctx.stroke();
    }

    // =========================================================================
    // Animation Driver - capped repaint rate
    // =========================================================================
    // The phase comes from the clock (Date.now() in onPaint), so the wave
    // moves at the same speed at any repaint rate. A FrameAnimation repainted
    // the canvas (CPU raster + texture upload, and a frame of the whole
    // window) at the output's refresh rate, up to 240/s. The wave is slow and
    // low, so ~30 repaints per second draw the same motion.
    readonly property int maxFps: 30

    Timer {
        interval: Math.round(1000 / root.maxFps)
        repeat: true
        running: root.shouldAnimate
        onTriggered: root.requestPaint()
    }

    // While stopped nothing repaints per frame, so redraw the static line
    // once whenever its shape or colour changes (e.g. playing -> paused
    // flattens the wave).
    onColorChanged: requestPaint()
    onLineWidthChanged: requestPaint()
    onFrequencyChanged: requestPaint()
    onAmplitudeMultiplierChanged: requestPaint()
    onFullLengthChanged: requestPaint()
    onShouldAnimateChanged: requestPaint()
}
