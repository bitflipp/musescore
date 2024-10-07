

/*

SPDX-License-Identifier: MIT
Copyright (c) 2024 Philipp Naumann

Permission is hereby granted, free of charge, to any person obtaining a copy of this software
and associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:
The above copyright notice and this permission notice (including the next paragraph) shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
import MuseScore 3.0
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window

MuseScore {
    version: "1.1.0"
    description: "Colorizes intervals across all staffs and voices."
    title: "Colorize intervals"
    categoryCode: "composing-arranging-tools"
    onRun: {
        selectedNotes = getSelectedNotes()
        if (selectedNotes.length < 2) {
            messageDialog.text = "Please select at least 2 notes."
            messageDialog.icon = StandardIcon.Critical
            messageDialog.visible = true
            return
        }
        window.visible = true
    }

    property var semitones: 7
    property var defaultNoteColor: "#000000"
    property var highlightColors: [defaultNoteColor, "#bfbfff", "#a3a3ff", "#7879ff", "#4949ff", "#1f1fff", "#0000ff"]
    property var selectedNotes

    function getSelectedNotes() {
        var cursor = curScore.newCursor()
        cursor.rewind(Cursor.SELECTION_START)
        var startStaffIdx, endStaffIdx, endTick
        if (cursor.segment) {
            startStaffIdx = cursor.staffIdx
            cursor.rewind(Cursor.SELECTION_END)
            endStaffIdx = cursor.staffIdx
            endTick = cursor.tick
        } else {
            startStaffIdx = 0
            cursor.rewind(Cursor.SELECTION_END)
            endStaffIdx = curScore.nstaves
            endTick = cursor.tick || curScore.lastSegment.tick + 1
        }
        var selectedNotes = []
        for (var staffIdx = startStaffIdx; staffIdx <= endStaffIdx; staffIdx++) {
            for (var voice = 0; voice < 4; voice++) {
                cursor.rewind(Cursor.SELECTION_START)
                cursor.voice = voice
                cursor.staffIdx = staffIdx
                while (cursor.segment && cursor.tick < endTick) {
                    if (!cursor.element || cursor.element.type !== Element.CHORD) {
                        cursor.next()
                        continue
                    }
                    var chord = cursor.element
                    var notes = chord.notes
                    for (var i = 0; i < notes.length; i++) {
                        var note = {
                            "startTick": cursor.tick,
                            "note": notes[i],
                            "endTick": cursor.tick + chord.actualDuration.ticks
                        }
                        selectedNotes.push(note)
                    }
                    cursor.next()
                }
            }
        }
        return selectedNotes
    }

    function nextHighlightColor(color) {
        for (var i = 0; i < highlightColors.length - 1; i++) {
            if (highlightColors[i] == color)
                return highlightColors[i + 1]
        }
        return highlightColors[highlightColors.length - 1]
    }

    function processSelectedNotes() {
        curScore.startCmd()
        for (var i = 0; i < selectedNotes.length; i++) {
            selectedNotes[i].note.color = defaultNoteColor
        }
        for (var i = 0; i < selectedNotes.length; i++) {
            var note1 = selectedNotes[i]
            for (var j = i + 1; j < selectedNotes.length; j++) {
                var note2 = selectedNotes[j]
                var notesOverlap = note1.startTick < note2.endTick && note2.startTick < note1.endTick
                if (!notesOverlap) {
                    continue
                }
                var currentSemitones = Math.abs(note1.note.pitch - note2.note.pitch) % 12
                if (currentSemitones !== semitones) {
                    continue
                }
                note1.note.color = nextHighlightColor(note1.note.color)
                note2.note.color = nextHighlightColor(note2.note.color)
            }
        }
        curScore.endCmd()
    }

    MessageDialog {
        id: messageDialog
        title: "Colorize Intervals"
        onAccepted: Qt.quit()
    }

    Window {
        id: window
        width: 400
        height: 75
        title: "Colorize Intervals"
        onClosing: Qt.quit()

        ColumnLayout {
            spacing: 15
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.bottomMargin: 10

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
                        textSemitones.text = value
                        semitones = value
                    }
                }

                Text {
                    id: textSemitones
                    text: semitones
                }
            }

            Button {
                text: "OK"
                Layout.fillWidth: true
                Layout.fillHeight: true
                onClicked: {
                    processSelectedNotes()
                    window.visible = false
                    Qt.quit()
                }
            }
        }
    }
}
