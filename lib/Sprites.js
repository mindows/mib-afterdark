.pragma library

// Pixel art for the bundled screensavers, drawn from scratch for After Dark.
// Each sprite is a list of rows; each character is one pixel and names a
// color in the palette handed to PixelSprite. "." is transparent.
//
// The quattro is artwork rather than a pixel grid: lib/art/quattro-<n>.png,
// drawn by lib/Quattro.qml. In the grid units the other sprites use it is
// quattroColumns wide and quattroRows tall. Liveries, by number: white works
// rally car, tornado red, black with gold, yellow, blue, green.
var quattroColumns = 36
var quattroRows = 36 * 265 / 467
var quattroLiveries = 6

// Tux, 12 x 12. K black, W white, Y beak and feet.
var tux = [
  "...KKKKKK...",
  "..KKKKKKKK..",
  "..KWKKKKWK..",
  "..KKYYYYKK..",
  ".KKWYYYYWKK.",
  ".KKWWWWWWKK.",
  "KKWWWWWWWWKK",
  "KKWWWWWWWWKK",
  "KKWWWWWWWWKK",
  ".KKWWWWWWKK.",
  "..YYKKKKYY..",
  ".YYYY..YYYY."
]

var tuxPalette = { K: "#101014", W: "#f5f5f0", Y: "#f6a91c" }

// Invaders enemies, two frames each, 11 x 8.
var enemyPackage = [[
  "..KKKKKKK..",
  ".KBBBSBBBK.",
  "KBBBBSBBBBK",
  "KSSSSSSSSSK",
  "KBBBBSBBBBK",
  "KBBBBSBBBBK",
  ".KKKKKKKKK.",
  "K.K.....K.K"
], [
  "..KKKKKKK..",
  ".KBBBSBBBK.",
  "KBBBBSBBBBK",
  "KSSSSSSSSSK",
  "KBBBBSBBBBK",
  "KBBBBSBBBBK",
  ".KKKKKKKKK.",
  ".K.K...K.K."
]]

var enemyDependency = [[
  "...B...B...",
  "....B.B....",
  "...BBBBB...",
  "..BBKBKBB..",
  ".BBBBBBBBB.",
  ".B.BBBBB.B.",
  ".B.B...B.B.",
  "....BB.BB.."
], [
  "...B...B...",
  "B...B.B...B",
  "B..BBBBB..B",
  "B.BBKBKBB.B",
  "BBBBBBBBBBB",
  "..BBBBBBB..",
  "...B...B...",
  "..B.....B.."
]]

var enemyBug = [[
  "B..B...B..B",
  ".B.BBBBB.B.",
  "..BBBBBBB..",
  ".BBKBBBKBB.",
  "BBBBBBBBBBB",
  "B.BBBBBBB.B",
  "B.B.....B.B",
  "...BB.BB..."
], [
  "..B.....B..",
  "B..BBBBB..B",
  "B.BBBBBBB.B",
  "BBBKBBBKBBB",
  "BBBBBBBBBBB",
  ".BBBBBBBBB.",
  ".B.......B.",
  "B.........B"
]]

// The defender, 13 x 8.
var ship = [
  "......K......",
  ".....KWK.....",
  ".....KWK.....",
  "..K.KWWWK.K..",
  ".KWKWWWWWKWK.",
  "KWWWWWWWWWWWK",
  "KWWWWYWYWWWWK",
  "KKKKKKKKKKKKK"
]

function width(rows) {
  var w = 0
  for (var i = 0; i < rows.length; i++) w = Math.max(w, rows[i].length)
  return w
}
