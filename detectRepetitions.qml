/*
SPDX-License-Identifier: MIT
Copyright (c) 2025 Philipp Naumann

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

MuseScore {
    version: "1.0.0"
    description: "Detects repetitions of sounding notes."
    title: "Detect repetitions"
    categoryCode: "composing-arranging-tools"
    onRun: {
        processSelectedNotes()
    }

    property var highlightColor: "#F032E6"
    
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
                            startTick: cursor.tick,
                            note: notes[i],
                            endTick: cursor.tick + chord.actualDuration.ticks,
                        }
                        selectedNotes.push(note)
                    }
                    cursor.next()
                }
            }
        }
        selectedNotes.sort((note1, note2) => Math.sign(note2.startTick - note1.startTick))
        return selectedNotes
    }
    
    function processSelectedNotes() {
        curScore.startCmd()
        var selectedNotes = getSelectedNotes()
        for (var i = 0; i < selectedNotes.length; i++) {
            var note1 = selectedNotes[i]
            for (var j = i + 1; j < selectedNotes.length; j++) {
                var note2 = selectedNotes[j]
                if (note2.startTick > note1.endTick) {
                    break
                }
                if (!(note1.startTick < note2.endTick && note2.startTick < note1.endTick)) {
                    continue
                }
                if (note1.note.pitch !== note2.note.pitch) {
                    continue
                }
                note1.note.color = highlightColor
                note2.note.color = highlightColor
            }
        }
        curScore.endCmd()
    }
}
