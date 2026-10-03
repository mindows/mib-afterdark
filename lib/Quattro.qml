import QtQuick
import "Sprites.js" as Sprites

// The winged quattro, drawn as artwork in lib/art/: seen from above and in
// front, nose to the lower left. `pixel` sizes it in the units the old pixel
// sprite used (Sprites.quattroColumns wide), so screensavers can keep sizing
// cars as before. Every car of a livery shares one texture, and moving or
// scaling it never repaints anything.
Image {
  id: car

  property int livery: 0
  property real pixel: 3
  property bool facingLeft: true

  source: Qt.resolvedUrl("art/quattro-" + Math.max(0, Math.min(Sprites.quattroLiveries - 1, Math.floor(livery))) + ".png")
  width: Sprites.quattroColumns * pixel
  height: Sprites.quattroRows * pixel
  mirror: !facingLeft
  smooth: true
  mipmap: true
}
