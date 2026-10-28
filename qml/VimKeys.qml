import QtQuick

// VimKeys -- a small vim-style key parser for the file view.
//
// The parser owns no state the UI needs except the count / pending prefix /
// visual flag, and it never touches the panes itself: `feed()` returns
// { action, count, extend } and main.qml runs that action through the same
// command table the command palette uses.
//
// Bindings are intentionally ranger/yazi-like: h goes to the parent folder and
// l opens the selection, because the file grid is not a text buffer.
QtObject {
    id: vim

    // Visual mode: motions extend the selection instead of replacing it.
    property bool visual: false
    // Digits typed before a motion ("12j"); 0 means "none".
    property int count: 0
    // Pending multi-key prefix ("g", "d", "y").
    property string prefix: ""

    function reset() {
        visual = false;
        count = 0;
        prefix = "";
    }

    function takeCount() {
        var n = count;
        count = 0;
        return n;
    }

    function pending() {
        return { pending: true };
    }

    // Returns null when the key is not part of the vim layer, so the normal
    // shortcut handling can still see it.
    function feed(key, text, modifiers) {
        var ctrl = (modifiers & Qt.ControlModifier) !== 0;
        var alt = (modifiers & (Qt.AltModifier | Qt.MetaModifier)) !== 0;

        if (ctrl) {
            if (key === Qt.Key_D) return { action: "nav.halfDown" };
            if (key === Qt.Key_U) return { action: "nav.halfUp" };
            return null;
        }
        if (alt)
            return null;

        var t = (text && text.length === 1) ? text : "";
        if (t.length === 0 && key >= Qt.Key_A && key <= Qt.Key_Z)
            t = String.fromCharCode(key + 32);
        if (t.length !== 1)
            return null;

        if (prefix === "g") {
            prefix = "";
            var g = takeCount();
            switch (t) {
            case "g": return { action: "nav.top", count: g };
            case "t": return { action: "tab.next" };
            case "T": return { action: "tab.prev" };
            case "h": return { action: "go.home" };
            case "p": return { action: "go.pc" };
            case "s": return { action: "go.settings" };
            case "r": return { action: "go.recent" };
            case "d": return { action: "go.trash" };
            case "/": return { action: "search.global" };
            case "f": return { action: "path.edit" };
            case ".": return { action: "files.hidden" };
            case "n": return { action: "files.newFolder" };
            }
            return null;
        }

        if (prefix === "d") {
            prefix = "";
            takeCount();
            return t === "d" ? { action: "files.trash" } : null;
        }

        if (prefix === "y") {
            prefix = "";
            takeCount();
            return t === "y" ? { action: "files.copy" } : null;
        }

        if (t >= "0" && t <= "9") {
            if (t === "0" && count === 0)
                return { action: "nav.top" };
            count = Math.min(999, count * 10 + parseInt(t, 10));
            return pending();
        }

        var n = takeCount();
        switch (t) {
        case "j": return { action: "nav.down", count: n || 1, extend: visual };
        case "k": return { action: "nav.up", count: n || 1, extend: visual };
        case "h": return { action: "nav.parent" };
        case "l": return { action: "nav.open" };
        case "H": return { action: "nav.back" };
        case "L": return { action: "nav.forward" };
        case "G": return n > 0 ? { action: "nav.row", count: n } : { action: "nav.bottom" };
        case "o": return { action: "nav.open" };
        case "O": return { action: "tab.openSelection" };
        case "t": return { action: "tab.new" };
        case "r": return { action: "files.rename" };
        case "R": return { action: "files.refresh" };
        case "a": return { action: "files.newFolder" };
        case "A": return { action: "files.newFile" };
        case "x": return { action: "files.cut" };
        case "p": return { action: "files.paste" };
        case "u": return { action: "edit.undo" };
        case "m": return { action: "files.bookmark" };
        case "v":
            visual = !visual;
            return { action: visual ? "visual.start" : "visual.stop" };
        case "s": return { action: "view.toggleSplit" };
        case "S": return { action: "view.otherPane" };
        case ".": return { action: "files.hidden" };
        case "/": return { action: "search.focus" };
        case "?": return { action: "help.open" };
        case ":": return { action: "palette.open" };
        case "V": return { action: "files.selectAll" };
        case "~": return { action: "go.home" };
        case "D": return { action: "files.delete" };
        case "g": prefix = "g"; count = n; return pending();
        case "d": prefix = "d"; count = n; return pending();
        case "y": prefix = "y"; count = n; return pending();
        }
        return null;
    }
}
