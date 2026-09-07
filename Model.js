function normalizeEntry(value) {
  if (typeof value === "string")
    return value.trim() ? { type: "text", text: value } : null
  if (!value || typeof value !== "object") return null

  var type = String(value.type || value.kind || "")
  if (type === "text") {
    var text = String(value.text || "")
    return text.trim() ? { type: "text", text: text } : null
  }

  if (type === "image") {
    var path = String(value.path || "")
    if (!path) return null
    var image = {
      type: "image",
      path: path,
      mime: String(value.mime || "image/png")
    }
    if (value.capturedAt !== undefined && value.capturedAt !== null)
      image.capturedAt = String(value.capturedAt)
    return image
  }

  return null
}

function parseEntries(raw, limit) {
  var maximum = limit === undefined ? 200 : Math.max(0, Number(limit) || 0)
  try {
    var values = JSON.parse(String(raw || "[]"))
    if (!Array.isArray(values)) return []
    var result = []
    for (var i = 0; i < values.length && result.length < maximum; i++) {
      var entry = normalizeEntry(values[i])
      if (entry) result.push(entry)
    }
    return result
  } catch (e) {
    return []
  }
}

function decodeFileUri(uri) {
  var value = String(uri || "").trim()
  if (value.indexOf("file://") !== 0) return ""
  var path = value.substring(7)
  if (path.indexOf("localhost/") === 0) path = path.substring(9)
  if (path.charAt(0) !== "/") return ""
  try { return decodeURIComponent(path) } catch (e) { return path }
}

function filePaths(entry) {
  var value = normalizeEntry(entry)
  if (!value || value.type !== "text") return []
  var lines = value.text.split(/\r?\n/)
  var paths = []
  for (var i = 0; i < lines.length; i++) {
    var path = decodeFileUri(lines[i])
    if (path) paths.push(path)
  }
  return paths
}

function isImagePath(path) {
  return /\.(png|jpe?g|gif|webp|bmp|avif|tiff?|svg)$/i.test(String(path || ""))
}

// A row shows a picture when it IS a captured image, and also when it is a
// single copied file that happens to be one — a file:// copy of a screenshot
// is still a photo the user needs to recognise at a glance.
function thumbnailPath(entry) {
  var value = normalizeEntry(entry)
  if (!value) return ""
  if (value.type === "image") return value.path
  var paths = filePaths(value)
  return paths.length === 1 && isImagePath(paths[0]) ? paths[0] : ""
}

// Whether a row is a picture for the purposes of the text/photos toggle.
// Broader than thumbnailPath on purpose: a copy of two screenshots has no
// single thumbnail to show, but it is still a photo clip and belongs under
// "Photos" rather than under "Text".
function isPicture(entry) {
  var value = normalizeEntry(entry)
  if (!value) return false
  if (value.type === "image") return true
  var paths = filePaths(value)
  if (paths.length === 0) return false
  for (var i = 0; i < paths.length; i++)
    if (!isImagePath(paths[i])) return false
  return true
}

var FILTERS = ["all", "text", "image"]

function normalizeFilter(filter) {
  var mode = String(filter || "all")
  return FILTERS.indexOf(mode) >= 0 ? mode : "all"
}

function matchesFilter(entry, filter) {
  var mode = normalizeFilter(filter)
  if (mode === "all") return true
  return mode === "image" ? isPicture(entry) : !isPicture(entry)
}

// Cycle through the toggle in either direction, wrapping at both ends so
// Left from "all" lands on "image" rather than dead-ending.
function nextFilter(filter, delta) {
  var index = FILTERS.indexOf(normalizeFilter(filter))
  var step = Number(delta) || 0
  var count = FILTERS.length
  return FILTERS[((index + step) % count + count) % count]
}

function basename(path) {
  var parts = String(path || "").split("/")
  return parts.length ? parts[parts.length - 1] : ""
}

function category(entry) {
  var value = normalizeEntry(entry)
  if (!value) return "text"
  if (value.type === "image") return "image"
  if (filePaths(value).length > 0) return "file"
  if (/^https?:\/\/\S+$/i.test(value.text.trim())) return "link"
  if (/[\n\r]/.test(value.text)
      && /[{}();=<>]|\b(function|class|const|let|def|import)\b/.test(value.text)) return "code"
  return "text"
}

function preview(entry) {
  var value = normalizeEntry(entry)
  if (!value) return ""
  if (value.type === "image")
    return value.capturedAt ? "Image · " + value.capturedAt : "Image"

  var paths = filePaths(value)
  if (paths.length === 1) return basename(paths[0])
  if (paths.length > 1) return paths.length + " files"
  return value.text.slice(0, 8192).replace(/\s+/g, " ").trim().slice(0, 500)
}

function searchableText(entry) {
  var value = normalizeEntry(entry)
  if (!value) return ""
  if (value.type === "image")
    return ["image", "screenshot", value.mime, value.path, value.capturedAt || ""].join(" ")
  return value.text.slice(0, 8192) + " " + filePaths(value).join(" ")
}

function displayRows(history, query, limit, filter) {
  var values = Array.isArray(history) ? history : []
  var needle = String(query || "").trim().toLowerCase()
  var maximum = limit === undefined ? 200 : Math.max(0, Number(limit) || 0)
  var mode = normalizeFilter(filter)
  var rows = []

  for (var i = 0; i < values.length && rows.length < maximum; i++) {
    var entry = normalizeEntry(values[i])
    if (!entry) continue
    if (!matchesFilter(entry, mode)) continue
    if (needle && searchableText(entry).toLowerCase().indexOf(needle) < 0) continue
    var kind = category(entry)
    rows.push({
      historyIndex: i,
      entryType: entry.type,
      category: kind,
      previewText: preview(entry),
      detailText: kind.charAt(0).toUpperCase() + kind.slice(1),
      previewImage: thumbnailPath(entry)
    })
  }

  return rows
}

function removeAt(history, index, limit) {
  var values = Array.isArray(history) ? history.slice() : []
  var target = Number(index)
  if (isFinite(target) && target >= 0 && target < values.length) values.splice(target, 1)
  var maximum = limit === undefined ? 200 : Math.max(0, Number(limit) || 0)
  return values.slice(0, maximum)
}

if (typeof module !== "undefined") {
  module.exports = {
    normalizeEntry: normalizeEntry,
    parseEntries: parseEntries,
    decodeFileUri: decodeFileUri,
    filePaths: filePaths,
    isImagePath: isImagePath,
    thumbnailPath: thumbnailPath,
    isPicture: isPicture,
    filters: FILTERS,
    normalizeFilter: normalizeFilter,
    matchesFilter: matchesFilter,
    nextFilter: nextFilter,
    category: category,
    preview: preview,
    searchableText: searchableText,
    displayRows: displayRows,
    removeAt: removeAt
  }
}
