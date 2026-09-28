import QtQuick
import "PixelFont.js" as Font

// A line of text in the 3 x 5 arcade font, `pixel` screen pixels per cell.
Canvas {
  id: label

  property string text: ""
  property color color: "white"
  property real pixel: 4

  width: Math.max(1, Math.ceil(Font.measure(text) * pixel))
  height: Math.ceil(5 * pixel)
  antialiasing: false
  smooth: false

  onTextChanged: requestPaint()
  onColorChanged: requestPaint()
  onPixelChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    ctx.fillStyle = label.color
    var p = label.pixel
    var s = label.text
    for (var i = 0; i < s.length; i++) {
      var g = Font.glyph(s.charAt(i))
      var ox = i * 4
      for (var y = 0; y < 5; y++)
        for (var x = 0; x < 3; x++)
          if (g[y].charAt(x) === "#")
            ctx.fillRect(Math.floor((ox + x) * p), Math.floor(y * p), Math.ceil(p), Math.ceil(p))
    }
  }
}
