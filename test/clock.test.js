// Run with: node --test test/
const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const M = require("../Model.js")

const read = (f) => fs.readFileSync(path.join(__dirname, "..", f), "utf8")
const barWidget = read("BarWidget.qml")
const panel = read("Panel.qml")
const manifest = JSON.parse(read("manifest.json"))

// ---- Model.applyShowDate: the date mask

test("default fork format masks to day name + time", () => {
  assert.equal(M.applyShowDate("dddd MMM d h:mm AP", false), "dddd h:mm AP")
})

test("showDate true leaves the format untouched", () => {
  assert.equal(M.applyShowDate("dddd MMM d h:mm AP", true), "dddd MMM d h:mm AP")
  assert.equal(M.applyShowDate("dddd MMM d h:mm AP", null), "dddd MMM d h:mm AP")
})

test("string \"false\" masks too — that is what omarchy bar set writes", () => {
  assert.equal(M.applyShowDate("dddd MMM d h:mm AP", "false"), "dddd h:mm AP")
})

test("every preset ring format masks to something sane", () => {
  const cases = {
    "dddd HH:mm": "dddd HH:mm",            // no date to hide
    "dddd h:mm AP": "dddd h:mm AP",
    "HH:mm": "HH:mm",
    "h:mm AP": "h:mm AP",
    "ddd d MMM HH:mm": "ddd HH:mm",
    "ddd d MMM h:mm AP": "ddd h:mm AP",
    "yyyy-MM-dd HH:mm": "HH:mm",           // one word, dropped whole
    "d MMMM 'W'ww yyyy": "d MMMM 'W'ww yyyy" // nothing but date: unchanged
  }
  for (const format in cases)
    assert.equal(M.applyShowDate(format, false), cases[format], format)
})

test("vertical formats keep their all-date lines rather than going empty", () => {
  const vertical = "dd\nMMM\n'W'ww\n''yy"
  assert.equal(M.applyShowDate(vertical, false), vertical)
})

test("mixed vertical line masks; time-only line untouched", () => {
  assert.equal(M.applyShowDate("ddd d\nHH:mm", false), "ddd\nHH:mm")
})

test("masking is idempotent", () => {
  const once = M.applyShowDate("dddd MMM d h:mm AP", false)
  assert.equal(M.applyShowDate(once, false), once)
})

// ---- Wiring: the mask is actually wired into the widget and the panel

test("BarWidget defaults to the date-inclusive format and masks via Model", () => {
  assert.match(barWidget, /setting\("format", "dddd MMM d h:mm AP"\)/)
  assert.match(barWidget, /activeFormat: Model\.applyShowDate\(configuredFormat, showDate\)/)
})

test("BarWidget reads showDate tolerating the string form", () => {
  assert.match(barWidget, /setting\("showDate", null\)/)
  assert.match(barWidget, /value === false \|\| value === "false"/)
})

test("Panel defines the toggle and writes it through persistSettings", () => {
  assert.match(panel, /function toggleShowDate\(\)/)
  assert.match(panel, /persistSettings\(\{ showDate: !root\.showDate \}\)/)
  assert.match(panel, /onClicked: root\.toggleShowDate\(\)/)
  assert.match(panel, /root\.showDate \? "ON" : "OFF"/)
})

test("rebrand is complete — no omarchy.clock left behind", () => {
  for (const f of ["BarWidget.qml", "Panel.qml", "Model.js", "manifest.json"])
    assert.doesNotMatch(read(f), /omarchy\.clock/, f)
})

test("manifest carries the fork identity", () => {
  assert.equal(manifest.id, "gdeyoung.clock")
  assert.equal(manifest.author, "gdeyoung")
  assert.deepEqual(manifest.kinds, ["bar-widget"])
  assert.equal(manifest.entryPoints.barWidget, "BarWidget.qml")
})
