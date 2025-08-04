import qs.widgets
import qs.services
import qs.config
import QtQuick
import QtQuick.Controls

Slider {
  id: root

  required property string icon
  property real oldValue

  orientation: Qt.Vertical

  background: StyledRect {
  color: Colours.alpha(Colours.palette.m3surfaceContainer, true)
  radius: Appearance.rounding.full

  StyledRect {
    anchors.left: parent.left
    anchors.right: parent.right

    y: root.handle.y
    implicitHeight: parent.height - y

    color: Colours.alpha(Colours.palette.m3secondary, true)
    radius: Appearance.rounding.full
  }
  }

  handle: Item {
  id: handle

  property bool moving

  y: root.visualPosition * (root.availableHeight - height)
  implicitWidth: root.width
  implicitHeight: root.width

  Elevation {
    anchors.fill: parent
    radius: rect.radius
    level: handleInteraction.containsMouse ? 2 : 1
  }

  StyledRect {
    id: rect

    anchors.fill: parent

    color: Colours.alpha(Colours.palette.m3inverseSurface, true)
    radius: Appearance.rounding.full

    MouseArea {
    id: handleInteraction

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.NoButton
    }

    MaterialIcon {
    id: icon

    property bool moving: handle.moving

    function update(): void {
      animate = !moving;
      text = moving ? Qt.binding(() => Math.round(root.value * 100)) : Qt.binding(() => root.icon);
      font.pointSize = moving ? Appearance.font.size.small : Appearance.font.size.larger;
      font.family = moving ? Appearance.font.family.sans : Appearance.font.family.material;
    }

    animate: true
    text: root.icon
    color: Colours.palette.m3inverseOnSurface
    anchors.centerIn: parent

    Behavior on moving {
      SequentialAnimation {
      NumberAnimation {
        target: icon
        property: "scale"
        from: 1
        to: 0
        duration: Appearance.anim.durations.normal / 2
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.anim.curves.standardAccel
      }
      ScriptAction {
        script: icon.update()
      }
      NumberAnimation {
        target: icon
        property: "scale"
        from: 0
        to: 1
        duration: Appearance.anim.durations.normal / 2
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.anim.curves.standardDecel
      }
      }
    }
    }
  }
  }

  onPressedChanged: handle.moving = pressed

  onValueChanged: {
  if (Math.abs(value - oldValue) < 0.01)
    return;
  oldValue = value;
  handle.moving = true;
  stateChangeDelay.restart();
  }

  Timer {
  id: stateChangeDelay

  interval: 500
  onTriggered: {
    if (!root.pressed)
    handle.moving = false;
  }
  }

  Behavior on value {
  NumberAnimation {
    duration: Appearance.anim.durations.large
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Appearance.anim.curves.standard
  }
  }
}
