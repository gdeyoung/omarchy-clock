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
  assert.equal(manifest.id, "gdeyoung.timepiece")
  assert.equal(manifest.author, "gdeyoung")
  assert.deepEqual(manifest.kinds, ["bar-widget"])
  assert.equal(manifest.entryPoints.barWidget, "BarWidget.qml")
})

// ---- World clock parsing and zone labels

test("parseWorldClocks parses label:zone pairs, comma separated", () => {
  assert.deepEqual(M.parseWorldClocks("ET:America/New_York, PT:America/Los_Angeles"), [
    { label: "ET", zone: "America/New_York" },
    { label: "PT", zone: "America/Los_Angeles" }
  ])
})

test("parseWorldClocks drops bad zones, empty pieces, and caps at four", () => {
  assert.deepEqual(M.parseWorldClocks("ET:Not/AZone,PT:America/Los_Angeles"), [
    { label: "PT", zone: "America/Los_Angeles" }
  ])
  assert.equal(M.parseWorldClocks("").length, 0)
  assert.equal(M.parseWorldClocks(null).length, 0)
  assert.equal(M.parseWorldClocks("A:UTC,B:UTC,C:UTC,D:UTC,E:UTC").length, 4)
  assert.equal(M.parseWorldClocks("nolabel:America/New_York").length, 0)
})

test("zoneTimeLabel returns h:mm AM/PM for a valid zone, empty for a bad one", () => {
  const d = new Date(2026, 9, 18, 16, 22, 0) // local time; zone output varies but shape holds
  assert.match(M.zoneTimeLabel("America/New_York", d), /^\d{1,2}:\d{2}\u202f?(AM|PM)$|^\d{1,2}:\d{2} (AM|PM)$/)
  assert.equal(M.zoneTimeLabel("Not/AZone", d), "")
})

// ---- Countdown timer math

test("formatCountdown renders mm:ss and clamps at zero", () => {
  assert.equal(M.formatCountdown(0), "00:00")
  assert.equal(M.formatCountdown(-5000), "00:00")
  assert.equal(M.formatCountdown(594000), "09:54")
  assert.equal(M.formatCountdown(3723000), "62:03") // long runs keep counting past an hour
})

test("stepTimerMinutes clamps to 1..600 and tolerates junk", () => {
  assert.equal(M.stepTimerMinutes(10, 5), 15)
  assert.equal(M.stepTimerMinutes(3, -5), 1)
  assert.equal(M.stepTimerMinutes(598, 5), 600)
  assert.equal(M.stepTimerMinutes("10", 5), 15)
})

// ---- Wiring: zones row + timer are actually wired

test("Panel reads worldClocks through Model and renders zone times via date", () => {
  assert.match(panel, /Model\.parseWorldClocks\(setting\("worldClocks", ""\)\)/)
  assert.match(panel, /command: \["date", "\+%-%I:%M %p"\]/)
  assert.match(panel, /environment: \(\{ "TZ": zoneDelegate\.modelData\.zone \}\)/)
  assert.match(panel, /\^\[0-9\]\{1,2\}:\[0-9\]\{2\} \(AM\|PM\)\$/) // output validated before display
})

test("Panel owns the timer actions and writes exact keys", () => {
  assert.match(panel, /function timerStep\(delta\)/)
  assert.match(panel, /function timerToggle\(\)/)
  assert.match(panel, /function timerReset\(\)/)
  assert.match(panel, /timerRunning: true/)
  assert.match(panel, /timerEndsAt: Date\.now\(\) \+ remaining/)
  assert.match(panel, /timerDoneAt: now/)
})

test("Panel's fire watcher flips running off and retires the ping", () => {
  assert.match(panel, /now >= root\.timerEndsAt/)
  assert.match(panel, /now - root\.timerDoneAt >= 120000/)
  assert.match(panel, /persistSettings\(\{ timerDoneAt: 0 \}\)/)
})

test("BarWidget carries the countdown in the label and tolerates string state", () => {
  assert.match(barWidget, /text: root\.vertical \? "" : \(root\.displayText \+ root\.timerSuffix\)/)
  assert.match(barWidget, /Model\.formatCountdown\(timerRemainingMs\)/)
  assert.match(barWidget, /setting\("timerRunning", null\)/)
  assert.match(barWidget, /value === true \|\| value === "true"/)
})

test("version moved to 0.2.0 with the feature set named", () => {
  assert.equal(manifest.version, "0.2.0")
  assert.match(manifest.description, /world-clock/)
  assert.match(manifest.description, /countdown timer/)
})
