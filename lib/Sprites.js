.pragma library

// Pixel art for the bundled screensavers, drawn from scratch for After Dark.
// Each sprite is a list of rows; each character is one pixel and names a
// color in the palette handed to PixelSprite. "." is transparent.
//
// The quattro is a generic boxy 1980s rally coupe (long bonnet, upright glass,
// box arches, spot lamps). It carries no maker's badge or logo.

// Facing right. K outline, B body, b body shade, S livery stripe, D door
// shut line, W glass, w glass glint, L headlamp, R tail lamp, Y spot lamp,
// T tyre, H hub.
var quattro = [
  "..........KKKKKKKKKKKK",
  ".........KWWWWWKWWWWWWK",
  "........KWwWWWWKWWWWWWWK",
  ".......KWwWWWWWKWWWWWWWWK",
  "..KKKKKBBBBBBBBBBBBBBBBBBKKKKKKKKKK",
  ".KBBBBBBBBBBBBBBBDBBBBBBBBBBBBBBBBBK",
  "KRBBBBBBBBBBBBBBBDBBBBBBBBBBBBBBBBLK",
  "KSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSK",
  "KBBBKKKKKKBBBBBBDBBBBBBKKKKKKBBBBYYK",
  "KbbKTTTTTTKbbbbbbbbbbbKTTTTTTKbbbbbK",
  ".KKTTHHHHTTKKKKKKKKKKKTTHHHHTTKKKKK.",
  "...TTHHHHTT...........TTHHHHTT",
  "....TTTTTT.............TTTTTT"
]

// Where a wing's joint meets the roof, in the right-facing car's columns.
var roofJoint = 17

// Wing frames for a right-facing quattro. Each frame's joint is its
// bottom-right pixel, so every frame lines up on the same anchor.
var wingUp = [
  "KK..................",
  "KWKK................",
  ".KWWKK..............",
  ".KWwWWKK............",
  "..KWwWWWKK..........",
  "..KWWwWWWWKK........",
  "...KWWWwWWWWKK......",
  "...KKWWWWwWWWWKK....",
  ".....KKWWWWWWWWWKK..",
  ".......KKKWWWWWWWWK.",
  "..........KKKKKKKKKK"
]

var wingMid = [
  "....................",
  "....................",
  "....................",
  "....................",
  "KKKKKK..............",
  "KWWWWWKKKKK.........",
  ".KWwWWWWWWWKKKKK....",
  "..KKWWwWWWWWWWWWKK..",
  "....KKKWWWWwWWWWWWK.",
  ".......KKKKWWWWWWWWK",
  "...........KKKKKKKKK"
]

var wingDown = [
  "....................",
  "....................",
  "....................",
  "....................",
  "....................",
  "..............KKKKKK",
  "..........KKKKWWWWWK",
  "......KKKKWWWwWWWWKK",
  "..KKKKWWWwWWWKKKKK..",
  "KKWWWWWWKKKKK.......",
  "KKKKKKKK............"
]

var wingFrames = [wingUp, wingMid, wingDown, wingMid]

// Liveries: a body color, its shade, and a stripe.
var liveries = [
  { B: "#f2f2ee", b: "#bdbdb6", S: "#d8262e" },   // white works rally car
  { B: "#d8262e", b: "#9c1a20", S: "#f2f2ee" },   // tornado red
  { B: "#1b1d22", b: "#0c0d10", S: "#f2c230" },   // black with gold
  { B: "#f2c230", b: "#b58e1c", S: "#1b1d22" },   // yellow
  { B: "#3a7bd5", b: "#264f8a", S: "#f2f2ee" },   // blue
  { B: "#2f8f4e", b: "#1f5f34", S: "#f2f2ee" }    // green
]

var carColors = {
  K: "#0b0b0d", W: "#6fa8d6", w: "#d9f0ff", L: "#fff4b8", R: "#ff3b30",
  Y: "#ffd84a", T: "#16161a", H: "#9aa0a6", D: "rgba(0,0,0,0.35)"
}

function quattroPalette(livery) {
  var p = {}
  for (var k in carColors) p[k] = carColors[k]
  p.B = livery.B
  p.b = livery.b
  p.S = livery.S
  return p
}

var wingPalette = { K: "#0b0b0d", W: "#fbfbf6", w: "#c9c9c2" }

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
