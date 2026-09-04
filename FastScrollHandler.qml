import QtQuick
import "ScrollPolicy.js" as ScrollPolicy

Item {
  id: root

  required property var flickable
  property real speedMultiplier: 4.0
  property real mouseWheelStep: 48

  x: 0
  y: 0
  width: flickable.width
  height: flickable.height
  z: 1000

  function applyDeltas(pixelDeltaY, angleDeltaY) {
    var outcome = ScrollPolicy.result(
      flickable.contentY,
      pixelDeltaY,
      angleDeltaY,
      flickable.originY,
      flickable.contentHeight,
      flickable.height,
      flickable.interactive,
      mouseWheelStep,
      speedMultiplier)

    if (outcome.moved) {
      flickable.cancelFlick()
      flickable.contentY = outcome.contentY
    }
    return outcome.accepted
  }

  // Instrumentation on this Quickshell stack showed that a child
  // WheelHandler loses the event to Flickable. A full-surface MouseArea with
  // no accepted buttons receives wheel input without stealing clicks or drags.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    hoverEnabled: false

    onWheel: function(wheel) {
      wheel.accepted = root.applyDeltas(wheel.pixelDelta.y, wheel.angleDelta.y)
    }
  }
}
