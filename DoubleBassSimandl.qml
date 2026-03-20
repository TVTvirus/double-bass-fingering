//=============================================================================
//  Double Bass Fingering - Simandl System
//  Context-aware fingering using dynamic programming
//  Compatible with MuseScore 3.x and 4.x
//
//  Author: TVTvirus
//  License: GPL-3.0
//=============================================================================
import QtQuick 2.2
import MuseScore 3.0

MuseScore {
    version: "1.0"
    description: "Double Bass fingering with Simandl positions, context-aware"
    menuPath: "Plugins.Fingering.DoubleBassSimandl"
    id: doubleBassSimandl

    //4.4 title: "Double Bass Simandl"
    //4.4 categoryCode: "composing-arranging-tools"
    Component.onCompleted: {
        if (mscoreMajorVersion >= 4 && mscoreMinorVersion <= 3) {
            doubleBassSimandl.title = "Double Bass Simandl"
            doubleBassSimandl.categoryCode = "composing-arranging-tools"
        }
    }

    property var noteNames: ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
    property var openStrings: [28, 33, 38, 43]   // MIDI: E1, A1, D2, G2
    property var stringNames: ["E", "A", "D", "G"]

    // ==========================================================================
    // COLOR SETTINGS
    // Each color represents a position. Change hex values to customize.
    // To disable coloring entirely, comment out the color block in onRun
    // (search for "// COLOR BLOCK START" and "// COLOR BLOCK END")
    // ==========================================================================
    property var posColors: ({
        "Ab": "#000000",  // Open string  — black (default note color)
        "1ª": "#0071bb",  // 1st position — blue
        "½":  "#00bcd4",  // Half position — cyan
        "2ª": "#62bc47",  // 2nd position — green
        "3ª": "#f5d000",  // 3rd position — yellow
        "4ª": "#f99d1c",  // 4th position — orange
        "5ª": "#e21c48",  // 5th position — red
        "6ª": "#8d5ba6"   // 6th position — purple
    })

    // ==========================================================================
    // SIMANDL POSITION MAP
    // Format: { fret: semitones from open string, finger: "0/1/2/4", pos: position }
    // Italian system: fingers 1, 2, 4 (no independent finger 3 in low positions)
    // Each position covers 3 semitones: finger 1, finger 2, finger 4
    // Positions overlap by one semitone (a note can be played in two positions)
    // ==========================================================================
    function buildSimandlMap() {
        return [
            // E string (open = E1, MIDI 28)
            [
                {fret:0,  finger:"0", pos:"Ab"},
                {fret:1,  finger:"1", pos:"½"},
                {fret:2,  finger:"2", pos:"½"},
                {fret:3,  finger:"4", pos:"½"},
                {fret:2,  finger:"1", pos:"1ª"},
                {fret:3,  finger:"2", pos:"1ª"},
                {fret:4,  finger:"4", pos:"1ª"},
                {fret:4,  finger:"1", pos:"2ª"},
                {fret:5,  finger:"2", pos:"2ª"},
                {fret:6,  finger:"4", pos:"2ª"},
                {fret:6,  finger:"1", pos:"3ª"},
                {fret:7,  finger:"2", pos:"3ª"},
                {fret:8,  finger:"4", pos:"3ª"},
                {fret:8,  finger:"1", pos:"4ª"},
                {fret:9,  finger:"2", pos:"4ª"},
                {fret:10, finger:"4", pos:"4ª"},
                {fret:10, finger:"1", pos:"5ª"},
                {fret:11, finger:"2", pos:"5ª"},
                {fret:12, finger:"4", pos:"5ª"},
                {fret:12, finger:"1", pos:"6ª"},
                {fret:13, finger:"2", pos:"6ª"},
                {fret:14, finger:"4", pos:"6ª"}
            ],
            // A string (open = A1, MIDI 33)
            [
                {fret:0,  finger:"0", pos:"Ab"},
                {fret:1,  finger:"1", pos:"½"},
                {fret:2,  finger:"2", pos:"½"},
                {fret:3,  finger:"4", pos:"½"},
                {fret:2,  finger:"1", pos:"1ª"},
                {fret:3,  finger:"2", pos:"1ª"},
                {fret:4,  finger:"4", pos:"1ª"},
                {fret:4,  finger:"1", pos:"2ª"},
                {fret:5,  finger:"2", pos:"2ª"},
                {fret:6,  finger:"4", pos:"2ª"},
                {fret:6,  finger:"1", pos:"3ª"},
                {fret:7,  finger:"2", pos:"3ª"},
                {fret:8,  finger:"4", pos:"3ª"},
                {fret:8,  finger:"1", pos:"4ª"},
                {fret:9,  finger:"2", pos:"4ª"},
                {fret:10, finger:"4", pos:"4ª"},
                {fret:10, finger:"1", pos:"5ª"},
                {fret:11, finger:"2", pos:"5ª"},
                {fret:12, finger:"4", pos:"5ª"},
                {fret:12, finger:"1", pos:"6ª"},
                {fret:13, finger:"2", pos:"6ª"},
                {fret:14, finger:"4", pos:"6ª"}
            ],
            // D string (open = D2, MIDI 38)
            [
                {fret:0,  finger:"0", pos:"Ab"},
                {fret:1,  finger:"1", pos:"½"},
                {fret:2,  finger:"2", pos:"½"},
                {fret:3,  finger:"4", pos:"½"},
                {fret:2,  finger:"1", pos:"1ª"},
                {fret:3,  finger:"2", pos:"1ª"},
                {fret:4,  finger:"4", pos:"1ª"},
                {fret:4,  finger:"1", pos:"2ª"},
                {fret:5,  finger:"2", pos:"2ª"},
                {fret:6,  finger:"4", pos:"2ª"},
                {fret:6,  finger:"1", pos:"3ª"},
                {fret:7,  finger:"2", pos:"3ª"},
                {fret:8,  finger:"4", pos:"3ª"},
                {fret:8,  finger:"1", pos:"4ª"},
                {fret:9,  finger:"2", pos:"4ª"},
                {fret:10, finger:"4", pos:"4ª"},
                {fret:10, finger:"1", pos:"5ª"},
                {fret:11, finger:"2", pos:"5ª"},
                {fret:12, finger:"4", pos:"5ª"},
                {fret:12, finger:"1", pos:"6ª"},
                {fret:13, finger:"2", pos:"6ª"},
                {fret:14, finger:"4", pos:"6ª"}
            ],
            // G string (open = G2, MIDI 43)
            [
                {fret:0,  finger:"0", pos:"Ab"},
                {fret:1,  finger:"1", pos:"½"},
                {fret:2,  finger:"2", pos:"½"},
                {fret:3,  finger:"4", pos:"½"},
                {fret:2,  finger:"1", pos:"1ª"},
                {fret:3,  finger:"2", pos:"1ª"},
                {fret:4,  finger:"4", pos:"1ª"},
                {fret:4,  finger:"1", pos:"2ª"},
                {fret:5,  finger:"2", pos:"2ª"},
                {fret:6,  finger:"4", pos:"2ª"},
                {fret:5,  finger:"1", pos:"3ª"},
                {fret:6,  finger:"2", pos:"3ª"},
                {fret:7,  finger:"4", pos:"3ª"},
                {fret:7,  finger:"1", pos:"4ª"},
                {fret:8,  finger:"2", pos:"4ª"},
                {fret:9,  finger:"4", pos:"4ª"},
                {fret:9,  finger:"1", pos:"5ª"},
                {fret:10, finger:"2", pos:"5ª"},
                {fret:11, finger:"4", pos:"5ª"},
                {fret:11, finger:"1", pos:"6ª"},
                {fret:12, finger:"2", pos:"6ª"},
                {fret:13, finger:"4", pos:"6ª"}
            ]
        ]
    }

    function allOptions(pitch, simandlMap) {
        var options = []
        for (var s = 0; s < openStrings.length; s++) {
            var fret = pitch - openStrings[s]
            if (fret < 0) continue
            var entries = simandlMap[s]
            for (var e = 0; e < entries.length; e++) {
                if (entries[e].fret === fret) {
                    options.push({
                        stringIdx:  s,
                        stringName: stringNames[s],
                        finger:     entries[e].finger,
                        pos:        entries[e].pos
                    })
                }
            }
        }
        if (options.length === 0) {
            options.push({stringIdx: -1, stringName: "X", finger: "", pos: "?"})
        }
        return options
    }

    // Position order used for cost calculation
    // 1st position is prioritized over half position (lower index = cheaper)
    function posOrder(pos) {
        var order = {"Ab":0, "1ª":1, "½":2, "2ª":3, "3ª":4, "4ª":5, "5ª":6, "6ª":7}
        var val = order[pos]
        return (typeof val !== 'undefined') ? val : 99
    }

    // Cost of moving from option A to option B
    // Lower positions are always preferred (positionPenalty)
    // Moving between positions adds extra cost on top
    function cost(a, b) {
        if (a === null || a.stringIdx === -1 || b.stringIdx === -1) return 0
        var posA = posOrder(a.pos)
        var posB = posOrder(b.pos)
        var posDiff = Math.abs(posA - posB)
        var stringDiff = Math.abs(a.stringIdx - b.stringIdx)

        // Base penalty: higher positions cost more regardless of movement
        var positionPenalty = posB * 2

        // Movement cost between consecutive notes
        var movementCost
        if (posDiff === 0 && stringDiff === 0)     movementCost = 0  // same string, same position
        else if (posDiff === 0 && stringDiff > 0)  movementCost = 1  // string change, same position
        else if (posDiff === 1)                    movementCost = 3  // adjacent position shift
        else if (posDiff === 2)                    movementCost = 6  // 2-position jump
        else                                       movementCost = 10 // large jump

        return positionPenalty + movementCost
    }

    // Dynamic programming over all notes in the voice
    // Finds the sequence of fingerings with minimum total cost
    function bestPath(pitches, simandlMap) {
        var n = pitches.length
        if (n === 0) return []

        var opts = []
        for (var i = 0; i < n; i++) {
            opts.push(allOptions(pitches[i], simandlMap))
        }

        var dp = []
        var parent = []

        // Initialize first note with its position penalty
        var firstRow = []
        var firstPar = []
        for (var j = 0; j < opts[0].length; j++) {
            firstRow.push(posOrder(opts[0][j].pos) * 2)
            firstPar.push(-1)
        }
        dp.push(firstRow)
        parent.push(firstPar)

        // Fill DP table
        for (var i = 1; i < n; i++) {
            var row = []
            var par = []
            for (var j = 0; j < opts[i].length; j++) {
                var minCost = 999999
                var minPar  = 0
                for (var k = 0; k < opts[i-1].length; k++) {
                    var c = dp[i-1][k] + cost(opts[i-1][k], opts[i][j])
                    if (c < minCost) {
                        minCost = c
                        minPar  = k
                    }
                }
                row.push(minCost)
                par.push(minPar)
            }
            dp.push(row)
            parent.push(par)
        }

        // Traceback from best final option
        var last  = n - 1
        var bestJ = 0
        var bestC = 999999
        for (var j = 0; j < opts[last].length; j++) {
            if (dp[last][j] < bestC) {
                bestC = dp[last][j]
                bestJ = j
            }
        }

        var path = []
        var cur  = bestJ
        for (var i = last; i >= 0; i--) {
            path.unshift(opts[i][cur])
            if (i > 0) cur = parent[i][cur]
        }
        return path
    }

    function octave(pitch) {
        return Math.floor((pitch - 12) / 12)
    }
    function noteName(pitch) {
        return noteNames[(pitch - 12) % 12]
    }
    function fullNoteName(pitch) {
        return noteName(pitch) + octave(pitch)
    }

    onRun: {
        var simandlMap = buildSimandlMap()
        var cursor = curScore.newCursor()
        var fullScore = false
        var startStaff, endStaff, endTick

        cursor.rewind(Cursor.SELECTION_START)
        if (!cursor.segment) {
            fullScore  = true
            startStaff = 0
            endStaff   = curScore.nstaves - 1
        } else {
            startStaff = cursor.staffIdx
            cursor.rewind(Cursor.SELECTION_END)
            endTick    = (cursor.tick === 0) ? curScore.lastSegment.tick + 1 : cursor.tick
            endStaff   = cursor.staffIdx
        }

        curScore.startCmd()

        for (var staff = startStaff; staff <= endStaff; staff++) {
            for (var voice = 0; voice < 4; voice++) {
                cursor.rewind(Cursor.SELECTION_START)
                cursor.voice    = voice
                cursor.staffIdx = staff
                if (fullScore) cursor.rewind(Cursor.SCORE_START)

                // First pass: collect pitches
                var pitches = []
                while (cursor.segment && (fullScore || cursor.tick < endTick)) {
                    if (cursor.element && cursor.element.type === Element.CHORD) {
                        var notes = cursor.element.notes
                        pitches.push(notes[notes.length - 1].pitch)
                    }
                    cursor.next()
                }

                if (pitches.length === 0) continue

                // Run dynamic programming
                var path = bestPath(pitches, simandlMap)

                // Second pass: add text labels and colors
                cursor.rewind(Cursor.SELECTION_START)
                cursor.voice    = voice
                cursor.staffIdx = staff
                if (fullScore) cursor.rewind(Cursor.SCORE_START)

                var idx = 0
                while (cursor.segment && (fullScore || cursor.tick < endTick) && idx < path.length) {
                    if (cursor.element && cursor.element.type === Element.CHORD) {
                        var opt       = path[idx]
                        var label     = opt.stringName + opt.finger
                        var prevLabel = idx > 0 ? path[idx-1].stringName + path[idx-1].finger : ""

                        // COLOR BLOCK START
                        // To disable note coloring, comment out from here...
                        var color = posColors[opt.pos] || "#000000"
                        var chordNotes = cursor.element.notes
                        for (var n = 0; n < chordNotes.length; n++) {
                            chordNotes[n].color = color
                        }
                        // ...to here
                        // COLOR BLOCK END

                        // Add string+finger text label only when it changes
                        if (label !== prevLabel) {
                            var text = newElement(Element.STAFF_TEXT)
                            text.autoplace = true
                            text.offsetX   = 0.65
                            text.align     = 2
                            text.text      = label
                            cursor.add(text)
                        }
                        idx++
                    }
                    cursor.next()
                }
            }
        }

        curScore.endCmd()
        ;(typeof quit === 'undefined' ? Qt.quit : quit)()
    }
}
