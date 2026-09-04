# Pastey

Pastey is a compact clipboard-history panel for the Omarchy bar. It uses the
same popup vocabulary as Omarchy's Bluetooth panel: a small status hero,
section labels, keyboard cursor surfaces, theme-native colors, and a panel
anchored directly to its bar icon.

## What it does

- Keeps the newest 200 Omarchy clipboard entries
- Shows five rows at a time and fast-scrolls through the full history
- Searches all retained text, file paths, and image metadata as you type
- Restores an item to the clipboard on click or Enter; it never types into an app
- Copies the latest visible item with a right-click on the bar icon
- Removes every visible item with its × button or the Delete key
- Uses a paperclip icon and defaults to the right side of the bar

Pastey shares Omarchy's built-in clipboard history file rather than launching a
second `wl-paste` watcher. The built-in `Super+Ctrl+V` clipboard manager remains
available and sees the same 200-entry history.

## Install

From the private GitHub repository (GitHub access required):

```bash
omarchy plugin add https://github.com/nixfred/Pastey.git --enable --yes
omarchy bar move nixfred.pastey --section right
```

From a local checkout:

```bash
omarchy plugin add file:///absolute/path/to/Pastey --enable --yes
omarchy bar move nixfred.pastey --section right
```

## Keyboard

- Type to search; Backspace edits and Escape clears
- Up/Down and Page Up/Page Down move through results
- Enter restores the selected item to the clipboard and closes Pastey
- Delete removes the selected item
- Escape closes when search is empty

## Requirements

Pastey targets Omarchy 4 and uses the clipboard tooling Omarchy already ships:
`jq` and `wl-copy`.

## Test

```bash
node tests/model.test.js
node tests/scroll-policy.test.js
bash tests/action.test.sh
omarchy plugin validate .
```
