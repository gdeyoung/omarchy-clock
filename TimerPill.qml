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
  signal clicked()

  width: pillText.implicitWidth + (prominent ? Style.space(24) : Style.space(16))
  height: Math.max(pillText.implicitHeight + Style.space(8), Style.space(22))
  radius: Style.cornerRadius
  border.width: Style.spacing.hairline
  border.color: pillMouse.containsMouse
    ? Style.normalBorderFor(pill.foreground, Commons.Color.accent)
    : Style.normalBorderFor(pill.foreground, pill.foreground)
  color: pillMouse.containsMouse
    ? Style.hoverFillFor(pill.foreground, Commons.Color.accent)
    : "transparent"

  Text {
    id: pillText
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: pill.label
    color: pill.prominent ? Commons.Color.accent : pill.foreground
    font.family: pill.fontFamily
    font.pixelSize: Style.font.caption
    font.letterSpacing: 1
    font.bold: true
  }

  MouseArea {
    id: pillMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: pill.clicked()
  }
}
