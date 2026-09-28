.pragma library

// Small helpers every part of After Dark shares. Nothing here touches the
// shell, so screensavers and the headless snapshot harness can import it too.

// The categories Random mode chooses between, in the order the control panel
// lists them.
var categories = [
  { id: "omarchy", label: "Omarchy" },
  { id: "arcade", label: "Arcade" },
  { id: "retro", label: "Retro" },
  { id: "system", label: "System" },
  { id: "weird", label: "Weird" },
  { id: "calm", label: "Calm" },
  { id: "chaotic", label: "Chaotic" }
]

function isCategory(id) {
  for (var i = 0; i < categories.length; i++)
    if (categories[i].id === id) return true
  return false
}

function clamp(value, lo, hi) {
  return value < lo ? lo : (value > hi ? hi : value)
}

function lerp(a, b, t) {
  return a + (b - a) * t
}

function rand(lo, hi) {
  return lo + Math.random() * (hi - lo)
}

function randInt(lo, hi) {
  return Math.floor(lo + Math.random() * (hi - lo + 1))
}

function pick(list) {
  return list.length ? list[Math.floor(Math.random() * list.length)] : undefined
}

function chance(oneIn) {
  return Math.random() * Math.max(1, oneIn) < 1
}

// Weighted pick over [{ weight, value }].
function weighted(entries) {
  var total = 0
  for (var i = 0; i < entries.length; i++) total += Math.max(0, entries[i].weight)
  if (total <= 0) return undefined
  var roll = Math.random() * total
  for (var j = 0; j < entries.length; j++) {
    roll -= Math.max(0, entries[j].weight)
    if (roll < 0) return entries[j].value
  }
  return entries[entries.length - 1].value
}

// Text that reaches the screen from outside the plugin (process names,
// journal identifiers, a community module's name) is cleaned first:
// invisible formatting characters are deleted, control characters and line
// separators become spaces, whitespace collapses, and the result is cut to
// `limit` characters without splitting a surrogate pair.
// Built from strings: QML's lexer turns a \u2028 escape inside a regex
// literal into a real line break, which ends the literal early.
var invisibleChars = new RegExp("[\\u00ad\\u061c\\u180e\\u200b-\\u200f\\u202a-\\u202e\\u2060-\\u206f\\ufe00-\\ufe0f\\ufeff\\ufff9-\\ufffb]", "g")
var controlChars = new RegExp("[\\u0000-\\u001f\\u007f-\\u009f\\u2028\\u2029]", "g")

function cleanText(value, limit) {
  if (typeof value !== "string") return ""
  var max = limit > 0 ? limit : 120
  var text = value
    .replace(invisibleChars, "")
    .replace(controlChars, " ")
    .replace(/\s+/g, " ")
    .trim()
  var chars = Array.from(text)
  if (chars.length <= max) return text
  return chars.slice(0, Math.max(1, max - 1)).join("").trim() + "…"
}

// A remote address shown on an idle screen keeps only its network half, so
// a passer-by reads "203.0.x.x" rather than who this machine talks to.
function maskAddress(address) {
  var text = String(address || "")
  var v4 = /^(\d{1,3})\.(\d{1,3})\.\d{1,3}\.\d{1,3}$/.exec(text)
  if (v4) return v4[1] + "." + v4[2] + ".x.x"
  if (text.indexOf(":") !== -1) {
    var parts = text.replace(/^\[|\]$/g, "").split(":").filter(function(p) { return p.length > 0 })
    return parts.slice(0, 2).join(":") + ":…"
  }
  return text
}

function formatThousands(n) {
  var s = String(Math.max(0, Math.floor(Number(n) || 0)))
  return s.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
}

function formatDuration(seconds) {
  var s = Math.max(0, Math.floor(seconds))
  var d = Math.floor(s / 86400)
  var h = Math.floor((s % 86400) / 3600)
  var m = Math.floor((s % 3600) / 60)
  if (d > 0) return d + "d " + h + "h"
  if (h > 0) return h + "h " + m + "m"
  return m + "m " + (s % 60) + "s"
}

function pad(value, width, ch) {
  var s = String(value)
  while (s.length < width) s = (ch || " ") + s
  return s
}
