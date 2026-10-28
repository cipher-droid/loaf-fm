import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

// KeyHelp -- the in-app keyboard cheat sheet ("?").
//
// Rows come from the same command table the palette uses, so a binding can
// never be documented in one place and behave differently in another.
Popup {
    id: help

    property var commands: []
    property var rows: []

    width: Math.min(820, (parent ? parent.width : 1000) - 140)
    height: Math.min(660, (parent ? parent.height : 800) - 120)
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

    function openHelp() {
        rebuild();
        open();
    }

    function rebuild() {
        var out = [];
        var lastSection = "";
        for (var i = 0; i < commands.length; ++i) {
            var cmd = commands[i];
            if (cmd.showInHelp === false)
                continue;
            var vimOn = typeof theme !== "undefined" && theme && theme.keyMode === "vim";
            var keyLabel = (typeof window !== "undefined" && window && window.displayKeys)
                    ? window.displayKeys(cmd.id, cmd.keys || "") : (cmd.keys || "");
            var vimLabel = vimOn ? (cmd.vim || "") : "";
            if (!keyLabel && !vimLabel)
                continue;
            out.push({
                title: cmd.title,
                section: cmd.section,
                keys: keyLabel,
                vim: vimLabel,
                showSection: cmd.section !== lastSection
            });
            lastSection = cmd.section;
        }
        rows = out;
    }

    onOpened: {
        keyCatcher.forceActiveFocus();
        list.positionViewAtBeginning();
    }

    contentItem: ColumnLayout {
        spacing: 0

        Item {
            id: keyCatcher
            Layout.fillWidth: true
            Layout.preferredHeight: 0
            focus: true

            Keys.onPressed: function(event) {
                var page = Math.max(1, Math.floor(list.height / 34) - 1);
                if (event.key === Qt.Key_Down) {
                    list.flick(0, -120);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    list.flick(0, 120);
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageDown) {
                    list.flick(0, -120 * page);
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageUp) {
                    list.flick(0, 120 * page);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Question || event.text === "?") {
                    help.close();
                    event.accepted = true;
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.topMargin: 20
            Layout.bottomMargin: 14
            spacing: 12

            LoafIcon {
                name: "keyboard"
                size: 22
                color: theme.primary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: qsTr("Keyboard shortcuts")
                    color: theme.textMain
                    font.pixelSize: theme.fs(18)
                    font.bold: true
                }

                Text {
                    text: (typeof theme !== "undefined" && theme && theme.keyMode === "vim")
                          ? qsTr("Vim mode: motions, counts (3j, 5G) and visual mode are active. Esc leaves visual mode.")
                          : qsTr("Normal mode: classic shortcuts. Switch to Vim in Settings → Behavior → Keyboard for motions.")
                    color: theme.textMuted
                    font.pixelSize: theme.fs(11)
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
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
            model: help.rows
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 6 }

            delegate: Item {
                id: row
                required property var modelData

                width: list.width
                height: (modelData.showSection ? 34 : 0) + 34

                Text {
                    visible: row.modelData.showSection
                    text: row.modelData.section
                    color: theme.primary
                    font.pixelSize: theme.fs(10)
                    font.letterSpacing: 1.0
                    font.capitalization: Font.AllUppercase
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.top: parent.top
                    anchors.topMargin: 14
                }

                RowLayout {
                    y: row.modelData.showSection ? 34 : 0
                    width: row.width - 48
                    x: 24
                    height: 34
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.title
                        color: theme.textMain
                        font.pixelSize: theme.fs(12)
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
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: theme.surfaceContainer

            Text {
                anchors.centerIn: parent
                text: qsTr("j / k scroll    Esc close    Ctrl+Shift+P command palette")
                color: theme.outline
                font.pixelSize: theme.fs(10)
            }
        }
    }
}
