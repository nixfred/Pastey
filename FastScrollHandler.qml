import QtQml
import "ScrollPolicy.js" as ScrollPolicy

QtObject {
  id: root

  required property var flickable
  property real speedMultiplier: 4.0
  property real mouseWheelStep: 48

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
}
