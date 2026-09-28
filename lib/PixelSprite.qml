import QtQuick

// One piece of pixel art from Sprites.js, painted once at `pixel` screen
// pixels per art pixel. Moving or scaling the item afterwards costs the GPU a
// transform, not a repaint, which is why the arcade screensavers build their
// scenes out of these instead of redrawing a canvas every frame.
Canvas {
  id: sprite

  property var rows: []
  property var colors: ({})
  property real pixel: 3
  property bool mirror: false

  readonly property int columns: {
    var w = 0
    for (var i = 0; i < rows.length; i++) w = Math.max(w, rows[i].length)
    return w
  }

  width: Math.ceil(columns * pixel)
  height: Math.ceil(rows.length * pixel)
  antialiasing: false
  smooth: false

  onRowsChanged: requestPaint()
  onColorsChanged: requestPaint()
  onPixelChanged: requestPaint()
  onMirrorChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var p = sprite.pixel
    for (var y = 0; y < rows.length; y++) {
      var row = rows[y]
      var x = 0
      while (x < row.length) {
        var ch = row.charAt(x)
        var run = 1
        while (x + run < row.length && row.charAt(x + run) === ch) run++
        var color = sprite.colors[ch]
        if (ch !== "." && color) {
          var left = sprite.mirror ? sprite.columns - x - run : x
          ctx.fillStyle = color
          // Whole-pixel edges, so neighbouring runs never leave a seam.
          ctx.fillRect(Math.floor(left * p), Math.floor(y * p),
            Math.ceil(run * p), Math.ceil(p))
        }
        x += run
      }
    }
  }
}
