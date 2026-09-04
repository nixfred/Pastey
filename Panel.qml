import QtQuick
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

  property var history: []
  property string query: ""
  property int selectedIndex: 0
  property string actionStatus: ""

  ListModel { id: displayModel }

  function rebuild() {
    var rows = Model.displayRows(history, query, historyLimit)
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

        PanelSectionHeader {
          text: root.query !== "" ? "SEARCH RESULTS" : "LATEST FIVE"
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

              BorderSurface {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(34)
                height: width
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

              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(34) - removeButton.width - parent.spacing * 2
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
              text: root.query !== "" ? "No matching clips" : "Clipboard is empty"
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
            : "Click or Enter restores clipboard · Delete remove"
          color: root.actionStatus === "Copy failed" ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }
}
