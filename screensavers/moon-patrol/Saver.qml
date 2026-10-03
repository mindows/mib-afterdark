import QtQuick
import QtQuick.Shapes
import "../../lib"
import "../../lib/Sprites.js" as Sprites
import "../../lib/Util.js" as Util

// Moon Patrol: a six-wheeled buggy drives an endless lunar highway on its
// own. It jumps craters, shoots boulders out of the way, and fires straight
// up at saucers and their bombs, over two parallax ranges. With the Quattro
// option on, some stretches are a rally stage driven by a quattro, and a
// winged one now and then crosses the sky as a bonus target.
Item {
  id: root

  property var host: null
  property bool running: true

  readonly property bool preview: host ? host.preview : false
  readonly property bool frantic: (host ? host.option("pace", "patrol") : "patrol") === "frantic"
  readonly property bool themed: (host ? host.option("color", "arcade") : "arcade") === "theme"
  readonly property bool quattroTwist: host ? host.option("quattro", true) !== false : true

  readonly property real unit: Math.max(0.5, height / 1080)
  readonly property real px: 6 * unit
  readonly property real groundY: Math.round(height * 0.84)
  readonly property real buggyX: Math.round(width * 0.22)
  readonly property real speed: (frantic ? 480 : 400) * unit
  readonly property real gravity: 1500 * unit
  readonly property real jumpV: 700 * unit
  // How far the vehicle travels in one jump.
  readonly property real reach: speed * 2 * jumpV / gravity
  readonly property real pointLength: 2400 * unit
  readonly property string letters: "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

  // The vehicle on the road: the buggy, or the quattro on a rally stage.
  // updateRally() decides it, so a change can be announced.
  property bool rally: false
  // Switching Quattro on starts a stage at once, lasting until this point.
  property int rallyEnd: -1
  onQuattroTwistChanged: if (quattroTwist) rallyEnd = point + 2
  readonly property real carW: (rally ? 30 : 24) * px

  property real dist: 0
  property var car: freshCar()
  property var obstacles: []
  property var shots: []
  property var ufos: []
  property var flyer: null
  property var bombs: []
  property var particles: []
  property real nextSpawn: 0
  property real ufoClock: 5
  property int point: 0
  property int lap: 0
  property int score: 0
  property int hiScore: 0
  property int lives: 3
  property string banner: ""
  property real bannerTime: 0
  property bool started: false
  property string builtFor: ""
  property real clock: 0
  property int wheelFrame: 0

  // ---------------------------------------------------------------- colors

  function mix(a, b, t) {
    return Qt.tint(a, Qt.rgba(b.r, b.g, b.b, t))
  }

  // Scenery and HUD. The vehicles and saucers keep their arcade colors so
  // they read against any theme.
  readonly property var scene: {
    if (!themed || !host) return {
      skyTop: "#000004", skyLow: "#0a0a2a", star: "#ffffff",
      far: "#1c3a9a", farRim: "#5f8dff", near: "#17663a", nearRim: "#4fc26a",
      ground: "#b88a52", lip: "#ecc98e", pebble: "#8a6236", pit: "#2a1a0c", pitRim: "#5a3a1c",
      rock: "#a07850", rockDark: "#5e4028", hud: "#ffffff", banner: "#ffe14a", course: "#5f8dff"
    }
    var bg = host.background, fg = host.foreground, ac = host.accent
    return {
      skyTop: String(bg), skyLow: String(mix(bg, ac, 0.12)), star: String(fg),
      far: String(mix(bg, ac, 0.25)), farRim: String(mix(bg, ac, 0.6)),
      near: String(mix(bg, ac, 0.45)), nearRim: String(ac),
      ground: String(mix(bg, fg, 0.55)), lip: String(fg), pebble: String(mix(bg, fg, 0.38)),
      pit: String(mix(bg, fg, 0.12)), pitRim: String(mix(bg, fg, 0.3)),
      rock: String(mix(bg, fg, 0.78)), rockDark: String(mix(bg, fg, 0.42)),
      hud: String(fg), banner: String(ac), course: String(ac)
    }
  }

  // ------------------------------------------------------------ the game

  // Quattro stages are two points long and start at A, I and Q, so every
  // game opens on one.
  function stagePoint(p) {
    var i = p % 26
    return i === 0 || i === 1 || i === 8 || i === 9 || i === 16 || i === 17
  }

  function updateRally() {
    var want = root.quattroTwist && (stagePoint(root.point) || root.point < root.rallyEnd)
    if (want === root.rally) return
    // A stage that starts a new lap leaves COURSE COMPLETE up; one that
    // ends because Quattro was switched off earns nothing.
    if (want && !(root.point > 0 && root.point % 26 === 0)) showBanner("QUATTRO STAGE", 2.2)
    if (!want && root.quattroTwist) {
      root.score += 2000
      showBanner("STAGE CLEAR 2000", 2.2)
    }
    if (root.car.alive)
      explode(root.buggyX + root.carW / 2, root.groundY - 4 * root.px - root.car.h, 30, 200, root.scene.lip, true)
    root.rally = want
  }

  function freshCar() {
    return { h: 0, vh: 0, alive: true, respawn: 0, upCool: 0, fwdCool: 0, bounce: [0, 0, 0] }
  }

  function showBanner(text, seconds) {
    root.banner = text
    root.bannerTime = seconds
  }

  function pointBanner() {
    showBanner("POINT " + root.letters.charAt(root.point % 26), 1.6)
  }

  function saveHiScore() {
    if (root.score <= root.hiScore) return
    root.hiScore = root.score
    if (root.host) root.host.set("hiscore", root.hiScore)
  }

  function newGame() {
    saveHiScore()
    root.score = 0
    root.lives = 3
    root.dist = 0
    root.point = 0
    root.lap = 0
    root.obstacles = []
    root.ufos = []
    root.flyer = null
    root.bombs = []
    root.shots = []
    root.nextSpawn = root.width * 0.9
    root.car = freshCar()
    root.rallyEnd = -1
    // Set directly: GAME OVER goes up right after this and should stay.
    root.rally = root.quattroTwist && stagePoint(0)
    showBanner(root.rally ? "QUATTRO STAGE" : "POINT A", 2)
  }

  function insertObstacle(o) {
    var i = root.obstacles.length
    while (i > 0 && root.obstacles[i - 1].x > o.x) i--
    root.obstacles.splice(i, 0, o)
  }

  function spawn() {
    // The road gets busier with every lap of the course, up to a point.
    var busy = Math.max(0.7, 1 - root.lap * 0.06) * (root.frantic ? 0.8 : 1)
    while (root.nextSpawn < root.dist + root.width * 1.3) {
      var roll = Math.random()
      var o = null
      if (roll < 0.45) {
        o = { kind: "crater", x: root.nextSpawn, w: Util.rand(50, 130) * root.unit }
      } else if (roll < 0.85) {
        var big = Util.chance(3)
        o = { kind: "rock", x: root.nextSpawn, big: big, w: (big ? 9 : 6) * root.px, hp: big ? 2 : 1 }
      }
      if (o) {
        // Now and then the pilot misjudges a jump.
        o.error = (Util.chance(20) ? Util.rand(-90, 90) : Util.rand(-8, 8)) * root.unit
        root.obstacles.push(o)
      }
      root.nextSpawn += Util.rand(1.3, 3) * busy * root.reach + (o ? o.w : 0)
    }
  }

  // Debris thrown upward (`burst` false) or in every direction.
  function explode(x, y, count, speed, color, burst) {
    for (var i = 0; i < count && root.particles.length < root.maxParticles; i++) {
      var a = burst ? Math.random() * Math.PI * 2 : -Math.random() * Math.PI
      var v = Math.random() * speed * root.unit
      root.particles.push({ x: x, y: y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, life: Util.rand(0.4, 1.1), color: color, g: 600 })
    }
  }

  function crash() {
    var c = root.car
    c.alive = false
    c.respawn = 2.5
    root.lives--
    var cx = root.buggyX + root.carW / 2, cy = root.groundY - 6 * root.px - c.h
    explode(cx, cy, 50, 300, "#ff9a3c", false)
    explode(cx, cy, 30, 220, root.rally ? "#f4f4f4" : "#d070ff", false)
  }

  // Where the guns are, in screen coordinates, for the vehicle on the road.
  function frontGun() {
    return { x: root.buggyX + root.carW, y: root.groundY - (root.rally ? 6.5 : 4.5) * root.px - root.car.h }
  }

  function roofGun() {
    if (root.rally) return { x: root.buggyX + 15 * root.px, y: root.groundY - 11 * root.px - root.car.h }
    return { x: root.buggyX + 3.5 * root.px, y: root.groundY - 10 * root.px - root.car.h }
  }

  // The pilot: jump what can't be shot, shoot what can, watch the sky.
  function think(dt) {
    var c = root.car
    var front = root.dist + root.buggyX + root.carW
    var rear = root.dist + root.buggyX
    c.fwdCool -= dt
    c.upCool -= dt

    for (var i = 0; i < root.obstacles.length; i++) {
      var o = root.obstacles[i]
      if (o.x + o.w < rear || (o.kind === "rock" && o.hp <= 0)) continue
      var d = o.x - front
      if (o.kind === "rock" && d > 0 && d < root.width * 0.45) {
        // Some boulders it would rather jump.
        if (o.shoot === undefined) o.shoot = !Util.chance(4)
        if (o.shoot && c.fwdCool <= 0 && c.h <= 0) {
          var g = frontGun()
          root.shots.push({ up: false, x: g.x, y: g.y, travelled: 0 })
          c.fwdCool = 0.3
        }
      }
      // Take off so the jump's midpoint is over the middle of the obstacle.
      if (c.h <= 0 && d <= (root.reach - root.carW - o.w) / 2 + o.error && d > -root.carW * 0.3) {
        c.vh = root.jumpV
        c.h = 0.01
      }
      break
    }

    if (c.upCool > 0) return
    var gun = roofGun()
    var shotSpeed = 800 * root.unit
    var aim = false
    var targets = root.ufos.slice()
    if (root.flyer) targets.push(root.flyer)
    for (var u = 0; u < targets.length && !aim; u++) {
      var t = targets[u]
      var lead = (gun.y - t.y) / shotSpeed
      aim = Math.abs(t.x + t.vx * lead + t.w / 2 - gun.x) < 14 * root.unit
    }
    // The same window a shot needs to hit a bomb.
    for (var k = 0; k < root.bombs.length && !aim; k++)
      aim = Math.abs(root.bombs[k].x - gun.x) < 3 * root.px && root.bombs[k].y < gun.y - 60 * root.unit
    if (aim) {
      root.shots.push({ up: true, x: gun.x, y: gun.y, travelled: 0 })
      c.upCool = 0.22
    }
  }

  function launchSky() {
    // A winged quattro now and then instead of saucers, worth far more.
    if (root.quattroTwist && !root.preview && (root.host ? root.host.rare(12) : Util.chance(12))) {
      var fromLeft = Math.random() < 0.5
      var pixel = 2.4 * root.unit
      var w = Sprites.quattroColumns * pixel
      root.flyer = {
        x: fromLeft ? -w : root.width, baseY: Util.rand(0.1, 0.22) * root.height, y: 0,
        vx: (fromLeft ? 1 : -1) * 230 * root.unit, t: 0, w: w, hgt: Sprites.quattroRows * pixel, pixel: pixel,
        livery: Util.randInt(0, Sprites.quattroLiveries - 1)
      }
      return
    }
    var n = Util.randInt(1, root.frantic ? 4 : 3)
    for (var f = 0; f < n; f++)
      root.ufos.push({
        x: -80 * root.unit - f * 90 * root.unit, baseY: Util.rand(0.12, 0.32) * root.height, y: 0,
        vx: Util.rand(160, 240) * root.unit, w: 12 * root.px, t: Math.random() * 6,
        life: Util.rand(9, 14), bomb: Util.rand(1, 2.5)
      })
  }

  function step(dt) {
    if (root.width <= 0) return
    var size = root.width + "x" + root.height
    if (root.builtFor !== size) {
      root.builtFor = size
      farRange.outline = skyline(root.width, 2 * root.px, root.groundY - root.height * 0.1, [0.15, 0.06, 0.04], [3, 7, 13], true)
      nearRange.outline = skyline(root.width, 3 * root.px, root.groundY - root.height * 0.015, [0.06, 0.03], [2, 5], false)
      buildPebbles()
    }
    if (!root.started) {
      root.started = true
      root.hiScore = root.host ? Number(root.host.get("hiscore", 0)) || 0 : 0
      newGame()
    }
    if (root.bannerTime > 0) root.bannerTime -= dt
    root.clock += dt
    var frame = Math.floor(root.clock * 10) % 2
    if (frame !== root.wheelFrame) root.wheelFrame = frame

    var c = root.car
    if (c.alive) {
      root.dist += root.speed * dt
      think(dt)
      if (c.h > 0) {
        c.vh -= root.gravity * dt
        c.h += c.vh * dt
        if (c.h <= 0) {
          c.h = 0
          c.vh = 0
          c.bounce = [2 * root.px, 2 * root.px, 2 * root.px]
        }
      }
      // Each wheel rides its own bumps, about three a second at any frame rate.
      for (var w = 0; w < 3; w++) {
        c.bounce[w] *= Math.pow(0.002, dt)
        if (c.h <= 0 && Math.random() < 3.3 * dt) c.bounce[w] = -Util.rand(0, 1.2) * root.px
      }
      // The quattro throws up a rooster tail of moon dust, about 30 puffs a second.
      if (root.rally && c.h <= 0 && root.particles.length < root.maxParticles / 2 && Math.random() < 30 * dt) {
        root.particles.push({
          x: root.buggyX + 4 * root.px, y: root.groundY - root.px,
          vx: -root.speed * Util.rand(0.3, 0.8), vy: -Util.rand(30, 140) * root.unit,
          life: Util.rand(0.3, 0.7), color: root.scene.lip, g: 150
        })
      }

      var rear = root.dist + root.buggyX
      var mid = rear + root.carW / 2
      for (var i = 0; i < root.obstacles.length; i++) {
        var o = root.obstacles[i]
        if (o.kind === "crater" && c.h <= 0 && mid > o.x + 2 * root.px && mid < o.x + o.w - 2 * root.px) { crash(); break }
        if (o.kind === "rock" && o.hp > 0 && c.h < (o.big ? 6 : 5) * root.px
            && o.x < rear + root.carW - root.px && o.x + o.w > rear + root.px) { crash(); break }
      }
    } else {
      c.respawn -= dt
      if (c.respawn <= 0) {
        if (root.lives <= 0) {
          // After newGame(), which would replace it with "POINT A".
          newGame()
          showBanner("GAME OVER", 3)
        } else {
          // Back on the road with a clear stretch ahead.
          var clearTo = root.dist + root.width * 0.7
          root.obstacles = root.obstacles.filter(function(o) { return o.x > clearTo })
          root.bombs = []
          c.alive = true
          c.h = 0
          c.vh = 0
          pointBanner()
        }
      }
    }

    // Only forward: a resize changes pointLength, and must not count a
    // point (or a lap, at A) for going back.
    var reached = Math.floor(root.dist / root.pointLength)
    if (reached > root.point) {
      root.point = reached
      root.score += 500
      if (root.point % 26 === 0) {
        root.lap++
        root.score += 5000
        showBanner("COURSE COMPLETE", 2.5)
      } else {
        pointBanner()
      }
      saveHiScore()
    }
    updateRally()

    spawn()
    root.obstacles = root.obstacles.filter(function(o) { return o.x + o.w > root.dist - 100 * root.unit })

    root.ufoClock -= dt
    if (root.ufoClock <= 0 && root.ufos.length === 0 && !root.flyer && c.alive) {
      launchSky()
      root.ufoClock = root.frantic ? Util.rand(4, 9) : Util.rand(6, 14)
    }
    var keptUfos = []
    for (var u = 0; u < root.ufos.length; u++) {
      var ufo = root.ufos[u]
      ufo.t += dt
      ufo.life -= dt
      ufo.x += ufo.vx * dt
      ufo.y = ufo.baseY + Math.sin(ufo.t * 2.2) * 40 * root.unit
      // They patrol back and forth until their time is up, then leave.
      if (ufo.life > 0 && ufo.x > root.width * 0.85 && ufo.vx > 0) ufo.vx = -ufo.vx
      if (ufo.life > 0 && ufo.x < root.width * 0.05 && ufo.vx < 0) ufo.vx = -ufo.vx
      // The bomb clock waits while the car is down, so a respawn is not met
      // by every saucer dropping at once.
      if (c.alive) ufo.bomb -= dt
      if (ufo.bomb <= 0 && c.alive) {
        // Bombs fall straight down and the car can only shoot straight up
        // from its roof gun, so one landing anywhere else on the car can't
        // be stopped. Saucers mostly hold those until they are past it.
        var dropX = ufo.x + 6 * root.px
        var overCar = dropX > root.buggyX - root.px && dropX < root.buggyX + root.carW + root.px
        if (overCar && Math.abs(dropX - roofGun().x) >= 3 * root.px && !Util.chance(6)) {
          ufo.bomb = (root.carW + 2 * root.px) / Math.max(1, Math.abs(ufo.vx))
        } else {
          root.bombs.push({ x: dropX, y: ufo.y + 6 * root.px, vy: 120 * root.unit })
          ufo.bomb = root.frantic ? Util.rand(0.8, 2) : Util.rand(1.2, 3)
        }
      }
      // Still patrolling (the back of a flight starts further off screen), or
      // not yet gone after leaving.
      if (ufo.life > 0 || (ufo.x > -200 * root.unit && ufo.x < root.width + 200 * root.unit)) keptUfos.push(ufo)
    }
    root.ufos = keptUfos

    if (root.flyer) {
      var fl = root.flyer
      fl.t += dt
      fl.x += fl.vx * dt
      fl.y = fl.baseY + Math.sin(fl.t * 1.6) * 18 * root.unit
      if (fl.x < -fl.w - 10 || fl.x > root.width + 10) root.flyer = null
    }

    var keptBombs = []
    for (var k = 0; k < root.bombs.length; k++) {
      var bomb = root.bombs[k]
      bomb.vy += 500 * root.unit * dt
      bomb.y += bomb.vy * dt
      if (c.alive && bomb.x > root.buggyX && bomb.x < root.buggyX + root.carW
          && bomb.y > root.groundY - (root.rally ? 11 : 10) * root.px - c.h && bomb.y < root.groundY - c.h) {
        crash()
        continue
      }
      if (bomb.y >= root.groundY) {
        explode(bomb.x, root.groundY, 14, 160, "#ffd27a", false)
        // A bomb far enough ahead leaves a crater behind.
        var wx = bomb.x + root.dist
        var room = wx > root.dist + root.buggyX + root.carW + root.reach
        for (var j = 0; room && j < root.obstacles.length; j++)
          if (Math.abs(root.obstacles[j].x - wx) < root.reach * 1.2) room = false
        if (room) insertObstacle({ kind: "crater", x: wx - 24 * root.unit, w: 48 * root.unit, error: 0 })
        continue
      }
      keptBombs.push(bomb)
    }
    root.bombs = keptBombs

    var keptShots = []
    for (var s = 0; s < root.shots.length; s++) {
      var shot = root.shots[s]
      var spent = false
      // Hit tests cover the whole stretch a shot moved this frame, so a slow
      // frame (dt up to 0.05) cannot carry it through a small target.
      if (shot.up) {
        var rise = 800 * root.unit * dt
        shot.y -= rise
        spent = shot.y < -10
        for (var su = 0; !spent && su < root.ufos.length; su++) {
          var uu = root.ufos[su]
          if (shot.x > uu.x && shot.x < uu.x + uu.w && shot.y + rise > uu.y && shot.y < uu.y + 6 * root.px) {
            explode(uu.x + uu.w / 2, uu.y + 3 * root.px, 30, 260, "#ff6a5a", true)
            root.ufos.splice(su, 1)
            root.score += 100
            spent = true
          }
        }
        var fq = root.flyer
        if (!spent && fq && shot.x > fq.x + fq.w * 0.15 && shot.x < fq.x + fq.w * 0.85 && shot.y + rise > fq.y && shot.y < fq.y + fq.hgt) {
          explode(fq.x + fq.w / 2, fq.y + fq.hgt / 2, 50, 280, "#ffd84a", true)
          explode(fq.x + fq.w / 2, fq.y + fq.hgt / 2, 30, 200, "#ffffff", true)
          root.flyer = null
          root.score += 5000
          showBanner("QUATTRO BONUS 5000", 2.5)
          spent = true
        }
        for (var sb = 0; !spent && sb < root.bombs.length; sb++) {
          var bb = root.bombs[sb]
          // The gap closed by the shot and the falling bomb together.
          var gap = shot.y - bb.y
          if (Math.abs(shot.x - bb.x) < 3 * root.px && gap < 4 * root.px && gap + rise + bb.vy * dt > -4 * root.px) {
            explode(bb.x, bb.y, 10, 120, "#ffd27a", true)
            root.bombs.splice(sb, 1)
            root.score += 50
            spent = true
          }
        }
      } else {
        var move = 900 * root.unit * dt
        // How far the shot closed on the rocks: its own move plus the road's.
        var closed = move + (c.alive ? root.speed * dt : 0)
        shot.x += move
        shot.travelled += move
        spent = shot.travelled > root.width * 0.45
        for (var r = 0; !spent && r < root.obstacles.length; r++) {
          var rock = root.obstacles[r]
          if (rock.kind !== "rock" || rock.hp <= 0) continue
          var rx = rock.x - root.dist
          if (shot.x > rx && shot.x - closed < rx + rock.w) {
            rock.hp--
            spent = true
            explode(shot.x, shot.y, 6, 100, root.scene.rock, false)
            if (rock.hp <= 0) {
              explode(rx + rock.w / 2, root.groundY - 3 * root.px, 24, 220, root.scene.rock, false)
              root.score += rock.big ? 200 : 100
            }
          }
        }
      }
      if (!spent) keptShots.push(shot)
    }
    root.shots = keptShots

    var keptParticles = []
    for (var p = 0; p < root.particles.length; p++) {
      var part = root.particles[p]
      part.life -= dt
      if (part.life <= 0) continue
      part.vy += part.g * root.unit * dt
      part.x += part.vx * dt
      part.y += part.vy * dt
      if (part.y > root.groundY) { part.y = root.groundY; part.vy *= -0.3 }
      keptParticles.push(part)
    }
    root.particles = keptParticles

    sync()
  }

  // ------------------------------------------------------------- drawing

  // Everything is painted once and then only moved: the ranges and the
  // road scroll as whole layers, and obstacles keep a pooled item each.

  readonly property int maxCraters: 10
  readonly property int maxRocks: 10
  readonly property int maxShots: 16
  readonly property int maxUfos: 4
  readonly property int maxBombs: 12
  readonly property int maxParticles: preview ? 80 : 220

  readonly property var buggyArt: [
    "...A....................",
    "...A.....PPPPPP.........",
    "...A....PPCCPCCP........",
    ".PPPPPPPPPPPPPPPPPPPP...",
    "PPPPPPPPPPPPPPPPPPPPPPP.",
    "PPLLLLLLLLLLLLLLLLLLLPPP",
    ".DDDDDDDDDDDDDDDDDDDDDD."
  ]
  readonly property var buggyColors: ({ P: "#a855d8", C: "#7ee8ff", L: "#e3a0ff", D: "#4c1d66", A: "#c0c0c8" })
  readonly property var buggyWheel: [
    [".KKK.", "KGWGK", "KWWWK", "KGWGK", ".KKK."],
    [".KKK.", "KWGWK", "KGWGK", "KWGWK", ".KKK."]
  ]

  // The rally quattro side on, nose to the right: flat bonnet, upright glass,
  // boxy arches, a lip spoiler on the boot.
  readonly property var quattroArt: [
    "...........BBBBBBBBBB.........",
    "..........BKKKKKBKKKKKB.......",
    ".S.......BKKKKKKBKKKKKKB......",
    ".SBBBBBBBBBBBBBBBBBBBBBBBBBB..",
    ".BBBBBBBBBBBBBBBBBBBBBBBBBBBBL",
    ".BRRRRRRRRRRRRRRRRRRRRRRRRRRRB",
    ".BBB......BBBBBBBBBB......BBBB",
    "..DD......DDDDDDDDDD......DDD."
  ]
  // Liveries: white works car, tornado red, yellow.
  readonly property var quattroLiveries: [
    { B: "#f2f2ee", K: "#1a2230", R: "#d8262e", S: "#d8262e", D: "#3a3a40", L: "#fff6c0" },
    { B: "#c8202a", K: "#1a2230", R: "#f2f2ee", S: "#1a1a1a", D: "#4a1014", L: "#fff6c0" },
    { B: "#f2c418", K: "#1a2230", R: "#1a1a1a", S: "#1a1a1a", D: "#5a4608", L: "#ffffff" }
  ]
  property int livery: 0
  onRallyChanged: if (rally) livery = Util.randInt(0, quattroLiveries.length - 1)
  readonly property var quattroWheel: [
    [".KKKK.", "KGKKGK", "KKWWKK", "KKWWKK", "KGKKGK", ".KKKK."],
    [".KKKK.", "KKGGKK", "KGWWGK", "KGWWGK", "KKGGKK", ".KKKK."]
  ]
  readonly property var wheelColors: ({ K: "#18181c", G: "#8c8c9a", W: "#e0e0e0" })

  readonly property var smallRockArt: ["..RR..", ".RRRR.", "RRrRRR", "RRRRrR", "RrRRRR"]
  readonly property var bigRockArt: ["...RRR...", "..RRRRR..", ".RRrRRRR.", "RRRRRrRRR", "RRrRRRRRR", "RRRRRRrRR"]
  readonly property var rockColors: ({ R: scene.rock, r: scene.rockDark })
  readonly property var ufoArt: ["....WWWW....", "...WCCCCW...", ".SSSSSSSSSS.", "SSYSSYSSYSSS", ".SSSSSSSSSS.", "...S....S..."]
  readonly property var ufoColors: ({ W: "#f0f0ff", C: "#5ad8ff", S: "#d84a4a", Y: "#ffe14a" })

  // A ridge line that repeats every `period`, drawn twice so it can scroll
  // forever, stepped to the pixel grid. Integer frequencies keep it seamless.
  function skyline(period, colW, base, amps, freqs, jagged) {
    var cols = Math.max(1, Math.round(period / colW))
    var cw = period / cols
    var phases = []
    for (var k = 0; k < amps.length; k++) phases.push(Math.random())
    var heights = []
    for (var c = 0; c < cols; c++) {
      var y = base
      for (var m = 0; m < amps.length; m++) {
        var t = (c / cols * freqs[m] + phases[m]) % 1
        var wave = jagged ? 1 - Math.abs(t * 2 - 1) : 0.5 + 0.5 * Math.sin(t * Math.PI * 2)
        y -= amps[m] * root.height * wave
      }
      heights.push(Math.round(y / root.px) * root.px)
    }
    var bottom = root.groundY + 8
    var out = [Qt.point(-8, bottom)]
    for (var rep = 0; rep < 2; rep++)
      for (var i = 0; i < cols; i++) {
        var x0 = rep * period + i * cw
        out.push(Qt.point(Math.max(-8, x0), heights[i]))
        out.push(Qt.point(x0 + cw, heights[i]))
      }
    out.push(Qt.point(2 * period, bottom))
    out.push(Qt.point(-8, bottom))
    return out
  }

  property var pebbles: []
  function buildPebbles() {
    var list = []
    for (var i = 0; i < (root.preview ? 30 : 70); i++)
      list.push({ x: Math.random() * root.width, y: Util.rand(0.1, 1) * (root.height - root.groundY), w: Util.randInt(1, 4) * root.px })
    root.pebbles = list.concat(list.map(function(p) { return { x: p.x + root.width, y: p.y, w: p.w } }))
  }

  // Each obstacle keeps the pooled item it was given until it goes, so an
  // item is only repainted when it takes a new obstacle.
  function slots(list, max) {
    var used = {}
    for (var i = 0; i < list.length; i++) if (list[i].slot !== undefined) used[list[i].slot] = true
    var next = 0
    var bySlot = {}
    for (var j = 0; j < list.length; j++) {
      var o = list[j]
      if (o.slot === undefined) {
        while (next < max && used[next]) next++
        if (next >= max) continue
        o.slot = next
        used[next] = true
      }
      bySlot[o.slot] = o
    }
    return bySlot
  }

  function sync() {
    farRange.x = -((root.dist * 0.12) % root.width)
    nearRange.x = -((root.dist * 0.3) % root.width)
    groundLayer.x = -(root.dist % root.width)

    var craters = slots(root.obstacles.filter(function(o) { return o.kind === "crater" }), root.maxCraters)
    for (var i = 0; i < root.maxCraters; i++) {
      var ci = craterRepeater.itemAt(i)
      if (!ci) continue
      var cr = craters[i]
      ci.visible = !!cr
      if (cr) { ci.cw = cr.w; ci.x = cr.x - root.dist }
    }
    var rocks = slots(root.obstacles.filter(function(o) { return o.kind === "rock" }), root.maxRocks)
    for (var r = 0; r < root.maxRocks; r++) {
      var ri = rockRepeater.itemAt(r)
      if (!ri) continue
      var rk = rocks[r]
      ri.visible = !!rk && rk.hp > 0
      if (rk) { ri.big = rk.big; ri.x = rk.x - root.dist; ri.y = root.groundY - ri.height }
    }

    var c = root.car
    var settle = (c.bounce[0] + c.bounce[1] + c.bounce[2]) / 3
    vehicle.visible = c.alive
    if (root.rally) {
      quattroBody.y = root.groundY - 11 * root.px - c.h + (c.h > 0 ? 0 : settle)
      for (var q = 0; q < 2; q++) {
        var qw = quattroWheels.itemAt(q)
        if (qw) qw.y = root.groundY - 6 * root.px - c.h + (c.h > 0 ? root.px : c.bounce[q * 2])
      }
    } else {
      buggyBody.y = root.groundY - 10 * root.px - c.h + (c.h > 0 ? 0 : settle)
      for (var w = 0; w < 3; w++) {
        var wheel = buggyWheels.itemAt(w)
        if (wheel) wheel.y = root.groundY - 5 * root.px - c.h + (c.h > 0 ? root.px : c.bounce[w])
      }
    }

    for (var u = 0; u < root.maxUfos; u++) {
      var ui = ufoRepeater.itemAt(u)
      if (!ui) continue
      var ufo = root.ufos[u]
      ui.visible = !!ufo
      if (ufo) { ui.x = ufo.x; ui.y = ufo.y }
    }
    flyerItem.visible = !!root.flyer
    if (root.flyer) {
      flyerItem.pixel = root.flyer.pixel
      flyerItem.livery = root.flyer.livery
      flyerItem.facingLeft = root.flyer.vx < 0
      flyerItem.x = root.flyer.x
      flyerItem.y = root.flyer.y
    }
    for (var k = 0; k < root.maxBombs; k++) {
      var bi = bombRepeater.itemAt(k)
      if (!bi) continue
      var bomb = root.bombs[k]
      bi.visible = !!bomb
      if (bomb) { bi.x = bomb.x - bi.width / 2; bi.y = bomb.y - bi.height / 2 }
    }
    for (var s = 0; s < root.maxShots; s++) {
      var si = shotRepeater.itemAt(s)
      if (!si) continue
      var shot = root.shots[s]
      si.visible = !!shot
      if (shot) {
        si.width = shot.up ? root.px : 3 * root.px
        si.height = shot.up ? 3 * root.px : root.px
        si.x = shot.x
        si.y = shot.y
      }
    }
    for (var p = 0; p < root.maxParticles; p++) {
      var pi = particleRepeater.itemAt(p)
      if (!pi) continue
      var part = root.particles[p]
      if (!part) { if (pi.visible) pi.visible = false; continue }
      pi.x = part.x
      pi.y = part.y
      if (pi.tint !== part.color) pi.tint = part.color
      pi.opacity = Math.min(1, part.life * 2)
      pi.visible = true
    }
  }

  component Range: Shape {
    id: range
    property var outline: []
    property color fill: "white"
    property color rim: "white"
    width: root.width * 2
    height: root.height
    ShapePath {
      fillColor: range.fill
      strokeColor: range.rim
      strokeWidth: root.px
      joinStyle: ShapePath.MiterJoin
      PathPolyline { path: range.outline }
    }
  }

  // A wheel with two pre-painted frames; turning it only flips visibility.
  component Wheel: Item {
    id: wheel
    property var frames: []
    PixelSprite { visible: root.wheelFrame === 0; rows: wheel.frames[0] || []; colors: root.wheelColors; pixel: root.px }
    PixelSprite { visible: root.wheelFrame === 1; rows: wheel.frames[1] || []; colors: root.wheelColors; pixel: root.px }
  }

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0; color: root.scene.skyTop }
      GradientStop { position: 0.75; color: root.scene.skyLow }
    }
  }

  Repeater {
    model: root.preview ? 40 : 90
    Rectangle {
      x: Math.random() * root.width
      y: Math.random() * root.groundY * 0.6
      width: (Math.random() < 0.2 ? 4 : 2) * root.unit
      height: width
      color: root.scene.star
      opacity: Util.rand(0.3, 0.9)
    }
  }

  Quattro {
    id: flyerItem
    visible: false
  }

  Range { id: farRange; fill: root.scene.far; rim: root.scene.farRim }
  Range { id: nearRange; fill: root.scene.near; rim: root.scene.nearRim }

  Repeater {
    id: ufoRepeater
    model: root.maxUfos
    PixelSprite { visible: false; rows: root.ufoArt; colors: root.ufoColors; pixel: root.px }
  }

  Repeater {
    id: bombRepeater
    model: root.maxBombs
    Rectangle { visible: false; width: 2 * root.px; height: 3 * root.px; radius: root.px; color: "#ffd27a" }
  }

  // The road: the regolith, a lip, and pebbles scrolling with it.
  Rectangle {
    y: root.groundY
    width: root.width
    height: root.height - root.groundY
    color: root.scene.ground
  }
  Rectangle { y: root.groundY; width: root.width; height: root.px; color: root.scene.lip }
  Item {
    id: groundLayer
    y: root.groundY
    width: root.width * 2
    Repeater {
      model: root.pebbles
      Rectangle { x: modelData.x; y: modelData.y; width: modelData.w; height: root.px; color: root.scene.pebble }
    }
  }

  Repeater {
    id: craterRepeater
    model: root.maxCraters
    Item {
      id: crater
      property real cw: 40
      visible: false
      y: root.groundY
      Shape {
        ShapePath {
          fillColor: root.scene.pit
          strokeColor: root.scene.pitRim
          strokeWidth: root.px
          PathPolyline {
            path: [Qt.point(0, -1), Qt.point(crater.cw, -1), Qt.point(crater.cw - 3 * root.px, 7 * root.px),
              Qt.point(3 * root.px, 7 * root.px), Qt.point(0, -1)]
          }
        }
      }
    }
  }

  Repeater {
    id: rockRepeater
    model: root.maxRocks
    PixelSprite {
      property bool big: false
      visible: false
      rows: big ? root.bigRockArt : root.smallRockArt
      colors: root.rockColors
      pixel: root.px
    }
  }

  Item {
    id: vehicle
    x: root.buggyX
    Item {
      visible: !root.rally
      Repeater {
        id: buggyWheels
        model: 3
        Wheel { x: [1, 9.5, 18][index] * root.px; frames: root.buggyWheel }
      }
      PixelSprite { id: buggyBody; rows: root.buggyArt; colors: root.buggyColors; pixel: root.px }
    }
    Item {
      visible: root.rally
      Repeater {
        id: quattroWheels
        model: 2
        Wheel { x: [4, 20][index] * root.px; frames: root.quattroWheel }
      }
      PixelSprite { id: quattroBody; rows: root.quattroArt; colors: root.quattroLiveries[root.livery]; pixel: root.px }
    }
  }

  Repeater {
    id: shotRepeater
    model: root.maxShots
    Rectangle { visible: false; color: "#fff4b0" }
  }

  Repeater {
    id: particleRepeater
    model: root.maxParticles
    Rectangle {
      property string tint: "#ffffff"
      visible: false
      width: root.px
      height: root.px
      color: tint
    }
  }

  // ---------------------------------------------------------------- HUD

  PixelText {
    x: 28 * root.unit
    y: 28 * root.unit
    text: Util.pad(root.score, 6, "0")
    color: root.scene.hud
    pixel: 6 * root.unit
  }

  PixelText {
    anchors.right: parent.right
    anchors.rightMargin: 28 * root.unit
    y: 28 * root.unit
    text: "HI " + Util.pad(Math.max(root.hiScore, root.score), 6, "0")
    color: root.scene.hud
    opacity: 0.6
    pixel: 4 * root.unit
  }

  // Progress along the course, A to Z, the way the cabinet showed it.
  Item {
    id: course
    anchors.horizontalCenter: parent.horizontalCenter
    y: 30 * root.unit
    width: root.width * 0.36
    height: 24 * root.unit
    readonly property real progress: ((root.dist / root.pointLength) % 26) / 26
    Rectangle { y: 10 * root.unit; width: parent.width; height: 2 * root.unit; color: root.scene.course; opacity: 0.6 }
    Repeater {
      model: ["A", "E", "J", "O", "T", "Z"]
      PixelText {
        // Each point is 1/26 of the bar, the scale `progress` uses.
        x: root.letters.indexOf(modelData) / 26 * course.width - width / 2
        y: 16 * root.unit
        text: modelData
        color: root.scene.course
        pixel: 2.5 * root.unit
      }
    }
    Rectangle {
      x: course.progress * course.width - width / 2
      y: 4 * root.unit
      width: 6 * root.unit
      height: 14 * root.unit
      color: root.scene.banner
    }
  }

  Row {
    x: 28 * root.unit
    y: 72 * root.unit
    spacing: 10 * root.unit
    Repeater {
      model: Math.max(0, root.lives)
      PixelSprite { rows: root.buggyArt; colors: root.buggyColors; pixel: 1.5 * root.unit }
    }
  }

  PixelText {
    anchors.horizontalCenter: parent.horizontalCenter
    y: root.height * 0.42
    visible: root.bannerTime > 0
    opacity: Math.min(1, root.bannerTime * 2)
    text: root.banner
    color: root.scene.banner
    pixel: 8 * root.unit
  }

  FrameAnimation {
    running: root.running && root.visible
    onTriggered: root.step(Math.min(frameTime, 0.05))
  }
}
