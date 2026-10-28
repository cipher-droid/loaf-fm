# Keyboard reference

Loaf is designed to be usable without a mouse. Everything in this file is
available from the keyboard, and the same command table drives the vim layer,
the command palette and the in-app cheat sheet, so the three can never drift
apart.

Press `?` (or `F1`) at any time to see the cheat sheet, and `Ctrl+Shift+P`
to open the command palette.

Loaf has two key modes, switched in **Settings → Behavior → Keyboard**:

- **Normal** (default): the classic shortcuts below, and typing a letter filters
  the current folder.
- **Vim**: motions, counts and visual mode, with `/`, `:` and `?` on the file
  view. `Ctrl` + `d` pages down, so bookmarks move to `Ctrl` + `Shift` + `D`,
  and `Ctrl` + `H` focuses the sidebar (`Ctrl` + `Shift` + `H` toggles hidden
  files).

The cheat sheet only shows the keys for the mode you are in.

## Command palette

| Key | Action |
| :--- | :--- |
| `Ctrl` + `Shift` + `P`, or `:` | Open the command palette |
| Type | Fuzzy search over every command |
| `Up` / `Down`, `Ctrl` + `P` / `Ctrl` + `N` | Move the selection |
| `PageUp` / `PageDown` | Move a page at a time |
| `Enter` | Run the selected command |
| `Esc` | Close |

Commands that need a selection or a writable folder are hidden while they
cannot run, so the list only offers things that will work.

## Vim mode

Vim mode is opt-in (**Settings → Behavior → Keyboard**). In Normal mode the
same letters filter the current folder instead.

### Motions

| Key | Action |
| :--- | :--- |
| `j` / `k` | Down / up |
| `h` | Move left in the grid; at the left edge, parent folder |
| `l` | Move right in the grid; at the right edge, open the selection |
| `o`, `Enter` | Open the selection |
| `H` / `L` | Back / forward in history |
| `gg`, `0` | First item |
| `G` | Last item |
| `5G` | Item number 5 |
| `12j`, `3k` | Move by a count |
| `Ctrl` + `d` / `Ctrl` + `u` | Half page down / up |
| `PageDown` / `PageUp` | Full page down / up |
| `Home` / `End` | First / last item |
| `v` | Toggle visual mode (motions extend the selection) |
| `Esc` | Leave visual mode, clear selection, leave the sidebar |

### Files

| Key | Action |
| :--- | :--- |
| `r` | Rename |
| `dd` | Move to trash |
| `D` | Delete permanently |
| `yy` | Copy |
| `x` | Cut |
| `p` | Paste |
| `Y` | Copy path |
| `a` / `A` | New folder / new file |
| `m` | Bookmark this folder |
| `V` | Select all |
| `Space` | Quick look |
| `R` | Reload the folder |
| `.` | Toggle hidden files |
| `u` | Undo |
| `O` | Open the selection in a new tab |

### Tabs, panes and views

| Key | Action |
| :--- | :--- |
| `t` / `Ctrl` + `T` | New tab |
| `Ctrl` + `W` | Close tab |
| `gt` / `gT` | Next / previous tab |
| `Alt` + `1` … `9` | Jump to a tab |
| `s` / `F3` | Toggle split view |
| `S` | Focus the other pane |
| `Ctrl` + `B` (vim: also `Ctrl` + `H`) | Focus the sidebar (`j`/`k`, `Enter`, `Esc`) |
| `F9` | Expand / collapse the sidebar |
| `Ctrl` + `1` / `Ctrl` + `2` | Grid / list view |
| `Ctrl` + `+` / `-` / `0` | Icon size |

### Places and search

| Key | Action |
| :--- | :--- |
| `gh` | Home |
| `gp` | This PC |
| `gs` | Settings |
| `gr` | Recent |
| `gd` | Trash |
| `gf` | Edit the path bar |
| `/` | Filter this folder |
| `g/` | Search everywhere |
| `:` | Command palette |
| `?` | This cheat sheet |

## Everything else

| Key | Action |
| :--- | :--- |
| `Ctrl` + `F` | Filter this folder |
| `Ctrl` + `L` | Edit the path bar |
| `Ctrl` + `A` | Select all |
| `Ctrl` + `Shift` + `I` | Invert selection |
| `Ctrl` + `S` | Select by pattern |
| `Ctrl` + `C` / `X` / `V` | Copy / cut / paste |
| `Ctrl` + `Shift` + `C` | Copy path |
| `Ctrl` + `D` (vim: `Ctrl` + `Shift` + `D`) | Bookmark this folder |
| `Ctrl` + `H` (vim: `Ctrl` + `Shift` + `H` or `.`) | Toggle hidden files |
| `Ctrl` + `Z` / `Ctrl` + `Shift` + `Z` | Undo / redo |
| `Shift` + `F10` | Context menu for the selection |
| `Alt` + `Enter` | Properties |
| `F2` | Rename (several selected: batch rename) |
| `Delete` / `Shift` + `Delete` | Trash / delete permanently |
| `Ctrl` + `N` | New window |
| `Ctrl` + `Q` | Close window |
| `F1` | Keyboard cheat sheet |

## Dialogs

`Enter` or `Space` activates the focused button, `Esc` closes the dialog, and
`Tab` moves between buttons. Confirmation dialogs focus the confirm button, so
`Enter` accepts and `Esc` cancels.
