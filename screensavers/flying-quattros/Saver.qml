import QtQuick
import "../../lib"
import "../../lib/Sprites.js" as Sprites
import "../../lib/Util.js" as Util

// Flying Quattros: winged rally cars flying down and to the left, the way
// toasters used to. Near cars are big and fast, far ones small and slow.
// Now and then one drives along the bottom, hits an invisible jump, and
// takes off. Traffic grows with every idle minute.
Item {
  id: root

  property var host: null
  property bool running: true

  readonly property string traffic: host ? host.option("traffic", "normal") : "normal"
  readonly property string trails: host ? host.option("trails", "dust") : "dust"
  readonly property string sky: host ? host.option("sky", "night") : "night"
  readonly property bool preview: host ? host.preview : false

  // Art pixels scale with the screen, so a 4K display is not full of ants.
  readonly property real unit: Math.max(0.5, height / 1080)
  readonly property int maxCars: 64
  readonly property int maxPuffs: 220

  property var cars: []
  property var puffs: []
  property real spawnClock: 0
  property real groundClock: 8
  property real flapClock: 0

  readonly property var trailColors: ({
    dust: ["#c8a672", "#b08d5a", "#d9c29a"],
    snow: ["#ffffff", "#e8f0ff", "#cfe0f5"],
    gravel: ["#8a8a8a", "#6e6e6e", "#a0a0a0"]
  })

  function targetCount() {
    var base = root.traffic === "calm" ? 5 : (root.traffic === "ridiculous" ? 16 : 9)
    var perMinute = root.traffic === "calm" ? 0.3 : (root.traffic === "ridiculous" ? 2.5 : 0.8)
    var minutes = root.host ? root.host.elapsed / 60 : 0
    var n = Math.floor(base + minutes * perMinute)
    return Math.min(root.preview ? 8 : root.maxCars - 4, n)
  }

  function freeSlot() {
    var used = {}
    for (var i = 0; i < root.cars.length; i++) used[root.cars[i].slot] = true
    for (var s = 0; s < root.maxCars; s++) if (!used[s]) return s
    return -1
  }

  function makeCar(kind, pixel, x, y, livery) {
    var slot = freeSlot()
    if (slot < 0) return null
    var p = pixel * root.unit
    var car = {
      slot: slot, kind: kind, pixel: p,
      x: x, y: y, vx: 0, vy: 0, rot: 0, spin: 0,
      livery: livery === undefined ? Util.randInt(0, Sprites.liveries.length - 1) : livery,
      flap: Math.random() * 4, flapRate: Util.rand(5, 9),
      wings: kind !== "ground", trail: 0, dirty: true, left: true, gravity: 0
    }
    var speed = p * Util.rand(34, 46)
    if (kind === "flyer" || kind === "giant") {
      car.vx = -speed
      car.vy = speed * Util.rand(0.42, 0.58)
    } else if (kind === "wrongway") {
      car.left = false
      car.vx = speed
      car.vy = -speed * 0.5
    } else if (kind === "ground") {
      car.vx = -speed * 1.6
      car.vy = 0
      // A third of ground cars find the jump.
      car.jumpAt = Math.random() < 0.34 ? Util.rand(0.3, 0.75) * root.width : -1
    }
    if (kind === "flyer" && Util.chance(30)) car.spin = Util.rand(-160, 160)
    root.cars.push(car)
    return car
  }

  // Cars enter from the top edge or the right edge, so the whole sky fills.
  function spawnFlyer() {
    var depth = Math.pow(Math.random(), 1.6)
    var pixel = 1.4 + depth * 4.6
    var w = 36 * pixel * root.unit
    var fromTop = Math.random() < root.width / (root.width + root.height)
    var x = fromTop ? Util.rand(0.1, 1.2) * root.width : root.width + w * 0.2
    var y = fromTop ? -w * 0.5 : Util.rand(-0.1, 0.7) * root.height

    if (root.host && root.host.rare(150)) {
      // The one that goes the wrong way.
      makeCar("wrongway", pixel, -w, Util.rand(0.4, 1.0) * root.height)
      return
    }
    if (root.host && root.host.rare(260) && !root.preview) {
      // Rare: a quattro so big it fills the sky on its way across.
      var gp = root.height / 13 / root.unit * 0.8
      var giant = makeCar("giant", gp, root.width, -root.height * 0.4)
      if (giant) { giant.vx *= 0.9; giant.vy *= 0.9 }
      return
    }
    if (Util.chance(22)) {
      // A formation of five, in a V.
      var livery = Util.randInt(0, Sprites.liveries.length - 1)
      var gap = 48 * pixel * root.unit
      for (var i = 0; i < 5; i++) {
        var rank = Math.ceil(i / 2)
        var sideSign = i % 2 === 0 ? 1 : -1
        var c = makeCar("flyer", pixel, x + rank * gap * 0.8, y - rank * gap * 0.25 * sideSign + rank * gap * 0.3, livery)
        if (c) { c.vx = -pixel * root.unit * 40; c.vy = pixel * root.unit * 20; c.spin = 0; c.flap = i * 0.4 }
      }
      return
    }
    makeCar("flyer", pixel, x, y)
  }

  function spawnGround() {
    var pixel = 3.2 + Math.random() * 1.6
    var h = 13 * pixel * root.unit
    var car = makeCar("ground", pixel, root.width + 20, root.height - h - root.height * 0.02)
    if (car) car.trail = 0
  }

  function emitPuff(car) {
    if (root.trails === "none" || root.puffs.length >= root.maxPuffs) return
    var w = 36 * car.pixel
    var h = 13 * car.pixel
    var rearX = car.left ? car.x + w * 0.92 : car.x + w * 0.08
    var colors = root.trailColors[root.trails] || root.trailColors.dust
    root.puffs.push({
      x: rearX + Util.rand(-2, 2) * car.pixel, y: car.y + h * 0.85 + Util.rand(-1, 1) * car.pixel,
      vx: -car.vx * 0.08 + Util.rand(-8, 8), vy: Util.rand(-14, 4) * root.unit,
      size: car.pixel * Util.rand(2.5, 4.5), grow: car.pixel * 6,
      life: 0, ttl: Util.rand(0.6, 1.1), color: Util.pick(colors),
      square: root.trails === "gravel" || root.trails === "snow"
    })
  }

  property bool seeded: false

  // Start mid-flight rather than with an empty sky. Done on the first frame,
  // once the item has its real size.
  function seed() {
    root.seeded = true
    for (var i = 0; i < 6; i++) {
      spawnFlyer()
      var c = root.cars[root.cars.length - 1]
      if (c && c.kind === "flyer") { c.x = Util.rand(0.1, 1.0) * root.width; c.y = Util.rand(0, 0.8) * root.height }
    }
  }

  function step(dt) {
    if (root.width <= 0) return
    if (!root.seeded) seed()
    root.flapClock += dt

    root.spawnClock -= dt
    var flyers = 0
    for (var i = 0; i < root.cars.length; i++) if (root.cars[i].kind !== "ground") flyers++
    if (root.spawnClock <= 0 && flyers < targetCount()) {
      spawnFlyer()
      root.spawnClock = Util.rand(0.25, 1.2) * (root.traffic === "ridiculous" ? 0.4 : 1)
    }

    root.groundClock -= dt
    if (root.groundClock <= 0 && !root.preview) {
      spawnGround()
      root.groundClock = Util.rand(18, 45)
    }

    var kept = []
    for (var c = 0; c < root.cars.length; c++) {
      var car = root.cars[c]
      if (car.kind === "ground") {
        if (car.jumpAt > 0 && car.x < car.jumpAt) {
          // Off the invisible jump: up it goes, and out come the wings.
          car.jumpAt = -1
          car.kind = "flyer"
          car.wings = true
          car.dirty = true
          car.vy = -car.pixel * 70
          car.gravity = car.pixel * 38
          car.spin = -25
        }
      }
      if (car.gravity > 0) {
        car.vy += car.gravity * dt
        // Level out into a normal glide once the jump has peaked.
        if (car.vy > -car.vx * 0.5) { car.gravity = 0; car.spin = 0 }
      }
      car.x += car.vx * dt
      car.y += car.vy * dt
      car.rot = car.gravity > 0 ? Math.max(-18, car.rot + car.spin * dt) : (car.spin !== 0 ? car.rot + car.spin * dt : car.rot * 0.95)
      car.flap += dt * car.flapRate
      car.trail -= dt
      if (car.trail <= 0 && (car.kind === "ground" || car.pixel > 2.4 * root.unit)) {
        emitPuff(car)
        car.trail = car.kind === "ground" ? 0.03 : 0.09
      }
      var w = 36 * car.pixel
      var gone = car.left ? (car.x < -w * 1.3 || car.y > root.height + w) : (car.x > root.width + w || car.y < -w)
      if (!gone) kept.push(car)
    }
    root.cars = kept

    var livePuffs = []
    for (var p = 0; p < root.puffs.length; p++) {
      var puff = root.puffs[p]
      puff.life += dt
      if (puff.life >= puff.ttl) continue
      puff.x += puff.vx * dt
      puff.y += puff.vy * dt
      livePuffs.push(puff)
    }
    root.puffs = livePuffs
    sync()
  }

  function sync() {
    var bySlot = {}
    for (var i = 0; i < root.cars.length; i++) bySlot[root.cars[i].slot] = root.cars[i]
    for (var s = 0; s < root.maxCars; s++) {
      var item = carRepeater.itemAt(s)
      if (!item) continue
      var car = bySlot[s]
      if (!car) { item.visible = false; continue }
      if (car.dirty) {
        item.pixel = car.pixel
        item.facingLeft = car.left
        item.livery = car.livery
        item.wings = car.wings
        item.z = car.pixel
        car.dirty = false
      }
      item.x = car.x
      item.y = car.y
      item.rotation = car.rot
      item.frame = Math.floor(car.flap) % Sprites.wingFrames.length
      item.visible = true
    }
    for (var p = 0; p < root.maxPuffs; p++) {
      var dot = puffRepeater.itemAt(p)
      if (!dot) continue
      var puff = root.puffs[p]
      if (!puff) { dot.visible = false; continue }
      var t = puff.life / puff.ttl
      var size = puff.size + puff.grow * t
      dot.width = size
      dot.height = size
      dot.radius = puff.square ? 0 : size / 2
      dot.x = puff.x - size / 2
      dot.y = puff.y - size / 2
      dot.color = puff.color
      dot.opacity = (1 - t) * 0.7
      dot.visible = true
    }
  }

  // ------------------------------------------------------------------ scene

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0; color: root.sky === "night" ? "#05070f" : "black" }
      GradientStop { position: 1; color: root.sky === "night" ? "#16203a" : "black" }
    }
  }

  // A few still stars, far behind everything.
  Repeater {
    model: root.sky === "night" ? 90 : 0
    Rectangle {
      required property int index
      readonly property real seed: Math.sin(index * 12.9898) * 43758.5453
      x: (seed - Math.floor(seed)) * root.width
      y: ((seed * 7.13) - Math.floor(seed * 7.13)) * root.height * 0.8
      width: Math.max(1, root.unit * (index % 7 === 0 ? 2 : 1))
      height: width
      color: "#cdd6f4"
      opacity: 0.25 + (index % 5) * 0.1
    }
  }

  Item {
    anchors.fill: parent
    Repeater {
      id: puffRepeater
      model: root.maxPuffs
      Rectangle { visible: false; antialiasing: false }
    }
  }

  Item {
    anchors.fill: parent
    Repeater {
      id: carRepeater
      model: root.maxCars

      Item {
        id: carItem
        property real pixel: 3
        property bool facingLeft: true
        property int livery: 0
        property bool wings: true
        property int frame: 0

        visible: false
        width: body.width
        height: body.height
        transformOrigin: Item.Center

        PixelSprite {
          id: wing
          visible: carItem.wings
          rows: Sprites.wingFrames[carItem.frame]
          colors: Sprites.wingPalette
          pixel: carItem.pixel
          mirror: carItem.facingLeft
          // The joint sits on the roof, a little behind the B-pillar.
          x: carItem.facingLeft
            ? (Sprites.width(Sprites.quattro) - 1 - Sprites.roofJoint) * carItem.pixel
            : (Sprites.roofJoint - 19) * carItem.pixel
          y: -9 * carItem.pixel
        }

        PixelSprite {
          id: body
          rows: Sprites.quattro
          colors: Sprites.quattroPalette(Sprites.liveries[carItem.livery])
          pixel: carItem.pixel
          mirror: carItem.facingLeft
        }
      }
    }
  }

  FrameAnimation {
    running: root.running && root.visible
    onTriggered: root.step(Math.min(frameTime, 0.05))
  }

}
