import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "nixfred.pastey"
  ipcTarget: "nixfred.pastey"

  readonly property int historyLimit: 200
  readonly property int visibleRowCount: 5
  readonly property int rowHeight: Style.space(62)
  readonly property int rowSpacing: Style.space(5)
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME")
    || Quickshell.env("HOME") + "/.local/state") + "/omarchy"
  readonly property string historyPath: stateDir + "/clipboard-history.json"
  readonly property string pluginDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Identity for the About line. The manifest is the single source of truth
  // for all three, so bumping a version or moving the repo is one edit there.
  // The constants are the fallback for when the registry is not reachable.
  readonly property var pluginManifest: {
    var reg = bar && bar.shell ? bar.shell.pluginRegistry : null
    return reg && reg.installedPlugins ? (reg.installedPlugins[root.moduleName] || null) : null
  }
  readonly property string pluginVersion: pluginManifest && pluginManifest.version
    ? String(pluginManifest.version) : ""
  readonly property string repoUrl: pluginManifest && pluginManifest.repository
    ? String(pluginManifest.repository) : "https://github.com/nixfred/Pastey"
  readonly property string homeUrl: pluginManifest && pluginManifest.homepage
    ? String(pluginManifest.homepage) : "https://nixfred.com"

  property var history: []
  property string query: ""
  property string filter: "all"
  property int selectedIndex: 0
  property string actionStatus: ""

  ListModel { id: displayModel }

  function rebuild() {
    var rows = Model.displayRows(history, query, historyLimit, filter)
    displayModel.clear()
    for (var i = 0; i < rows.length; i++) displayModel.append(rows[i])

    if (displayModel.count === 0) selectedIndex = 0
    else selectedIndex = Math.max(0, Math.min(selectedIndex, displayModel.count - 1))

    Qt.callLater(function() {
      if (displayModel.count > 0)
        resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
    })
  }

  function loadHistory(raw) {
    var parsed
    try { parsed = JSON.parse(String(raw || "[]")) } catch (e) { parsed = [] }
    var sourceCount = Array.isArray(parsed) ? parsed.length : 0
    history = Model.parseEntries(raw, historyLimit)
    rebuild()

    // The stock recorder intentionally keeps a larger general-purpose history.
    // Pastey owns the user's tighter contract and trims it whenever a capture
    // pushes the shared file past 200 entries.
    if (sourceCount > historyLimit) {
      historyFile.setText(JSON.stringify(history, null, 2) + "\n")
    }
  }

  function selectedRow() {
    return displayModel.count > 0 && selectedIndex >= 0 && selectedIndex < displayModel.count
      ? displayModel.get(selectedIndex) : null
  }

  function select(delta) {
    if (displayModel.count === 0) return
    selectedIndex = Math.max(0, Math.min(displayModel.count - 1, selectedIndex + delta))
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function setQuery(value) {
    query = String(value || "")
    selectedIndex = 0
    rebuild()
  }

  function setFilter(value) {
    var next = Model.normalizeFilter(value)
    if (next === filter) return
    filter = next
    selectedIndex = 0
    rebuild()
  }

  function cycleFilter(delta) {
    setFilter(Model.nextFilter(filter, delta))
  }

  // Names the mode the user is in, so the hero count and the empty state
  // don't each re-derive it. Counting is against the filtered view, never
  // against the whole history — "2 of 5 pictures" would be a lie when the 5
  // is the total clip count.
  function filterNoun(count) {
    if (filter === "image") return count === 1 ? "picture" : "pictures"
    if (filter === "text") return count === 1 ? "text clip" : "text clips"
    return count === 1 ? "clip" : "clips"
  }

  function restoreClipboard(row, closeAfter) {
    var target = row || selectedRow()
    if (!target || actionProc.running) return
    if (closeAfter !== false) root.close()
    actionProc.command = [pluginDir + "/pastey-action", String(target.historyIndex)]
    actionProc.running = true
  }

  function removeRow(row) {
    var target = row || selectedRow()
    if (!target) return
    history = Model.removeAt(history, target.historyIndex, historyLimit)
    historyFile.setText(JSON.stringify(history, null, 2) + "\n")
    actionStatus = "Removed"
    statusTimer.restart()
    rebuild()
  }

  component Caption: Text {
    textFormat: Text.PlainText
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  // A caption that opens a URL. xdg-open is detached so a slow browser start
  // never blocks the shell, and the panel closes so the page is not opened
  // behind a popup the click also dismissed.
  component Link: Text {
    id: linkText
    property string url: ""
    textFormat: Text.PlainText
    color: linkArea.containsMouse ? root.foreground : root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.underline: linkArea.containsMouse
    elide: Text.ElideRight

    MouseArea {
      id: linkArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (linkText.url === "") return
        root.close()
        Quickshell.execDetached(["xdg-open", linkText.url])
      }
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    query = ""
    selectedIndex = 0
    actionStatus = ""
    historyFile.reload()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  FileView {
    id: historyFile
    path: root.historyPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadHistory(text())
    onLoadFailed: { root.history = []; root.rebuild() }
    onFileChanged: reload()
  }

  Process {
    id: actionProc
    onExited: function(code) {
      root.actionStatus = code === 0 ? "Copied" : "Copy failed"
      statusTimer.restart()
    }
  }

  Timer {
    id: statusTimer
    interval: 1800
    repeat: false
    onTriggered: root.actionStatus = ""
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    tooltipText: "Pastey · " + root.history.length + " of 200 clips"
    onPressed: function(code) {
      if (code === Qt.RightButton && displayModel.count > 0) root.restoreClipboard(null, false)
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          if (root.query !== "") root.setQuery("")
          else root.close()
          event.accepted = true
        } else if (event.key === Qt.Key_Up) {
          root.select(-1); event.accepted = true
        } else if (event.key === Qt.Key_Down) {
          root.select(1); event.accepted = true
        } else if (event.key === Qt.Key_Left) {
          root.cycleFilter(-1); event.accepted = true
        } else if (event.key === Qt.Key_Right) {
          root.cycleFilter(1); event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
          root.select(-root.visibleRowCount); event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
          root.select(root.visibleRowCount); event.accepted = true
        } else if (event.key === Qt.Key_Home) {
          root.selectedIndex = 0
          if (displayModel.count > 0) resultList.positionViewAtBeginning()
          event.accepted = true
        } else if (event.key === Qt.Key_End) {
          root.selectedIndex = Math.max(0, displayModel.count - 1)
          if (displayModel.count > 0) resultList.positionViewAtEnd()
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.restoreClipboard(null, true)
          event.accepted = true
        } else if (event.key === Qt.Key_Delete) {
          root.removeRow(); event.accepted = true
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
          root.switchPanel((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab ? -1 : 1)
          event.accepted = true
        } else if (Util.editsFilter(event, root.query)) {
          root.setQuery(Util.editedFilter(event, root.query))
          event.accepted = true
        } else if (event.text && event.text.length === 1
          && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
          // Typing. Must stay the last branch, so every named key above wins
          // first — Space would otherwise never reach the list. A Ctrl or Alt
          // chord arrives as its control character (Ctrl+U is \x15), which the
          // >= 32 test drops, so shortcuts never leak into the query.
          root.setQuery(root.query + event.text)
          event.accepted = true
        }
      }

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.space(14)

        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          BorderSurface {
            id: heroIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Style.space(54)
            implicitHeight: Style.space(48)
            width: implicitWidth
            height: implicitHeight
            radius: width / 2
            color: Style.selectedFillFor(root.foreground, Color.accent)
            borderSpec: Border.controlSpec("selected", root.foreground, Color.accent)

            Text {
              anchors.centerIn: parent
              text: ""
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              rotation: -22
            }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: "Pastey"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: (root.query !== ""
                ? displayModel.count + (displayModel.count === 1 ? " MATCH" : " MATCHES")
                : root.filter !== "all"
                  ? displayModel.count + " " + root.filterNoun(displayModel.count)
                  : root.history.length + " OF 200 CLIPS").toUpperCase()
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        BorderSurface {
          width: parent.width
          height: Style.space(38)
          radius: Style.cornerRadius
          color: Style.normalFillFor(root.foreground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(11)
            anchors.rightMargin: Style.space(11)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "󰍉"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.icon
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.space(34)
              text: root.query !== "" ? root.query : "Search 200 clips…"
              color: root.query !== "" ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: keyCatcher.forceActiveFocus()
          }
        }

        // Text / photos / both. A mode, not a search: it survives Escape
        // and stays put while the query is edited, so a user hunting for a
        // screenshot never has to re-pick it between searches.
        ButtonGroup {
          // No tooltips: the labels already say it, and the kit floats a
          // tooltip upward, straight over the search field.
          options: [
            { value: "all", label: "Both" },
            { value: "text", label: "Text" },
            { value: "image", label: "Photos" }
          ]
          value: root.filter
          // The row list owns the panel cursor; the chips must not paint a
          // second highlight, so the external cursor stays disabled and the
          // group stays out of the Tab chain Tab uses to switch panels.
          focusable: false
          cursorIndex: -1
          foreground: root.foreground
          accent: Color.accent
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          onChanged: function(value) {
            root.setFilter(value)
            keyCatcher.forceActiveFocus()
          }
        }

        PanelSectionHeader {
          text: root.query !== "" ? "SEARCH RESULTS"
            : root.filter === "image" ? "PICTURES"
            : root.filter === "text" ? "TEXT CLIPS" : "LATEST FIVE"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        ListView {
          id: resultList
          width: parent.width
          height: displayModel.count === 0
            ? root.rowHeight
            : Math.min(displayModel.count, root.visibleRowCount) * root.rowHeight
              + (Math.min(displayModel.count, root.visibleRowCount) - 1) * root.rowSpacing
          model: displayModel
          clip: true
          spacing: root.rowSpacing
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          currentIndex: root.selectedIndex
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          delegate: CursorSurface {
            id: row
            required property int index
            required property int historyIndex
            required property string entryType
            required property string category
            required property string previewText
            required property string detailText
            required property string previewImage

            width: ListView.view.width - (ListView.view.ScrollBar.vertical.visible ? Style.space(8) : 0)
            height: root.rowHeight
            hasCursor: index === root.selectedIndex
            foreground: root.foreground
            fill: Style.hoverFillFor(root.foreground, Color.accent)
            currentFill: Style.selectedFillFor(root.foreground, Color.accent)

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.selectedIndex = row.index
              onClicked: root.restoreClipboard(row, true)
              // The delegate MouseArea is the actual pointer event owner on
              // this ListView. Route the wheel from here instead of placing a
              // competing overlay above the Flickable.
              onWheel: function(wheel) {
                wheel.accepted = fastScroll.applyDeltas(
                  wheel.pixelDelta.y, wheel.angleDelta.y)
              }
            }

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(9)
              anchors.rightMargin: Style.space(7)
              spacing: Style.space(9)

              // A picture row shows the picture. Anything else keeps the round
              // category glyph, so the list still reads as one column of
              // equal-weight badges.
              Item {
                id: badge
                anchors.verticalCenter: parent.verticalCenter
                readonly property bool showsThumbnail: row.previewImage !== ""
                  && thumbnail.status !== Image.Error
                width: showsThumbnail ? Style.space(48) : Style.space(34)
                height: showsThumbnail ? Style.space(40) : Style.space(34)

                BorderSurface {
                  anchors.fill: parent
                  visible: !badge.showsThumbnail
                  radius: width / 2
                  color: Style.selectedFillFor(root.foreground, Color.accent)
                  borderSpec: Border.none()

                  Text {
                    anchors.centerIn: parent
                    text: row.category === "image" ? "󰋩"
                      : row.category === "file" ? "󰈔"
                      : row.category === "link" ? "󰌷"
                      : row.category === "code" ? "󰅩" : "󰦨"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.icon
                  }
                }

                Image {
                  id: thumbnail
                  anchors.fill: parent
                  visible: badge.showsThumbnail
                  source: row.previewImage !== "" ? "file://" + row.previewImage : ""
                  // Screenshots are full-screen PNGs. Decoding them at their
                  // native size for a 48px badge is what would make a 200-row
                  // list crawl, so the loader is capped and kept off the UI
                  // thread.
                  sourceSize.width: 160
                  sourceSize.height: 160
                  asynchronous: true
                  cache: true
                  fillMode: Image.PreserveAspectCrop
                  smooth: true
                  // An Item clips to its bounding box and ignores radius, so
                  // the rounded corner has to come from a mask.
                  layer.enabled: true
                  layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: thumbnailMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                  }
                }

                // The shape, never drawn itself: MultiEffect reads its alpha.
                Rectangle {
                  id: thumbnailMask
                  anchors.fill: parent
                  radius: Style.space(7)
                  color: "black"
                  visible: false
                  layer.enabled: true
                  layer.smooth: true
                }
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - badge.width - removeButton.width - parent.spacing * 2
                spacing: Style.space(1)

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: row.previewText
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: row.detailText.toUpperCase()
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 0.8
                  elide: Text.ElideRight
                }
              }

              CursorSurface {
                id: removeButton
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(28)
                height: width
                radius: width / 2
                hasCursor: removeMouse.containsMouse
                foreground: root.foreground
                fill: Util.alpha(root.urgent, 0.20)

                Text {
                  anchors.centerIn: parent
                  text: "×"
                  color: removeMouse.containsMouse ? root.urgent : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }

                MouseArea {
                  id: removeMouse
                  anchors.fill: parent
                  z: 2
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: function(mouse) {
                    mouse.accepted = true
                    root.removeRow(row)
                    keyCatcher.forceActiveFocus()
                  }
                }

                PanelToolTip {
                  visible: removeMouse.containsMouse
                  text: "Remove"
                  fontFamily: root.fontFamily
                }
              }
            }
          }

          Column {
            anchors.centerIn: parent
            spacing: Style.space(5)
            visible: displayModel.count === 0

            Text {
              width: parent.width
              text: root.query !== "" ? "󰍉" : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              width: parent.width
              text: root.query !== "" ? "No matching clips"
                : root.filter !== "all" ? "No " + root.filterNoun(0) + " yet"
                : "Clipboard is empty"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignHCenter
            }
          }

          // One shared policy is invoked by whichever visible row owns the
          // pointer. Keeping this controller non-visual avoids the failed
          // overlay-versus-Flickable routing race.
          FastScrollHandler {
            id: fastScroll
            flickable: resultList
            speedMultiplier: 4.0
            mouseWheelStep: Math.max(1,
              (Number(Application.styleHints.wheelScrollLines) || 3)
                * Math.max(1, Style.font.body))
          }
        }

        PanelSeparator { foreground: root.foreground }

        Text {
          width: parent.width
          text: root.actionStatus !== ""
            ? root.actionStatus
            : "Enter restores · Delete removes · ←/→ filter"
          color: root.actionStatus === "Copy failed" ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        // About: version, source, site. At the foot of the panel and in the
        // dim caption colour, so it never competes with the list — but always
        // present, because you should never have to open a file to learn
        // which Pastey you are looking at. A Flow, not a Row: the panel is
        // narrow enough that a long repo path has to be allowed to wrap.
        Flow {
          width: parent.width
          spacing: Style.space(5)

          Caption { text: "Pastey" + (root.pluginVersion !== "" ? " v" + root.pluginVersion : "") }
          Caption { text: "·"; visible: root.repoUrl !== "" }
          Link {
            visible: root.repoUrl !== ""
            text: root.repoUrl.replace(/^https?:\/\//, "")
            url: root.repoUrl
          }
          Caption { text: "·"; visible: root.homeUrl !== "" }
          Link {
            visible: root.homeUrl !== ""
            text: root.homeUrl.replace(/^https?:\/\//, "")
            url: root.homeUrl
          }
        }
      }
    }
  }
}
