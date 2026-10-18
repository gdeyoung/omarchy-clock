import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Small bordered text button for the timer controls, in the same idiom as
// the DATE IN BAR pill: hairline border, hover fill, bold caption label.
// Callers pass the panel's foreground and font — a component file cannot
// see the instantiating context's root.
Rectangle {
  id: pill

  property string label: ""
  property bool prominent: false
  property color foreground
  property string fontFamily
  property color toneColor: Commons.Color.accent
  property bool dimmed: false
  signal clicked()

  width: pillText.implicitWidth + (prominent ? Style.space(24) : Style.space(16))
  height: Math.max(pillText.implicitHeight + Style.space(8),
    prominent ? Style.spacing.controlHeight : Style.space(24))
  radius: Style.cornerRadius
  opacity: pill.dimmed ? 0.3 : 1
  border.width: Style.spacing.hairline
  border.color: !pill.dimmed && pillMouse.containsMouse
    ? Style.normalBorderFor(pill.foreground, pill.toneColor)
    : Style.normalBorderFor(pill.foreground, pill.foreground)
  color: !pill.dimmed && pillMouse.containsMouse
    ? Style.hoverFillFor(pill.foreground, pill.toneColor)
    : "transparent"

  Text {
    id: pillText
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: pill.label
    color: pill.prominent ? pill.toneColor : pill.foreground
    font.family: pill.fontFamily
    font.pixelSize: Style.font.caption
    font.letterSpacing: 1
    font.bold: true
  }

  MouseArea {
    id: pillMouse
    anchors.fill: parent
    enabled: !pill.dimmed
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: pill.clicked()
  }
}
