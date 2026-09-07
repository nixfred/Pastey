const assert = require("node:assert/strict")
const model = require("../Model.js")

const text = { type: "text", text: "hello world" }
const link = { type: "text", text: "https://example.com/docs" }
const code = { type: "text", text: "function hello() {\n  return true\n}" }
const files = { type: "text", text: "file:///tmp/one.txt\nfile:///tmp/two.txt" }
const image = { type: "image", path: "/tmp/sample.png", mime: "image/png", capturedAt: "Today 09:00" }

assert.equal(model.category(text), "text")
assert.equal(model.category(link), "link")
assert.equal(model.category(code), "code")
assert.equal(model.category(files), "file")
assert.equal(model.category(image), "image")
assert.equal(model.preview(files), "2 files")
assert.equal(model.preview(image), "Image · Today 09:00")

const photoFile = { type: "text", text: "file:///tmp/holiday.JPG" }
const twoPhotos = { type: "text", text: "file:///tmp/a.png\nfile:///tmp/b.png" }
assert.equal(model.thumbnailPath(image), "/tmp/sample.png")
assert.equal(model.thumbnailPath(photoFile), "/tmp/holiday.JPG")
assert.equal(model.thumbnailPath(files), "")
assert.equal(model.thumbnailPath(twoPhotos), "")
assert.equal(model.thumbnailPath(text), "")
assert.equal(model.isImagePath("/tmp/a.webp"), true)
assert.equal(model.isImagePath("/tmp/a.txt"), false)

const rows = model.displayRows([image, photoFile, text], "", 200)
assert.equal(rows[0].previewImage, "/tmp/sample.png")
assert.equal(rows[1].previewImage, "/tmp/holiday.JPG")
assert.equal(rows[2].previewImage, "")

assert.equal(model.isPicture(image), true)
assert.equal(model.isPicture(photoFile), true)
assert.equal(model.isPicture(twoPhotos), true)   // no single thumbnail, still a photo clip
assert.equal(model.isPicture(files), false)
assert.equal(model.isPicture(text), false)

assert.equal(model.normalizeFilter("nonsense"), "all")
assert.equal(model.normalizeFilter(""), "all")
assert.equal(model.nextFilter("all", 1), "text")
assert.equal(model.nextFilter("image", 1), "all")
assert.equal(model.nextFilter("all", -1), "image")
assert.equal(model.nextFilter("bogus", 1), "text")

const mixed = [image, text, photoFile, link, files]
assert.equal(model.displayRows(mixed, "", 200, "all").length, 5)
assert.deepEqual(
  model.displayRows(mixed, "", 200, "image").map(r => r.historyIndex), [0, 2])
assert.deepEqual(
  model.displayRows(mixed, "", 200, "text").map(r => r.historyIndex), [1, 3, 4])
// An unknown filter shows everything rather than emptying the panel.
assert.equal(model.displayRows(mixed, "", 200, "bogus").length, 5)
// Filter and query compose: both must match.
assert.equal(model.displayRows(mixed, "holiday", 200, "image").length, 1)
assert.equal(model.displayRows(mixed, "holiday", 200, "text").length, 0)

const history = [text, link, code, files, image]
assert.equal(model.displayRows(history, "", 200).length, 5)
assert.equal(model.displayRows(history, "hello", 200).length, 2)
assert.equal(model.displayRows(history, "sample.png", 200).length, 1)
assert.equal(model.displayRows(history, "missing", 200).length, 0)

const oversized = Array.from({ length: 205 }, (_, i) => ({ type: "text", text: "clip " + i }))
assert.equal(model.parseEntries(JSON.stringify(oversized), 200).length, 200)
assert.equal(model.removeAt(oversized, 0, 200)[0].text, "clip 1")
assert.equal(model.removeAt(oversized, 0, 200).length, 200)

assert.deepEqual(model.parseEntries("not json", 200), [])
assert.deepEqual(model.filePaths({ type: "text", text: "not a file" }), [])

console.log("Pastey model tests passed")
