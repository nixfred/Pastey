# Pastey

Pastey is a compact clipboard-history panel for the Omarchy bar. It uses the
same popup vocabulary as Omarchy's Bluetooth panel: a small status hero,
section labels, keyboard cursor surfaces, theme-native colors, and a panel
anchored directly to its bar icon.

## What it does

- Keeps the newest 200 Omarchy clipboard entries
- Shows five rows at a time and scrolls through the full history
- Searches all retained text, file paths, and image metadata as you type
- Pastes an item on click or Enter
- Copies an item with Shift+Enter or a right-click on the bar icon
- Removes every visible item with its × button or the Delete key
- Uses a paperclip icon and defaults to the right side of the bar

Pastey shares Omarchy's built-in clipboard history file rather than launching a
second `wl-paste` watcher. The built-in `Super+Ctrl+V` clipboard manager remains
available and sees the same 200-entry history.

## Install

```bash
omarchy plugin add https://github.com/nixfred/Pastey.git --enable
omarchy bar move nixfred.pastey --section right
```

For a local checkout:

```bash
omarchy plugin add file:///absolute/path/to/Pastey --enable --yes
omarchy bar move nixfred.pastey --section right
```

## Keyboard

- Type to search; Backspace edits and Escape clears
- Up/Down and Page Up/Page Down move through results
- Enter pastes; Shift+Enter copies
- Delete removes the selected item
- Escape closes when search is empty

## Requirements

Pastey targets Omarchy 4 and uses the clipboard tooling Omarchy already ships:
`jq`, `wl-copy`, and `wtype`.

## Test

```bash
node tests/model.test.js
omarchy plugin validate .
```
