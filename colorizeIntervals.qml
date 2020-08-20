// SPDX-License-Identifier: MIT
// Copyright (c) 2020 Philipp Naumann
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software
// and associated documentation files (the "Software"), to deal in the Software without restriction,
// including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice (including the next paragraph) shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
// LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
// NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Description
//
// This plugin colorizes intervals across all staves and voices. One of its use cases is finding
// consecutive fifths and octaves.

// Screenshots
// - UI: https://raw.githubusercontent.com/bitflipp/musescore/master/colorizeIntervals.ui.png
// - Result of using the plugin on https://musescore.com/user/31664190/scores/5672016, bars 216-218,
//   7 semitones, highlight color #ff0000: https://raw.githubusercontent.com/bitflipp/musescore/master/colorizeIntervals.example.png

import MuseScore 3.0
import QtQuick 2.0
import QtQuick.Controls 2.1
import QtQuick.Dialogs 1.1
import QtQuick.Layouts 1.1
import QtQuick.Window 2.2

MuseScore {
    property var semitones: 7
    property var highlightColor: "#ff0000"
    property var selectedNotes
    
    function getSelectedNotes() {
        var cursor = curScore.newCursor();
        cursor.rewind(Cursor.SELECTION_START);

        var startStaffIdx, endStaffIdx, endTick;
        if (cursor.segment) {
            startStaffIdx = cursor.staffIdx;
            cursor.rewind(Cursor.SELECTION_END);
            endStaffIdx = cursor.staffIdx;
            endTick = cursor.tick;
        } else {
           startStaffIdx = 0;
           cursor.rewind(Cursor.SELECTION_END);
           endStaffIdx = curScore.nstaves;
           endTick = cursor.tick || curScore.lastSegment.tick + 1;
        }

        var selectedNotes = [];
        var lastTick;
        var lastTickNotes = [];
        for (var staffIdx = startStaffIdx; staffIdx <= endStaffIdx; staffIdx++) {
            for (var voice = 0; voice < 4; voice++) {
                cursor.rewind(Cursor.SELECTION_START);
                cursor.voice = voice;
                cursor.staffIdx = staffIdx;
                while (cursor.segment && cursor.tick < endTick) {
                    if (!cursor.element || cursor.element.type !== Element.CHORD) {
                        cursor.next();
                        continue;
                    }
                    for (var i = 0; i < lastTickNotes.length; i++) {
                        lastTickNotes[i].endTick = cursor.tick;
                    }
                    lastTickNotes = [];
                    var chord = cursor.element;
                    var notes = chord.notes;
                    for (var i = 0; i < notes.length; i++) {
                        var note = {
                            "startTick": cursor.tick,
                            "note": notes[i]
                        };
                        selectedNotes.push(note);
                        lastTickNotes.push(note);
                    }
                    cursor.next();
                }
            }
        }
        
        return selectedNotes;
    }

    function processSelectedNotes() {
        curScore.startCmd();
        for (var i = 0; i < selectedNotes.length; i++) {
            var note1 = selectedNotes[i];
            for (var j = i + 1; j < selectedNotes.length; j++) {
                var note2 = selectedNotes[j];
                var notesOverlap = note1.startTick < note2.endTick && note2.startTick < note1.endTick;
                if (!notesOverlap) {
                    continue;
                }

                var currentSemitones = Math.abs(note1.note.pitch - note2.note.pitch) % 12;
                if (currentSemitones !== semitones) {
                    continue;
                }

                note1.note.color = highlightColor;
                note2.note.color = highlightColor;
            }
        }
        curScore.endCmd();
    }

    menuPath: "Plugins.Proof Reading.Colorize Intervals"
    description: "Colorizes intervals across all staffs and voices."
    version: "1.0.0"
    onRun: {
        selectedNotes = getSelectedNotes();
        if (selectedNotes.length < 2) {
            messageDialog.text = "Please select at least 2 notes.";
            messageDialog.icon = StandardIcon.Critical;
            messageDialog.visible = true;
            return;
        }
        window.visible = true;
    }
    
    MessageDialog {
        id: messageDialog
        title: "Colorize Intervals"
        onAccepted: Qt.quit()
    }
    
    ColorDialog {
        id: colorDialog
        title: "Highlight color"
        color: highlightColor
        onAccepted: highlightColor = colorDialog.color
    }
    
    Window {
        id: window
        width: 400
        height: 200
        title: "Colorize Intervals"
        onClosing: Qt.quit()
        
        ColumnLayout {
            spacing: 10
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10

            RowLayout {
                Text {
                    text: "Semitones (modulo 12):"
                }

                Slider {
                    from: 0
                    value: 7
                    to: 11
                    stepSize: 1
                    snapMode: Slider.SnapAlways
                    Layout.fillWidth: true
                    onMoved: {
                        textSemitones.text = value;
                        semitones = value;
                    }
                }

                Text {
                    id: textSemitones
                    text: semitones
                }
            }

            RowLayout {
                Text {
                    text: "Highlight color:"
                }

                Button {
                    text: highlightColor
                    Layout.fillWidth: true
                    onClicked: colorDialog.open()
                }
            }
            
            Button {
                text: "OK"
                Layout.fillWidth: true
                onClicked: {
                    processSelectedNotes();
                    window.visible = false;
                    Qt.quit();
                }
            }
        }
    }
}
