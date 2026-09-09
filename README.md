<p align="center">
  <a href="#install"><img alt="Omarchy plugin" src="https://img.shields.io/badge/Omarchy-bar%20widget-43f2a1?style=flat-square&labelColor=0b141d"></a>
  <a href="LICENSE"><img alt="MIT" src="https://img.shields.io/badge/license-MIT-efcc45?style=flat-square&labelColor=0b141d"></a>
  <a href="#what-it-does"><img alt="200 clips" src="https://img.shields.io/badge/history-200%20clips-63c89e?style=flat-square&labelColor=0b141d"></a>
  <a href="#how-it-shares-omarchys-history"><img alt="No second watcher" src="https://img.shields.io/badge/watchers-zero%20added-7fb3d5?style=flat-square&labelColor=0b141d"></a>
</p>

# Pastey

A clipboard that remembers. Two hundred clips behind a paperclip on the Omarchy
bar, searchable the moment you start typing, with real thumbnails for the
screenshots and the whole clip on hover.

Pastey speaks Omarchy's own popup vocabulary — a small status hero, section
labels, keyboard cursor surfaces, theme-native colour, and a panel anchored
directly to its bar icon. It looks like the Bluetooth panel because it is built
out of the same parts.

## What it does

- Keeps the newest 200 Omarchy clipboard entries
- Shows five rows at a time and fast-scrolls through the full history
- Shows a real thumbnail for copied pictures — captured images and single copied
  image files — so a screenshot is recognisable without opening it
- Searches all retained text, file paths, and image metadata as you type
- Filters the list to text only, photos only, or both, from a toggle under
  the search field — the choice sticks while you search and until you change it
- Shows the whole clip on hover, so a row that has to elide to one line is
  still readable in full, newlines intact, with the picture itself for a photo
- Restores an item to the clipboard on click or Enter; it never types into an app
- Copies the latest visible item with a right-click on the bar icon
- Removes every visible item with its × button or the Delete key
- Carries its version, source and nixfred.com as one dim line at the foot of the
  panel, so you never have to open a file to learn which build you are running

## How it shares Omarchy's history

Pastey reads the clipboard history file Omarchy already maintains rather than
launching a second `wl-paste` watcher. Nothing new listens to your selections.
The built-in `Super+Ctrl+V` manager keeps working and sees exactly the same
entries, so the two are views of one history rather than rival copies of it.

Where the two disagree is length. The stock recorder keeps a deliberately larger
general-purpose history; Pastey owns the tighter 200-entry contract and trims the
shared file whenever a capture pushes it past that.

## Install

```sh
omarchy plugin add https://github.com/nixfred/Pastey.git --enable --yes
omarchy bar move nixfred.pastey --section right
```

From a local checkout:

```sh
omarchy plugin add file:///absolute/path/to/Pastey --enable --yes
omarchy bar move nixfred.pastey --section right
```

## Keyboard

- Type to search; Backspace edits and Escape clears
- Up/Down and Page Up/Page Down move through results
- Left/Right cycle the both / text / photos filter
- Enter restores the selected item to the clipboard and closes Pastey
- Delete removes the selected item
- Escape closes when search is empty

## Requirements

Pastey targets Omarchy 4 and uses the clipboard tooling Omarchy already ships:
`jq` and `wl-copy`. No additional packages, no service to enable, no state of
its own.

## Test

```sh
node tests/model.test.js
node tests/scroll-policy.test.js
bash tests/action.test.sh
omarchy plugin validate .
```
