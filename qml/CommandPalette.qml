import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

// CommandPalette -- fuzzy command launcher ("Ctrl+Shift+P" or ":").
//
// main.qml owns the command table (title, section, keys, vim and the function
// that runs it); the palette only filters and reports the chosen id, so the
// palette, the vim layer and the cheat sheet can never drift apart.
Popup {
    id: palette

    property var commands: []
    property var results: []
    property int currentIndex: 0
    property string query: ""
    property string prefix: ""

    signal triggered(string commandId)

    width: Math.min(660, (parent ? parent.width : 900) - 120)
    height: Math.min(460, (parent ? parent.height : 700) - 120)
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: Overlay.overlay
    padding: 0

    Overlay.modal: Rectangle { color: "#00000066" }

    background: Rectangle {
        radius: theme.radiusXl
        color: theme.surfaceContainerHigh
        border.width: 1
        border.color: theme.borderSubtle
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 120; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.97; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
        }
    }

    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 100; easing.type: Easing.InCubic }
    }

    transformOrigin: Item.Center

    function openPalette(pre) {
        prefix = pre || "";
        query = "";
        currentIndex = 0;
        rebuild();
        open();
    }

    function move(delta) {
        if (results.length === 0)
            return;
        currentIndex = Math.max(0, Math.min(results.length - 1, currentIndex + delta));
        list.positionViewAtIndex(currentIndex, ListView.Contain);
    }

    function activate() {
        if (currentIndex < 0 || currentIndex >= results.length)
            return;
        var id = results[currentIndex].id;
        close();
        palette.triggered(id);
    }

    // Subsequence scoring with a bonus for word starts and consecutive hits.
    function score(haystack, needle) {
        var h = haystack.toLowerCase();
        var n = needle.toLowerCase();
        if (n.length === 0)
            return 1;
        var hi = 0;
        var score = 0;
        var streak = 0;
        for (var i = 0; i < n.length; ++i) {
            var at = h.indexOf(n.charAt(i), hi);
            if (at < 0)
                return -1;
            streak = (at === hi) ? streak + 1 : 0;
            score += 10 + streak * 6 - Math.min(6, at - hi);
            hi = at + 1;
        }
        if (h.indexOf(n) === 0)
            score += 40;
        else if (h.indexOf(" " + n) >= 0)
            score += 20;
        return score;
    }

    function rebuild() {
        var q = query.trim();
        var found = [];
        for (var i = 0; i < commands.length; ++i) {
            var cmd = commands[i];
            if (cmd.hidden === true)
                continue;
            if (cmd.enabled && !cmd.enabled())
                continue;
            var haystack = cmd.section + " " + cmd.title;
            var s = q.length === 0 ? 1 : Math.max(score(cmd.title, q), score(haystack, q));
            if (s < 0)
                continue;
            found.push({
                id: cmd.id,
                title: cmd.title,
                section: cmd.section,
                keys: (typeof window !== "undefined" && window && window.displayKeys)
                      ? window.displayKeys(cmd.id, cmd.keys || "") : (cmd.keys || ""),
                vim: (typeof theme !== "undefined" && theme && theme.keyMode === "vim") ? (cmd.vim || "") : "",
                score: s
            });
        }
        if (q.length > 0)
            found.sort(function(a, b) { return b.score - a.score; });

        var lastSection = "";
        for (var j = 0; j < found.length; ++j) {
            var item = found[j];
            item.showSection = q.length === 0 && item.section !== lastSection;
            lastSection = item.section;
            found[j] = item;
        }
        results = found;
        currentIndex = 0;
    }

    onQueryChanged: rebuild()
    onOpened: {
        field.text = prefix;
        field.forceActiveFocus();
        field.cursorPosition = field.text.length;
        rebuild();
    }
    onClosed: query = ""

    contentItem: ColumnLayout {
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            Layout.topMargin: 14
            Layout.bottomMargin: 10
            spacing: 10

            LoafIcon {
                name: "command"
                size: 18
                color: theme.primary
            }

            TextField {
                id: field
                Layout.fillWidth: true
                placeholderText: qsTr("Type a command…")
                color: theme.textMain
                placeholderTextColor: theme.outline
                selectionColor: theme.primary
                selectedTextColor: theme.primaryFg
                font.pixelSize: theme.fs(15)
                background: null
                leftPadding: 0
                rightPadding: 0
                topPadding: 6
                bottomPadding: 6
                Accessible.name: qsTr("Command search")

                onTextChanged: palette.query = text

                Keys.onPressed: function(event) {
                    var ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                    if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_N)) {
                        palette.move(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_P)) {
                        palette.move(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageDown) {
                        palette.move(8);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageUp) {
                        palette.move(-8);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        palette.activate();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        palette.close();
                        event.accepted = true;
                    }
                }
            }

            Text {
                text: palette.results.length + qsTr(" results")
                color: theme.outline
                font.pixelSize: theme.fs(11)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.separator
            opacity: 0.6
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 6
            Layout.bottomMargin: 6
            clip: true
            model: palette.results
            currentIndex: palette.currentIndex
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 6 }

            delegate: Item {
                id: row
                required property var modelData
                required property int index

                width: list.width
                height: (modelData.showSection ? 30 : 0) + 46

                Text {
                    visible: row.modelData.showSection
                    text: row.modelData.section
                    color: theme.outline
                    font.pixelSize: theme.fs(10)
                    font.letterSpacing: 0.8
                    font.capitalization: Font.AllUppercase
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    anchors.top: parent.top
                    anchors.topMargin: 10
                }

                Rectangle {
                    id: pill
                    x: 10
                    y: row.modelData.showSection ? 30 : 0
                    width: row.width - 20
                    height: 42
                    radius: theme.radiusM
                    color: row.index === palette.currentIndex ? theme.secondaryContainer
                        : (rowMouse.containsMouse ? theme.hoverOverlay : "transparent")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        LoafIcon {
                            name: "arrow-right"
                            size: 14
                            color: row.index === palette.currentIndex ? theme.secondaryContainerFg : theme.outline
                            opacity: row.index === palette.currentIndex ? 1.0 : 0.0
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.title
                            color: row.index === palette.currentIndex ? theme.secondaryContainerFg : theme.textMain
                            font.pixelSize: theme.fs(13)
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: row.modelData.vim.length > 0
                            text: row.modelData.vim
                            color: theme.primary
                            font.pixelSize: theme.fs(11)
                            font.family: "monospace"
                        }

                        Rectangle {
                            visible: row.modelData.keys.length > 0
                            implicitWidth: keyLabel.implicitWidth + 12
                            implicitHeight: 20
                            radius: 6
                            color: theme.surfaceContainerHighest
                            border.width: 1
                            border.color: theme.outlineVariant

                            Text {
                                id: keyLabel
                                anchors.centerIn: parent
                                text: row.modelData.keys
                                color: theme.textMuted
                                font.pixelSize: theme.fs(10)
                                font.family: "monospace"
                            }
                        }
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        palette.currentIndex = row.index;
                        palette.activate();
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: theme.surfaceContainer
            radius: 0

            Text {
                anchors.centerIn: parent
                text: qsTr("↑ ↓ navigate    Enter run    Esc close")
                color: theme.outline
                font.pixelSize: theme.fs(10)
            }
        }
    }
}
