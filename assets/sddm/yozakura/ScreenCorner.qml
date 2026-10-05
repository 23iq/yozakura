import QtQuick

// Rounded screen corner (modules/corners/RoundCorner.qml geometry).
Canvas {
    id: corner

    property int size: 20
    // 0 top-left, 1 top-right, 2 bottom-left, 3 bottom-right
    property int which: 0

    width: size
    height: size
    antialiasing: true
    onPaint: {
        var ctx = getContext("2d");
        var r = size;
        ctx.clearRect(0, 0, width, height);
        ctx.beginPath();
        if (which === 0) {
            ctx.arc(r, r, r, Math.PI, 3 * Math.PI / 2);
            ctx.lineTo(0, 0);
        } else if (which === 1) {
            ctx.arc(0, r, r, 3 * Math.PI / 2, 2 * Math.PI);
            ctx.lineTo(r, 0);
        } else if (which === 2) {
            ctx.arc(r, 0, r, Math.PI / 2, Math.PI);
            ctx.lineTo(0, r);
        } else {
            ctx.arc(0, 0, r, 0, Math.PI / 2);
            ctx.lineTo(r, r);
        }
        ctx.closePath();
        ctx.fillStyle = "#000000";
        ctx.fill();
    }
}
