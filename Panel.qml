import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model
import "zones.js" as Zones

// The clock's calendar popup: a month grid with ISO week numbers, built to
// sit beside the weather panel — same hero-over-detail composition, same
// spacing scale, same small-caps labels.
//
// The grid is a read-out rather than a picker: today is the only marked
// day, and the only thing that moves is which month is on screen —
// chevrons, the scroll wheel, and the arrow keys all step it.
//
// BarWidget.qml owns the bar label and hands this panel the button to
// anchor against.
Panel {
  id: root
  moduleName: "gdeyoung.timepiece"
  ipcTarget: "gdeyoung.timepiece"
  manageIpc: false

  property var anchorItem: null

  // The bar tracks the widget mounted in its slot — BarWidget.qml — not this
  // nested panel. Everything the bar identifies a panel by has to be that
  // widget: the popout coordinator (and with it the open-panel dot under the
  // pill) compares against `slot.activeItem`, and switchPanelFrom looks the
  // slot up the same way.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // ---- Today. SystemClock keeps this honest across midnight so the
  //      highlight rolls over without the panel being reopened.
  property date today: new Date()
  readonly property string todayKey: Model.keyForDate(today)

  // The month on screen. Stepping moves this and nothing else: the grid is
  // a read-out, not a picker, so there is no per-day cursor to keep in sync.
  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()

  // Local noon, so a first of the month with no midnight (Havana, April 2012)
  // still names its own month; UTC would name the previous one west of Greenwich.
  readonly property date viewDate: new Date(viewYear, viewMonth, 1, 12)
  readonly property bool viewingCurrentMonth: viewYear === today.getFullYear() && viewMonth === today.getMonth()

  // Pinned to today, not to the month being browsed — stepping through the
  // calendar does not change how much of the year is gone.
  readonly property real yearDone: Model.yearProgress(today.getFullYear(), today.getMonth(), today.getDate())
  readonly property int yearDonePercent: Model.yearProgressPercent(today.getFullYear(), today.getMonth(), today.getDate())

  // Memento mori, for anyone who goes looking: double-tapping the year bar
  // asks for a birth year and a life expectancy, and a second bar tracks one
  // against the other. A birth year rather than an age, so it keeps counting
  // on its own. Without one the bar stays hidden.
  readonly property int birthYear: Model.parseBirthYear(setting("birthYear", 0), today.getFullYear())
  readonly property int age: Model.ageFromBirthYear(birthYear, today.getFullYear())
  readonly property int lifeExpectancy: Model.parseLifeExpectancy(setting("lifeExpectancy", 0))
  readonly property real lifeDone: Model.lifeProgress(age, lifeExpectancy)
  readonly property int lifeDonePercent: Model.lifeProgressPercent(age, lifeExpectancy)
  property bool editingLife: false

  // Unset falls through to the locale's own first day, so a fresh install
  // starts out matching the rest of the desktop rather than a hardcoded
  // convention. Clicking the grid's "W" heading writes the choice back to
  // shell.json.
  readonly property int weekStart: Model.normalizedWeekStart(setting("weekStartDay", null), Qt.locale().firstDayOfWeek)

  // The date beside the time in the bar label — masked by the host widget,
  // toggled here. Reads the same shell.json entry the bar pushes live, and
  // accepts the string "false" as false (that is what `omarchy bar set`
  // writes for a bare value).
  readonly property bool showDate: {
    var value = setting("showDate", null)
    return !(value === false || value === "false")
  }

  function toggleShowDate() {
    persistSettings({ showDate: !root.showDate })
  }

  // ---- World clock row: labeled times in other zones, only when configured.
  //      Setting shape and validation live in Model.parseWorldClocks. The
  //      gear at the popup's top-right opens the settings view, where zones
  //      are chosen — the row itself is a read-out.
  readonly property var worldClocks: Model.parseWorldClocks(setting("worldClocks", ""))

  property bool settingsOpen: false

  function zonesAdd(zone) {
    // zone is a full tz name ("America/New_York", "UTC"); the label is the
    // city part with underscores as spaces. Idempotent, capped at five —
    // writes go through zonesToString so the stored shape never drifts.
    var current = Model.parseWorldClocks(String(setting("worldClocks", "") || ""))
    for (var i = 0; i < current.length; i++) {
      if (current[i].zone === zone) return
    }
    if (current.length >= 5) return
    var parts = zone.split("/")
    var city = parts[parts.length - 1]
    current.push({ label: city === "UTC" ? "UTC" : city.replace(/_/g, " "), zone: zone })
    persistSettings({ worldClocks: Model.zonesToString(current) })
  }

  function zonesRemove(zone) {
    var current = Model.parseWorldClocks(String(setting("worldClocks", "") || ""))
    var kept = []
    for (var i = 0; i < current.length; i++) {
      if (current[i].zone !== zone) kept.push(current[i])
    }
    persistSettings({ worldClocks: Model.zonesToString(kept) })
  }

  // ---- Countdown timer. The panel owns the controls; state persists in the
  //      widget entry so a run survives shell restarts. The bar label shows
  //      the remaining time while running and a "done" ping for two minutes
  //      after the fire — aging that ping out is this panel's job, since the
  //      bar only reads.
  readonly property real timerEndsAt: Number(setting("timerEndsAt", 0)) || 0
  readonly property real timerRemainingMs: Number(setting("timerRemainingMs", 0)) || 0
  readonly property real timerDoneAt: Number(setting("timerDoneAt", 0)) || 0
  readonly property bool timerRunning: {
    var value = setting("timerRunning", null)
    return value === true || value === "true"
  }
  readonly property int timerMinutes: {
    var value = Number(setting("timerMinutes", 10))
    return (value >= 1 && value <= 600) ? Math.round(value) : 10
  }
  property date timerNow: new Date()

  readonly property real timerDisplayMs: timerRunning
    ? Math.max(0, timerEndsAt - timerNow.getTime())
    : (timerDoneAt > 0 ? 0 : timerRemainingMs)

  function timerStep(delta) {
    if (root.timerRunning || root.timerDoneAt > 0) return
    persistSettings({ timerMinutes: Model.stepTimerMinutes(root.timerMinutes, delta), timerRemainingMs: 0 })
  }

  function timerToggle() {
    if (root.timerRunning) {
      persistSettings({
        timerRunning: false,
        timerRemainingMs: Math.max(0, root.timerEndsAt - Date.now()),
        timerDoneAt: 0
      })
    } else {
      if (root.timerDoneAt > 0) { root.timerReset(); return }
      if (root.pomodoroActive) { root.pomodoroStop() } // modes are exclusive
      var remaining = root.timerRemainingMs > 0 ? root.timerRemainingMs : root.timerMinutes * 60000
      if (remaining <= 0) return
      persistSettings({
        timerRunning: true,
        timerEndsAt: Date.now() + remaining,
        timerDoneAt: 0
      })
    }
  }

  function timerReset() {
    persistSettings({ timerRunning: false, timerRemainingMs: 0, timerDoneAt: 0 })
  }

  // ---- Pomodoro: the self-running mode. Shares the timer row but not the
  //      state — starting either mode clears the other so the bar suffix and
  //      the readout always have exactly one owner. Phase transitions are
  //      computed by Model.nextPomodoroPhase; the watcher below fires them.
  readonly property string pomodoroMode: {
    var value = setting("pomodoroMode", "off")
    return (value === "focus" || value === "break" || value === "longbreak") ? value : "off"
  }
  readonly property real pomodoroEndsAt: Number(setting("pomodoroEndsAt", 0)) || 0
  readonly property int pomodoroCyclesDone: Number(setting("pomodoroCyclesDone", 0)) || 0
  readonly property int pomodoroFocusMin: Model.clampPomodoroMinutes(setting("pomodoroFocusMin", 25), 25, 1, 120)
  readonly property int pomodoroBreakMin: Model.clampPomodoroMinutes(setting("pomodoroBreakMin", 5), 5, 1, 60)
  readonly property bool pomodoroActive: pomodoroMode !== "off"

  // In-memory mode tab for the timer section's idle state. NEVER persisted:
  // config does not migrate back into the read-only popup.
  property string timerTab: "manual"

  // Categorical identity hues for the world-clock labels ( Gestalt
  // similarity: stable arbitrary marks, one per slot). Deliberately no
  // green/violet, so zones never masquerade as pomodoro phases.
  property var tzHues: ["#7dcfff", "#e0af68", "#f7768e", "#7aa2f7", "#ff9e64"]

  function pomodoroStart() {
    persistSettings({
      timerRunning: false, timerRemainingMs: 0, timerDoneAt: 0,
      pomodoroMode: "focus",
      pomodoroEndsAt: Date.now() + pomodoroFocusMin * 60000,
      pomodoroCyclesDone: 0
    })
  }

  // SKIP: apply the next phase now. The natural fire path lives in the bar
  // widget (mounted all session); this is the manual, popup-open path.
  function pomodoroAdvance() {
    var next = Model.nextPomodoroPhase(root.pomodoroMode, root.pomodoroCyclesDone, root.pomodoroFocusMin, root.pomodoroBreakMin)
    if (!next) { root.pomodoroStop(); return }
    persistSettings({
      pomodoroMode: next.mode,
      pomodoroEndsAt: Date.now() + next.minutes * 60000,
      pomodoroCyclesDone: next.cyclesDone
    })
  }

  function pomodoroStop() {
    persistSettings({ pomodoroMode: "off", pomodoroEndsAt: 0 })
  }

  function pomodoroStep(delta, which) {
    // V4-safe: no computed object keys — write the one key explicitly.
    var lo = 1
    var hi = which === "break" ? 60 : 120
    var current = which === "break" ? root.pomodoroBreakMin : root.pomodoroFocusMin
    var value = Math.max(lo, Math.min(hi, current + delta))
    if (which === "break") persistSettings({ pomodoroBreakMin: value })
    else persistSettings({ pomodoroFocusMin: value })
  }

  // The fire itself: flips running off and stamps the ping. 250 ms while a
  // run is live is cheap and makes the flip snappy; it also retires the
  // "done" ping two minutes later so the bar cleans itself up.
  Timer {
    interval: 250
    running: root.timerRunning || root.timerDoneAt > 0 || root.pomodoroActive
    repeat: true
    // Fires (pomodoro flips, the manual timer's done, the ping aging) are
    // owned by the BAR widget, which is mounted all session — this panel
    // exists only while open. This timer just keeps the readout ticking.
    onTriggered: root.timerNow = new Date()
  }

  // The interface is English throughout, so day names are not taken from the
  // system locale. Where the week starts still is: that is a regional
  // convention rather than a translation, and it stays overridable above.
  readonly property var labelLocale: Qt.locale("en_US")
  readonly property string nextWeekStartLabel: labelLocale.dayName(Model.toggledWeekStart(weekStart), Locale.LongFormat)
  readonly property var weekdays: Model.weekdayOrder(weekStart)
  readonly property var weeks: Model.monthGrid(viewYear, viewMonth, weekStart, todayKey)


  // Guarded so the widget renders before the bar is injected (the bar-widget
  // contract instantiates it bare).
  readonly property color contentForeground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property int cellWidth: Style.space(52)
  readonly property int cellHeight: Style.space(34)
  readonly property int cellSpacing: Style.space(2)
  readonly property int weekColumnWidth: Style.space(32)
  readonly property int gutterWidth: Style.space(14)

  function open() {
    refresh()
    root.controller.show()
    // Set after showing, not before: showing hands the popout coordinator
    // over, which closes whichever panel was open, and that close clears the
    // shared flag. Deferring means the panel taking over always wins, while
    // a handoff to a panel that does not manage the flag still leaves it
    // cleared rather than stuck on.
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    // Dismissing the panel mid-edit would otherwise leave the inputs up,
    // waiting behind a closed popup for the next time it opens.
    if (root.editingLife) root.cancelEditingLife()
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // Summoning by hotkey moves no pointer, so a hover the bar was still
  // holding must not keep the center indicators revealed behind the panel.
  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
    else if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function refresh() {
    root.today = new Date()
    root.goToToday()
  }

  function goToToday() {
    root.viewYear = today.getFullYear()
    root.viewMonth = today.getMonth()
  }

  function moveMonth(delta) {
    var next = Model.stepMonth(viewYear, viewMonth, delta)
    root.viewYear = next.year
    root.viewMonth = next.month
  }

  function moveYear(delta) {
    moveMonth(delta * 12)
  }

  // Applied locally first so the panel redraws on the click itself; the
  // shell.json write comes back through the bar as the same value. With no
  // writable entry (the widget is not in the layout) it stays a session-only
  // preference rather than doing nothing. The host widget builds its own
  // entry when the label format is cycled, so it has to be kept in step or
  // it would write this key straight back out from a stale copy.
  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setWeekStart(day) {
    var next = Model.normalizedWeekStart(day, root.weekStart)
    if (next === root.weekStart) return
    persistSettings({ weekStartDay: Model.weekStartSettingName(next) })
  }

  function startEditingLife() {
    root.editingLife = true
    Qt.callLater(function() {
      bornField.text = root.birthYear > 0 ? String(root.birthYear) : ""
      expectancyField.text = String(root.lifeExpectancy)
      bornField.selectAll()
      bornField.forceActiveFocus()
    })
  }

  function cancelEditingLife() {
    root.editingLife = false
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  // Shared by both fields: Tab hops to the other one, Enter commits the pair,
  // Escape drops the lot.
  function handleLifeKey(event, other) {
    if (event.key === Qt.Key_Escape) {
      root.cancelEditingLife()
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.commitLife()
      event.accepted = true
    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      other.selectAll()
      other.forceActiveFocus()
      event.accepted = true
    }
  }

  // Double-tapping the life bar puts it away again. The expectancy stays in
  // the config so setting a birth year again brings your own number back
  // rather than the default.
  function clearLife() {
    if (root.birthYear <= 0) return
    persistSettings({ birthYear: 0 })
  }

  function commitLife() {
    var born = Model.parseBirthYear(bornField.text, today.getFullYear())
    var span = Model.parseLifeExpectancy(expectancyField.text)
    if (born !== root.birthYear || span !== root.lifeExpectancy)
      persistSettings({ birthYear: born, lifeExpectancy: span })
    cancelEditingLife()
  }

  function toggleWeekStart() {
    setWeekStart(Model.toggledWeekStart(root.weekStart))
  }

  // English short day names, matching the rest of the interface.
  function weekdayLabel(weekday) {
    return String(labelLocale.dayName(weekday, Locale.ShortFormat)).toUpperCase()
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: {
      if (Model.keyForDate(clock.date) === String(root.todayKey)) return
      var followToday = root.viewingCurrentMonth
      root.today = clock.date
      if (followToday) root.goToToday()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.fittedContentHeight(root.settingsOpen ? settingsView.implicitHeight : calendarColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editingLife || root.settingsOpen
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.moveMonth(dx)
        if (dy !== 0) root.moveYear(dy)
      }
      onActivateRequested: root.goToToday()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "[") root.moveMonth(-1)
        else if (t === "]") root.moveMonth(1)
        else if (t === "{") root.moveYear(-1)
        else if (t === "}") root.moveYear(1)
        else if (t === "t" || t === "T") root.goToToday()
        else if (t === "w" || t === "W") root.toggleWeekStart()
      }

      Flickable {
        id: calendarScroll
        anchors.fill: parent
        visible: !root.settingsOpen
        contentWidth: calendarColumn.width
        contentHeight: calendarColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height || contentWidth > width

        Column {
          id: calendarColumn
          // Never narrower than the grid. The popup width is capped to what
          // the screen allows, and a fixed seven-column grid would otherwise
          // lose its last days off the edge instead of scrolling.
          width: Math.max(calendarScroll.width, gridColumn.width)
          spacing: Style.space(8)

          // ---- Hero: today, centered. Once the view has stepped back
          //      it is also the way home — clicking the date you are
          //      looking for beats hunting for a reset button.
          Item {
            width: parent.width
            height: heroRow.height

            Row {
              id: heroRow
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(22)

              Text {
                // Baseline-aligned, not center-aligned: "July 26" carries a
                // descender, so centering the two boxes leaves the icon
                // sitting visibly low against the digits.
                anchors.baseline: heroDate.baseline
                text: "󰃭"
                color: heroMouse.containsMouse
                  ? Style.hoverStateColor(root.contentForeground, Commons.Color.accent)
                  : root.contentForeground
                font.family: root.contentFontFamily
                // Decorative, and deliberately outside the Style.font.*
                // scale. Sized so the glyph reads at the cap height of the
                // date beside it rather than towering over it.
                font.pixelSize: 48
              }

              Text {
                id: heroDate
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(root.today, "MMMM d")
                color: heroMouse.containsMouse
                  ? Style.hoverStateColor(root.contentForeground, Commons.Color.accent)
                  : root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: 52
                font.bold: true
              }
            }

            MouseArea {
              id: heroMouse
              x: heroRow.x
              y: heroRow.y
              width: heroRow.width
              height: heroRow.height
              enabled: !root.viewingCurrentMonth
              hoverEnabled: enabled
              cursorShape: Qt.PointingHandCursor
              onClicked: root.goToToday()

              PanelToolTip {
                visible: heroMouse.containsMouse
                text: "Back to today"
                fontFamily: root.contentFontFamily
              }
            }
          }

          // ---- World clock row: labeled times in other zones, under the
          //      local date they convert from. Hidden entirely when unset.
          //      The QML engine has no Intl/timezone support, so each zone
          //      is one read-only `date` call a minute — the only external
          //      command the plugin runs, and its output is validated
          //      against the h:mm AM/PM shape before it is shown.
          Item {
            width: parent.width
            height: visible ? zonesRow.height : 0
            visible: root.worldClocks.length > 0

            Flow {
              id: zonesRow
              width: parent.width
              spacing: Style.space(18)

              Repeater {
                model: root.worldClocks

                Row {
                  id: zoneDelegate
                  required property var modelData
                  property string zoneTime: ""
                  property date minuteTick: clock.date
                  spacing: Style.space(7)

                  function refreshZone() {
                    if (zoneProc.running) zoneProc.running = false
                    zoneProc.running = true
                  }

                  Component.onCompleted: refreshZone()
                  onMinuteTickChanged: refreshZone()

                  Process {
                    id: zoneProc
                    command: ["date", "+%-I:%M %p"]
                    environment: ({ "TZ": zoneDelegate.modelData.zone })
                    stdout: StdioCollector {
                      waitForEnd: true
                      onStreamFinished: {
                        var t = String(text).replace(/^\s+|\s+$/g, "")
                        zoneDelegate.zoneTime = /^[0-9]{1,2}:[0-9]{2} (AM|PM)$/.test(t) ? t : ""
                      }
                    }
                  }

                  Text {
                    anchors.baseline: zoneTimeText.baseline
                    textFormat: Text.PlainText
                    text: zoneDelegate.modelData.label
                    color: typeof index !== "undefined" && index < root.tzHues.length
                      ? root.tzHues[index]
                      : Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 1
                  }

                  Text {
                    id: zoneTimeText
                    textFormat: Text.PlainText
                    text: zoneDelegate.zoneTime === "" ? "—" : zoneDelegate.zoneTime
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }
                }
              }
            }
          }

          // ---- Year progress, doubling as the rule under the hero:
          //      a plain hairline said nothing, and whole days done
          //      over days in the year says the same thing louder.
          Item {
            width: parent.width
            height: yearBlock.y + yearBlock.height

            Item {
              id: yearBlock
              y: Style.space(6)
              anchors.horizontalCenter: parent.horizontalCenter
              width: gridColumn.width
              height: Math.max(yearLabel.implicitHeight, Style.space(10))

              TapHandler {
                enabled: !root.editingLife
                onDoubleTapped: root.startEditingLife()
              }

              Row {
                visible: root.editingLife
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(10)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "BORN"
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.letterSpacing: 1
                }

                TextField {
                  id: bornField
                  width: Style.space(70)
                  anchors.verticalCenter: parent.verticalCenter
                  placeholderText: "year"
                  foreground: root.contentForeground
                  font.family: root.contentFontFamily
                  inputMethodHints: Qt.ImhDigitsOnly

                  Keys.onPressed: function(event) { root.handleLifeKey(event, expectancyField) }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.verticalCenterOffset: 0
                  leftPadding: Style.space(6)
                  text: "LIVE TO"
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.letterSpacing: 1
                }

                TextField {
                  id: expectancyField
                  width: Style.space(60)
                  anchors.verticalCenter: parent.verticalCenter
                  placeholderText: "90"
                  foreground: root.contentForeground
                  font.family: root.contentFontFamily
                  inputMethodHints: Qt.ImhDigitsOnly

                  Keys.onPressed: function(event) { root.handleLifeKey(event, bornField) }
                }
              }

              Text {
                id: yearLabel
                textFormat: Text.PlainText
                visible: !root.editingLife
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.today.getFullYear()
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }

              Text {
                id: yearPercent
                textFormat: Text.PlainText
                visible: !root.editingLife
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.yearDonePercent + "%"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Rectangle {
                id: yearTrack
                visible: !root.editingLife
                anchors.left: yearLabel.right
                anchors.right: yearPercent.left
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                height: Style.space(6)
                radius: Style.cornerRadius > 0 ? height / 2 : 0
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

                Rectangle {
                  width: Math.round(parent.width * root.yearDone)
                  height: parent.height
                  radius: parent.radius
                  color: Style.selectedStateColor(root.contentForeground, Commons.Color.accent)

                  Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
              }
            }
          }

          // ---- Memento mori. Only here once someone has gone looking and
          //      given an age; the same rail as the year above it, measured
          //      against a nominal lifetime.
          Item {
            visible: root.birthYear > 0
            width: parent.width
            height: visible ? lifeBlock.height : 0

            Item {
              id: lifeBlock
              anchors.horizontalCenter: parent.horizontalCenter
              width: gridColumn.width
              height: Math.max(lifeLabel.implicitHeight, Style.space(10))

              Text {
                id: lifeLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "LIFE"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }

              Text {
                id: lifePercent
                textFormat: Text.PlainText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.lifeDonePercent + "%"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Rectangle {
                anchors.left: lifeLabel.right
                anchors.right: lifePercent.left
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                height: Style.space(6)
                radius: Style.cornerRadius > 0 ? height / 2 : 0
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

                Rectangle {
                  width: Math.round(parent.width * root.lifeDone)
                  height: parent.height
                  radius: parent.radius
                  color: Style.selectedStateColor(root.contentForeground, Commons.Color.accent)

                  Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
              }

              TapHandler {
                onDoubleTapped: root.clearLife()
              }

              MouseArea {
                id: lifeMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton

                PanelToolTip {
                  visible: lifeMouse.containsMouse
                  text: "Memento Mori"
                  fontFamily: root.contentFontFamily
                }
              }
            }
          }

          // ---- Month grid: week numbers down a gutter on the left, then
          //      the seven day columns. Always six rows, so the popup is
          //      exactly as tall in February as it is in August.
          Item {
            width: parent.width
            height: gridColumn.y + gridColumn.height

            WheelHandler {
              onWheel: function(event) {
                // Horizontal wheels and touchpad side-scrolls report y === 0;
                // without this they would every one read as "next month".
                if (event.angleDelta.y === 0) return
                root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
              }
            }

            Column {
              id: gridColumn
              // The meter above is a solid rule; the grid needs room to
              // read as its own block rather than hanging off it.
              y: Style.space(18)
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(3)

              Row {
                id: headerRow
                spacing: root.cellSpacing

                // The week-number heading doubles as the week-start toggle.
                // It is the one control in the panel whose meaning is not
                // self-evident, so it carries a tooltip naming the day the
                // click will switch to.
                Rectangle {
                  width: root.weekColumnWidth
                  height: Style.space(16)
                  radius: Style.cornerRadius
                  color: weekStartMouse.containsMouse
                    ? Style.hoverFillFor(root.contentForeground, Commons.Color.accent)
                    : "transparent"

                  Text {
                    anchors.centerIn: parent
                    text: "W"
                    color: weekStartMouse.containsMouse
                      ? Style.hoverStateColor(root.contentForeground, Commons.Color.accent)
                      : Qt.darker(root.contentForeground, 1.9)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 1
                    font.bold: true
                  }

                  MouseArea {
                    id: weekStartMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleWeekStart()
                  }

                  PanelToolTip {
                    visible: weekStartMouse.containsMouse
                    text: "Start weeks on " + root.nextWeekStartLabel
                    fontFamily: root.contentFontFamily
                  }
                }

                Item {
                  width: root.gutterWidth
                  height: Style.space(16)
                }

                Repeater {
                  model: root.weekdays

                  Text {
                    textFormat: Text.PlainText
                    required property var modelData
                    width: root.cellWidth
                    height: Style.space(16)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.weekdayLabel(modelData)
                    color: Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 1
                    font.bold: true
                  }
                }
              }

              Repeater {
                model: root.weeks

                Row {
                  required property var modelData
                  spacing: root.cellSpacing

                  Text {
                    textFormat: Text.PlainText
                    width: root.weekColumnWidth
                    height: root.cellHeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.week
                    color: Qt.darker(root.contentForeground, 1.9)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Item {
                    width: root.gutterWidth
                    height: root.cellHeight
                  }

                  Repeater {
                    model: modelData.days

                    Rectangle {
                      required property var modelData

                      width: root.cellWidth
                      height: root.cellHeight
                      radius: Style.cornerRadius
                      // Today is outlined, not filled: a lit-up block shouts
                      // over a grid this quiet.
                      color: "transparent"
                      border.width: modelData.today ? Style.spacing.hairline : 0
                      border.color: Style.normalBorderFor(root.contentForeground, Commons.Color.accent)

                      Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: modelData.day
                        color: modelData.inMonth
                          ? (modelData.weekend ? Qt.darker(root.contentForeground, 1.45) : root.contentForeground)
                          : Qt.darker(root.contentForeground, 2.2)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.body
                        font.bold: modelData.today
                      }
                    }
                  }
                }
              }
            }

            // Hairline down the week-number gutter, drawn only beside the
            // day rows so it does not cut through the header band.
            Rectangle {
              x: gridColumn.x + root.weekColumnWidth + root.cellSpacing + Math.round((root.gutterWidth - width) / 2)
              y: gridColumn.y + headerRow.height + gridColumn.spacing
              width: Style.spacing.hairline
              height: gridColumn.height - headerRow.height - gridColumn.spacing
              color: root.contentForeground
              opacity: 0.1
            }
          }

          // ---- Month stepping, spanning the grid it drives. The chevrons
          //      sit on the grid's outer bounds, the same edges the year
          //      rail above uses, so the row reads as the panel's other
          //      full-width rail instead of a cluster floating in space.
          //      The label is centered and fixed-width, so it holds still
          //      from "MAY" to "SEPTEMBER".
          Item {
            width: parent.width
            height: monthNav.height

            Item {
              id: monthNav
              anchors.horizontalCenter: parent.horizontalCenter
              width: gridColumn.width
              height: monthLabel.implicitHeight + Style.space(10)

              Text {
                id: monthLabel
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                // Fixed width so the chevrons hold still between a
                // "MAY 2026" and a "SEPTEMBER 2026".
                width: Style.space(130)
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDate(root.viewDate, "MMMM yyyy").toUpperCase()
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.letterSpacing: 1
              }

              PanelActionButton {
                // Pulled out by the button's own padding so the glyph, not
                // its hit box, lines up with the "2026" on the year rail.
                anchors.left: parent.left
                anchors.leftMargin: -Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰅁"
                tooltipText: "Previous month"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.moveMonth(-1)
              }

              PanelActionButton {
                anchors.right: parent.right
                anchors.rightMargin: -Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰅂"
                tooltipText: "Next month"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.moveMonth(1)
              }
            }
          }

          // ---- Timer section, redesigned per design/timer-ux-spec.md:
          //      the readout IS the section. A 24px mm:ss hero (minutes-only
          //      "10M" read as a third button), mode tabs while idle, a
          //      remaining-time phase bar, a 4-segment rail for the set.
          //      Phase color is always co-coded with the phase word
          //      (WCAG 1.4.1); digits stay foreground in every state.
          Column {
            id: timerSection
            width: parent.width
            spacing: Style.space(6)

            property bool idleOnly: !root.timerRunning && root.timerDoneAt === 0
              && root.timerRemainingMs === 0 && !root.pomodoroActive
            property color breakHue: "#9ece6a"
            property color longBreakHue: "#bb9af7"
            property color phaseColor: root.pomodoroActive
              ? (root.pomodoroMode === "focus" ? Commons.Color.accent
                : (root.pomodoroMode === "longbreak" ? longBreakHue : breakHue))
              : (root.timerDoneAt > 0 ? Commons.Color.urgent : Commons.Color.accent)
            property int phaseTotalMin: {
              if (root.pomodoroActive)
                return root.pomodoroMode === "focus" ? root.pomodoroFocusMin
                  : (root.pomodoroMode === "longbreak" ? Model.POMODORO_LONG_BREAK_MIN : root.pomodoroBreakMin)
              if (idleOnly && root.timerTab === "pomo")
                return root.pomodoroFocusMin
              return root.timerMinutes
            }
            property real remainingMs: {
              if (root.pomodoroActive)
                return Math.max(0, root.pomodoroEndsAt - root.timerNow.getTime())
              if (idleOnly)
                return (root.timerTab === "pomo" ? root.pomodoroFocusMin : root.timerMinutes) * 60000
              if (root.timerDoneAt > 0)
                return 0
              return root.timerDisplayMs
            }
            property real phaseFraction: phaseTotalMin > 0
              ? Math.min(1, remainingMs / (phaseTotalMin * 60000)) : 0

            Item {
              width: parent.width
              height: sectionTitle.implicitHeight

              Text {
                id: sectionTitle
                anchors.left: parent.left
                textFormat: Text.PlainText
                text: root.pomodoroActive
                  ? Model.pomodoroPhaseLabel(root.pomodoroMode)
                    + " · " + (root.pomodoroMode === "focus"
                      ? (root.pomodoroCyclesDone % Model.POMODORO_CYCLE) + 1
                      : Math.min(root.pomodoroCyclesDone, Model.POMODORO_CYCLE))
                    + " OF " + Model.POMODORO_CYCLE
                  : (root.timerDoneAt > 0 ? "TIMER · DONE"
                    : (root.timerRunning ? "TIMER · RUNNING"
                      : (root.timerRemainingMs > 0 && root.timerDoneAt === 0 ? "TIMER · PAUSED"
                        : (root.timerTab === "pomo" ? "POMODORO" : "TIMER"))))
                color: root.pomodoroActive ? timerSection.phaseColor : Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 2
              }

              Rectangle {
                anchors.left: sectionTitle.right
                anchors.leftMargin: Style.space(8)
                anchors.verticalCenter: sectionTitle.verticalCenter
                width: Style.space(2) * 2
                height: Style.space(2) * 2
                radius: Style.space(2)
                visible: !timerSection.idleOnly
                color: timerSection.phaseColor

                SequentialAnimation on opacity {
                  running: root.timerDoneAt > 0
                  loops: Animation.Infinite
                  NumberAnimation { from: 1; to: 0.25; duration: 500; easing.type: Easing.InOutQuad }
                  NumberAnimation { from: 0.25; to: 1; duration: 500; easing.type: Easing.InOutQuad }
                }
              }

              Row {
                anchors.right: parent.right
                spacing: Style.space(4)
                visible: timerSection.idleOnly

                Rectangle {
                  width: tabManualText.implicitWidth + Style.space(16)
                  height: Style.space(24)
                  radius: Style.cornerRadius
                  border.width: Style.spacing.hairline
                  border.color: root.timerTab === "manual"
                    ? Style.normalBorderFor(root.contentForeground, Commons.Color.accent)
                    : Style.normalBorderFor(root.contentForeground, root.contentForeground)
                  color: root.timerTab === "manual"
                    ? Style.selectedFillFor(root.contentForeground, Commons.Color.accent)
                    : "transparent"

                  Text {
                    id: tabManualText
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: "TIMER"
                    color: root.timerTab === "manual" ? Commons.Color.accent : root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 1
                    font.bold: true
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.timerTab = "manual"
                  }
                }

                Rectangle {
                  width: tabPomoText.implicitWidth + Style.space(16)
                  height: Style.space(24)
                  radius: Style.cornerRadius
                  border.width: Style.spacing.hairline
                  border.color: root.timerTab === "pomo"
                    ? Style.normalBorderFor(root.contentForeground, Commons.Color.accent)
                    : Style.normalBorderFor(root.contentForeground, root.contentForeground)
                  color: root.timerTab === "pomo"
                    ? Style.selectedFillFor(root.contentForeground, Commons.Color.accent)
                    : "transparent"

                  Text {
                    id: tabPomoText
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: "POMODORO"
                    color: root.timerTab === "pomo" ? Commons.Color.accent : root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 1
                    font.bold: true
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.timerTab = "pomo"
                  }
                }
              }
            }

            // Hero: steppers flank the readout in fixed slots, so centering
            // never jumps when state changes (Fitts + Gestalt proximity).
            Item {
              width: parent.width
              height: timerHeroRow.height

              Row {
                id: timerHeroRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(12)

                TimerPill {
                  label: "−5M"
                  width: Style.space(52)
                  visible: !root.pomodoroActive && (!timerSection.idleOnly || root.timerTab === "manual")
                  dimmed: !timerSection.idleOnly
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.timerStep(-5)
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: Model.formatCountdown(timerSection.remainingMs)
                  color: root.timerDoneAt > 0 && !root.pomodoroActive
                    ? Commons.Color.urgent
                    : root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.display
                  font.letterSpacing: 1
                  font.bold: true
                }

                TimerPill {
                  label: "+5M"
                  width: Style.space(52)
                  visible: !root.pomodoroActive && (!timerSection.idleOnly || root.timerTab === "manual")
                  dimmed: !timerSection.idleOnly
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.timerStep(5)
                }
              }
            }

            // Remaining-time bar. Behavior-only motion, no re-layout.
            Rectangle {
              width: parent.width
              height: Style.space(3)
              radius: Style.space(1)
              visible: !timerSection.idleOnly
              color: root.timerDoneAt > 0 && !root.pomodoroActive
                ? Util.alpha(Commons.Color.urgent, 0.15)
                : Util.alpha(root.contentForeground, 0.12)

              Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                width: parent.width * timerSection.phaseFraction
                radius: parent.radius
                color: timerSection.phaseColor

                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                Behavior on color { ColorAnimation { duration: 250 } }
              }
            }

            // The set at a glance: 4 segments = 4 focus blocks; accent is
            // work done, the half-alpha segment is the block in progress.
            Item {
              width: parent.width
              height: cycleRail.height
              visible: root.pomodoroActive

              Row {
                id: cycleRail
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(4)

                Repeater {
                  model: Model.POMODORO_CYCLE

                  Rectangle {
                    required property int modelData
                    width: (timerSection.width - 3 * Style.space(4)) / Model.POMODORO_CYCLE
                    height: Style.space(4)
                    radius: Style.space(2)
                    color: {
                      var done = root.pomodoroMode === "longbreak" ? Model.POMODORO_CYCLE
                        : root.pomodoroCyclesDone % Model.POMODORO_CYCLE
                      if (modelData <= done) return Commons.Color.accent
                      if (modelData === done + 1 && root.pomodoroMode === "focus")
                        return Util.alpha(Commons.Color.accent, 0.5)
                      return Util.alpha(root.contentForeground, 0.12)
                    }
                  }
                }
              }
            }

            // Pomodoro idle summary: the whole contract in one muted line.
            Item {
              width: parent.width
              height: pomoSummary.implicitHeight
              visible: timerSection.idleOnly && root.timerTab === "pomo"

              Text {
                id: pomoSummary
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.PlainText
                text: "FOCUS " + root.pomodoroFocusMin + " · BREAK " + root.pomodoroBreakMin
                  + " · LONG " + Model.POMODORO_LONG_BREAK_MIN + " · " + Model.POMODORO_CYCLE + " BLOCKS"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
              }
            }

            // Verbs follow state; the primary carries the tone.
            Item {
              width: parent.width
              height: verbsRow.height

              Row {
                id: verbsRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(8)

                TimerPill {
                  label: "START"
                  prominent: true
                  visible: timerSection.idleOnly && root.timerTab === "manual"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.timerToggle()
                }

                TimerPill {
                  label: "PAUSE"
                  prominent: true
                  visible: !root.pomodoroActive && root.timerRunning
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.timerToggle()
                }

                TimerPill {
                  label: "RESUME"
                  prominent: true
                  visible: !root.pomodoroActive && !root.timerRunning && root.timerRemainingMs > 0 && root.timerDoneAt === 0
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.timerToggle()
                }

                TimerPill {
                  label: "RESET"
                  visible: !root.pomodoroActive && !root.timerRunning && root.timerRemainingMs > 0 && root.timerDoneAt === 0
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.timerReset()
                }

                TimerPill {
                  label: "RESET"
                  prominent: true
                  toneColor: Commons.Color.urgent
                  visible: !root.pomodoroActive && root.timerDoneAt > 0
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.timerReset()
                }

                TimerPill {
                  label: "START CYCLE"
                  prominent: true
                  visible: timerSection.idleOnly && root.timerTab === "pomo"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.pomodoroStart()
                }

                TimerPill {
                  label: "SKIP →"
                  visible: root.pomodoroActive
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.pomodoroAdvance()
                }

                TimerPill {
                  label: "STOP"
                  visible: root.pomodoroActive
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.pomodoroStop()
                }
              }
            }
          }

                  }
      }

      // ---- Settings: the gear swaps this view in over the calendar. The
      //      popup itself stays a read-out; every control writes through
      //      persistSettings, so the bar and rows apply live.
      Flickable {
        id: settingsScroll
        anchors.fill: parent
        visible: root.settingsOpen
        contentWidth: settingsView.width
        contentHeight: settingsView.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height || contentWidth > width

        SettingsView {
          id: settingsView
          clockPanel: root
          width: Math.max(settingsScroll.width, implicitWidth)
        }
      }

      // The gear. Last child so it rides above the content.
      Item {
        anchors.top: parent.top
        anchors.right: parent.right
        width: gearMouse.width
        height: gearMouse.height
        visible: !root.settingsOpen

        MouseArea {
          id: gearMouse
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: -Style.space(4)
          width: gearText.implicitWidth + Style.space(12)
          height: gearText.implicitHeight + Style.space(8)
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.settingsOpen = true

          Text {
            id: gearText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "\u2699"
            color: gearMouse.containsMouse ? Commons.Color.accent : Qt.darker(root.contentForeground, 1.4)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
          }

          PanelToolTip {
            visible: gearMouse.containsMouse
            text: "Time Piece settings"
            fontFamily: root.contentFontFamily
          }
        }
      }
    }
  }
}
