import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model
import "zones.js" as Zones

// Settings view: opened by the gear in the clock panel, swapped in over the
// calendar. The popup itself stays a read-out — every control here writes
// through the panel's persistSettings (updateEntryInline), so the bar label
// and the world-clock rows apply live.
//
// Zone search follows the NN/g findings: type-to-filter as the primary
// interaction, matches on city first (with US zone abbreviations as
// aliases), region names only from three characters up, results capped at
// eight. Candidate rows show place names, not offsets; live times are spent
// only on the zones already chosen (each is one `date` call a minute).
Column {
  id: view

  property var clockPanel: null
  property string search: ""

  // The panel's SystemClock id is not visible from this file, so the view
  // keeps its own minute-precision clock for the zone-row refresh ticks.
  SystemClock {
    id: settingsClock
    precision: SystemClock.Minutes
  }

  readonly property var results: Model.filterZones(Zones.TZ_REGIONS, search, 8)

  spacing: Style.space(16)

  function close() { if (clockPanel) clockPanel.settingsOpen = false }

  onVisibleChanged: {
    if (visible) Qt.callLater(function() { if (searchField) searchField.forceActiveFocus() })
  }

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) { view.close(); event.accepted = true }
  }

  // ---- Header.
  Item {
    width: parent.width
    height: settingsHeaderText.implicitHeight

    Text {
      id: settingsHeaderText
      anchors.left: parent.left
      textFormat: Text.PlainText
      text: "SETTINGS"
      color: Qt.darker(clockPanel.contentForeground, 1.5)
      font.family: clockPanel.contentFontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 2
    }

    Text {
      anchors.right: parent.right
      anchors.baseline: settingsHeaderText.baseline
      textFormat: Text.PlainText
      text: "✕"
      color: settingsCloseMouse.containsMouse ? Commons.Color.accent : clockPanel.contentForeground
      font.family: clockPanel.contentFontFamily
      font.pixelSize: Style.font.body

      MouseArea {
        id: settingsCloseMouse
        anchors.fill: parent
        anchors.margins: -Style.space(6)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: view.close()
      }
    }
  }

  // ---- World clocks: the chosen zones with live times, one row each.
  Column {
    width: parent.width
    spacing: Style.space(8)

    Text {
      textFormat: Text.PlainText
      text: "WORLD CLOCKS"
      color: Qt.darker(clockPanel.contentForeground, 1.5)
      font.family: clockPanel.contentFontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
    }

    Column {
      width: parent.width
      visible: clockPanel.worldClocks.length > 0
      spacing: Style.space(4)

      Repeater {
        model: clockPanel.worldClocks

        Item {
          id: zoneRow
          required property var modelData
          width: parent.width
          height: Math.max(zoneRowLabel.implicitHeight, zoneRowTime.implicitHeight)
          property string zoneTime: ""
          property date minuteTick: settingsClock.date

          function refreshZone() {
            if (zoneRowProc.running) zoneRowProc.running = false
            zoneRowProc.running = true
          }

          Component.onCompleted: refreshZone()
          onMinuteTickChanged: refreshZone()

          Process {
            id: zoneRowProc
            command: ["date", "+%-I:%M %p"]
            environment: ({ "TZ": zoneRow.modelData.zone })
            stdout: StdioCollector {
              waitForEnd: true
              onStreamFinished: {
                var t = String(text).replace(/^\s+|\s+$/g, "")
                zoneRow.zoneTime = /^[0-9]{1,2}:[0-9]{2} (AM|PM)$/.test(t) ? t : ""
              }
            }
          }

          Text {
            id: zoneRowLabel
            anchors.left: parent.left
            anchors.baseline: zoneRowTime.baseline
            textFormat: Text.PlainText
            text: zoneRow.modelData.label
            color: clockPanel.contentForeground
            font.family: clockPanel.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Text {
            id: zoneRowTime
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: zoneRow.zoneTime === "" ? "—" : zoneRow.zoneTime
            color: clockPanel.contentForeground
            font.family: clockPanel.contentFontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            anchors.right: parent.right
            anchors.baseline: zoneRowTime.baseline
            textFormat: Text.PlainText
            text: "×"
            color: zoneRowRemoveMouse.containsMouse ? Commons.Color.accent : Qt.darker(clockPanel.contentForeground, 1.4)
            font.family: clockPanel.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true

            MouseArea {
              id: zoneRowRemoveMouse
              anchors.fill: parent
              anchors.margins: -Style.space(6)
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: clockPanel.zonesRemove(zoneRow.modelData.zone)
            }
          }
        }
      }
    }

    Text {
      visible: clockPanel.worldClocks.length === 0
      textFormat: Text.PlainText
      text: "None yet — search below to add one."
      color: Qt.darker(clockPanel.contentForeground, 1.5)
      font.family: clockPanel.contentFontFamily
      font.pixelSize: Style.font.caption
    }
  }

  // ---- Add a city: search-first, per the research. Aliases (ET, PT, UTC…)
  //      resolve before the list match; region names count from three chars.
  Column {
    width: parent.width
    spacing: Style.space(8)

    Text {
      textFormat: Text.PlainText
      text: "ADD A CITY"
      color: Qt.darker(clockPanel.contentForeground, 1.5)
      font.family: clockPanel.contentFontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
    }

    TextField {
      id: searchField
      width: parent.width
      placeholderText: "Search — city, region, or ET/PT/UTC…"
      foreground: clockPanel.contentForeground
      font.family: clockPanel.contentFontFamily
      font.pixelSize: Style.font.body
      onTextChanged: view.search = text
    }

    Column {
      width: parent.width
      visible: view.results.length > 0
      spacing: Style.space(2)

      Repeater {
        model: view.results

        Rectangle {
          id: resultRow
          required property var modelData
          width: parent.width
          height: Math.max(resultCity.implicitHeight, resultRegion.implicitHeight) + Style.space(8)
          radius: Style.cornerRadius
          color: resultRowMouse.containsMouse
            ? Style.hoverFillFor(clockPanel.contentForeground, Commons.Color.accent)
            : "transparent"

          property bool picked: {
            var zones = clockPanel.worldClocks
            for (var i = 0; i < zones.length; i++) {
              if (zones[i].zone === resultRow.modelData.zone) return true
            }
            return false
          }

          Text {
            id: resultCity
            anchors.left: parent.left
            anchors.leftMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: resultRow.modelData.city + (resultRow.picked ? "  ✓" : "")
            color: resultRow.picked ? Commons.Color.accent : clockPanel.contentForeground
            font.family: clockPanel.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Text {
            id: resultRegion
            anchors.right: parent.right
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: resultRow.modelData.subregion !== ""
              ? resultRow.modelData.region + " · " + resultRow.modelData.subregion
              : resultRow.modelData.region
            color: Qt.darker(clockPanel.contentForeground, 1.5)
            font.family: clockPanel.contentFontFamily
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            id: resultRowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              clockPanel.zonesAdd(resultRow.modelData.zone)
              searchField.clear()
              searchField.forceActiveFocus()
            }
          }
        }
      }
    }

    Text {
      visible: view.search.replace(/^\s+|\s+$/g, "") !== "" && view.results.length === 0
      textFormat: Text.PlainText
      text: "No match — try a bigger city nearby."
      color: Qt.darker(clockPanel.contentForeground, 1.5)
      font.family: clockPanel.contentFontFamily
      font.pixelSize: Style.font.caption
    }
  }

  // ---- Bar: the date toggle, now a settings row instead of a popup pill.
  Column {
    width: parent.width
    spacing: Style.space(8)

    Text {
      textFormat: Text.PlainText
      text: "BAR"
      color: Qt.darker(clockPanel.contentForeground, 1.5)
      font.family: clockPanel.contentFontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
    }

    Item {
      width: parent.width
      height: Math.max(dateToggleLabel.implicitHeight, dateTogglePill.height)

      Text {
        id: dateToggleLabel
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "Date in bar"
        color: clockPanel.contentForeground
        font.family: clockPanel.contentFontFamily
        font.pixelSize: Style.font.body
      }

      Rectangle {
        id: dateTogglePill
        anchors.right: parent.right
        width: dateTogglePillText.implicitWidth + Style.space(24)
        height: Math.max(dateTogglePillText.implicitHeight + Style.space(8), Style.space(24))
        radius: Style.cornerRadius
        border.width: Style.spacing.hairline
        border.color: dateToggleMouse.containsMouse
          ? Commons.Color.accent
          : Style.normalBorderFor(clockPanel.contentForeground, clockPanel.contentForeground)
        color: clockPanel.showDate
          ? Style.hoverFillFor(clockPanel.contentForeground, Commons.Color.accent)
          : "transparent"

        Text {
          id: dateTogglePillText
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: clockPanel.showDate ? "ON" : "OFF"
          color: clockPanel.contentForeground
          font.family: clockPanel.contentFontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          font.bold: true
        }

        MouseArea {
          id: dateToggleMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: clockPanel.toggleShowDate()
        }
      }
    }
  }

  // ---- Timer: the idle preset the popup's −5M/+5M steppers nudge.
  Column {
    width: parent.width
    spacing: Style.space(8)

    Text {
      textFormat: Text.PlainText
      text: "TIMER"
      color: Qt.darker(clockPanel.contentForeground, 1.5)
      font.family: clockPanel.contentFontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
    }

    Item {
      width: parent.width
      height: Math.max(timerDefaultLabel.implicitHeight, timerMinus.height)

      Text {
        id: timerDefaultLabel
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "Default minutes"
        color: clockPanel.contentForeground
        font.family: clockPanel.contentFontFamily
        font.pixelSize: Style.font.body
      Row {
        anchors.right: parent.right
        spacing: Style.space(8)

        Rectangle {
          id: timerMinus
          width: Style.space(44)
          height: Math.max(timerMinusText.implicitHeight + Style.space(8), Style.space(24))
          radius: Style.cornerRadius
          border.width: Style.spacing.hairline
          border.color: Style.normalBorderFor(clockPanel.contentForeground, clockPanel.contentForeground)

          Text {
            id: timerMinusText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "−5"
            color: clockPanel.contentForeground
            font.family: clockPanel.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: clockPanel.timerStep(-5)
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: clockPanel.timerMinutes
          color: clockPanel.contentForeground
          font.family: clockPanel.contentFontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Rectangle {
          width: Style.space(44)
          height: timerMinus.height
          radius: Style.cornerRadius
          border.width: Style.spacing.hairline
          border.color: Style.normalBorderFor(clockPanel.contentForeground, clockPanel.contentForeground)

          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "+5"
            color: clockPanel.contentForeground
            font.family: clockPanel.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: clockPanel.timerStep(5)
          }
        }
      }
    }
  }

  // ---- Pomodoro: the cycle lengths. Long break (15) and set length (4)
  //      are fixed — two steppers carry everything a user actually tunes.
  Column {
    width: parent.width
    spacing: Style.space(8)

    Text {
      textFormat: Text.PlainText
      text: "POMODORO"
      color: Qt.darker(clockPanel.contentForeground, 1.5)
      font.family: clockPanel.contentFontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
    }

    Item {
      width: parent.width
      height: Math.max(pomoFocusLabel.implicitHeight, pomoSteppers.height)

      Text {
        id: pomoFocusLabel
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "Focus / break minutes"
        color: clockPanel.contentForeground
        font.family: clockPanel.contentFontFamily
        font.pixelSize: Style.font.body
      }

      Row {
        id: pomoSteppers
        anchors.right: parent.right
        spacing: Style.space(8)

        Rectangle {
          width: Style.space(36)
          height: Math.max(pomoMinusText.implicitHeight + Style.space(8), Style.space(24))
          radius: Style.cornerRadius
          border.width: Style.spacing.hairline
          border.color: Style.normalBorderFor(clockPanel.contentForeground, clockPanel.contentForeground)

          Text {
            id: pomoMinusText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "−"
            color: clockPanel.contentForeground
            font.family: clockPanel.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { clockPanel.pomodoroStep(-5, "focus"); clockPanel.pomodoroStep(-1, "break") }
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: clockPanel.pomodoroFocusMin + " / " + clockPanel.pomodoroBreakMin
          color: clockPanel.contentForeground
          font.family: clockPanel.contentFontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Rectangle {
          width: Style.space(36)
          height: Math.max(pomoMinusText.implicitHeight + Style.space(8), Style.space(24))
          radius: Style.cornerRadius
          border.width: Style.spacing.hairline
          border.color: Style.normalBorderFor(clockPanel.contentForeground, clockPanel.contentForeground)

          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "+"
            color: clockPanel.contentForeground
            font.family: clockPanel.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { clockPanel.pomodoroStep(5, "focus"); clockPanel.pomodoroStep(1, "break") }
          }
        }
      }
    }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      textFormat: Text.PlainText
      text: "4 focus blocks, then a 15-minute long break. Phases advance on their own; a desktop notification marks each flip."
      color: Qt.darker(clockPanel.contentForeground, 1.5)
      font.family: clockPanel.contentFontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
}
