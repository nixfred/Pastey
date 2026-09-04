const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const policy = require("../ScrollPolicy.js")

assert.equal(policy.scrollDistance(12, 0, 48, 4), 48)
assert.equal(policy.scrollDistance(-12, 0, 48, 4), -48)
assert.equal(policy.scrollDistance(0, 120, 48, 4), 192)
assert.equal(policy.scrollDistance(0, -120, 48, 4), -192)
assert.equal(policy.scrollDistance(5, 120, 48, 4), 20)
assert.equal(policy.scrollDistance(0, 120, 30, 2), 60)
assert.equal(policy.scrollDistance(0, 0, 48, 4), 0)

assert.deepEqual(policy.bounds(0, 1000, 300), { minimum: 0, maximum: 700 })
assert.deepEqual(policy.bounds(10, 100, 300), { minimum: 10, maximum: 10 })
assert.equal(policy.boundedContentY(-1, 0, 1000, 300), 0)
assert.equal(policy.boundedContentY(900, 0, 1000, 300), 700)

let outcome = policy.result(300, 20, 0, 0, 1000, 300, true, 48, 4)
assert.deepEqual(outcome, { contentY: 220, distance: 80, moved: true, accepted: true })

outcome = policy.result(0, 20, 0, 0, 1000, 300, true, 48, 4)
assert.equal(outcome.contentY, 0)
assert.equal(outcome.accepted, false)

outcome = policy.result(700, -20, 0, 0, 1000, 300, true, 48, 4)
assert.equal(outcome.contentY, 700)
assert.equal(outcome.accepted, false)

outcome = policy.result(300, 20, 0, 0, 1000, 300, false, 48, 4)
assert.equal(outcome.contentY, 300)
assert.equal(outcome.accepted, false)

outcome = policy.result(10, 0, -120, 10, 100, 300, true, 48, 4)
assert.equal(outcome.contentY, 10)
assert.equal(outcome.accepted, false)

const root = path.resolve(__dirname, "..")
const panel = fs.readFileSync(path.join(root, "Panel.qml"), "utf8")
const handler = fs.readFileSync(path.join(root, "FastScrollHandler.qml"), "utf8")

assert.equal((panel.match(/FastScrollHandler\s*\{/g) || []).length, 1)
assert.equal((panel.match(/onWheel:\s*function\(wheel\)/g) || []).length, 1)
assert.match(panel, /wheel\.accepted\s*=\s*fastScroll\.applyDeltas/)
assert.doesNotMatch(handler, /MouseArea\s*\{/)
assert.doesNotMatch(handler, /WheelHandler\s*\{/)
assert.match(handler, /QtObject\s*\{/)

console.log("Pastey scroll policy tests passed")
