function numberOrZero(value) {
  var number = Number(value)
  return isFinite(number) ? number : 0
}

function scrollDistance(pixelDeltaY, angleDeltaY, mouseWheelStep, speedMultiplier) {
  var distance = numberOrZero(pixelDeltaY)
  if (distance === 0)
    distance = numberOrZero(angleDeltaY) / 120 * Math.max(1, numberOrZero(mouseWheelStep))
  return distance * Math.max(0, numberOrZero(speedMultiplier))
}

function bounds(originY, contentHeight, viewportHeight) {
  var minimum = numberOrZero(originY)
  var maximum = Math.max(minimum,
    minimum + Math.max(0, numberOrZero(contentHeight))
      - Math.max(0, numberOrZero(viewportHeight)))
  return { minimum: minimum, maximum: maximum }
}

function boundedContentY(value, originY, contentHeight, viewportHeight) {
  var limits = bounds(originY, contentHeight, viewportHeight)
  return Math.max(limits.minimum, Math.min(limits.maximum, numberOrZero(value)))
}

function result(currentY, pixelDeltaY, angleDeltaY, originY, contentHeight,
                viewportHeight, interactive, mouseWheelStep, speedMultiplier) {
  var current = numberOrZero(currentY)
  var distance = scrollDistance(pixelDeltaY, angleDeltaY, mouseWheelStep, speedMultiplier)
  if (!interactive || distance === 0)
    return { contentY: current, distance: distance, moved: false, accepted: false }

  var next = boundedContentY(current - distance, originY, contentHeight, viewportHeight)
  var moved = Math.abs(next - current) > 0.01
  return { contentY: next, distance: distance, moved: moved, accepted: moved }
}

if (typeof module !== "undefined") {
  module.exports = {
    scrollDistance: scrollDistance,
    bounds: bounds,
    boundedContentY: boundedContentY,
    result: result
  }
}
