pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "MetricsModel.js" as MetricsModel

// The load history in an inset well: CPU, RAM and every GPU as a line over
// a soft fill in its series colour, the newest sample on the right edge, a
// hairline grid that scrolls with the samples. `zoom` sets how many samples
// show (MetricsModel.chartWindow); repaints on new samples while visible.
Well {
    id: root

    property real zoom: 1

    function requestPaint() {
        canvas.requestPaint();
    }

    onVisibleChanged: {
        if (visible)
            canvas.requestPaint();
    }

    Connections {
        target: SystemResources
        function onCpuHistoryChanged() {
            if (root.visible)
                canvas.requestPaint();
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.margins: Space.xs

        onPaint: {
            const ctx = getContext("2d");
            const w = width;
            const h = height;
            ctx.clearRect(0, 0, w, h);
            if (SystemResources.cpuHistory.length < 2)
                return;

            const win = MetricsModel.chartWindow(w, root.zoom, SystemResources.cpuHistory.length, SystemResources.totalDataPoints);

            // Grid: 8 rows, a column every 10 samples
            ctx.strokeStyle = Type.hairline;
            ctx.lineWidth = Space.hairline;
            for (let i = 1; i < 8; i++) {
                const y = h * (i / 8);
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(w, y);
                ctx.stroke();
            }
            for (const x of MetricsModel.gridLines(win, SystemResources.totalDataPoints)) {
                ctx.beginPath();
                ctx.moveTo(x, 0);
                ctx.lineTo(x, h);
                ctx.stroke();
            }

            function drawLine(history, color) {
                if (!history || history.length < 2)
                    return;
                const recent = history.slice(-Math.min(win.maxPoints, history.length));
                const xAt = i => win.offset + i * win.spacing;
                const yAt = i => h - recent[i] * h;

                const gradient = ctx.createLinearGradient(0, 0, 0, h);
                gradient.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0.4));
                gradient.addColorStop(0.5, Qt.rgba(color.r, color.g, color.b, 0.2));
                gradient.addColorStop(1, Qt.rgba(color.r, color.g, color.b, 0.0));
                ctx.fillStyle = gradient;
                ctx.beginPath();
                ctx.moveTo(xAt(0), h);
                for (let i = 0; i < recent.length; i++)
                    ctx.lineTo(xAt(i), yAt(i));
                ctx.lineTo(xAt(recent.length - 1), h);
                ctx.closePath();
                ctx.fill();

                ctx.strokeStyle = color;
                ctx.lineWidth = Space.stroke - 1;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.beginPath();
                for (let i = 0; i < recent.length; i++) {
                    if (i === 0)
                        ctx.moveTo(xAt(i), yAt(i));
                    else
                        ctx.lineTo(xAt(i), yAt(i));
                }
                ctx.stroke();
            }

            drawLine(SystemResources.cpuHistory, Colors[MetricsModel.seriesColor("cpu")]);
            drawLine(SystemResources.ramHistory, Colors[MetricsModel.seriesColor("ram")]);
            if (SystemResources.gpuDetected) {
                for (let i = 0; i < SystemResources.gpuCount; i++)
                    drawLine(SystemResources.gpuHistories[i], Colors[MetricsModel.seriesColor("gpu", SystemResources.gpuVendors[i])]);
            }
        }
    }
}
