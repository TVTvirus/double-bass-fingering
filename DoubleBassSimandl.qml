//=============================================================================
//  Double Bass Fingering - Simandl System
//  Context-aware fingering using dynamic programming
//  Compatible with MuseScore 3.x and 4.x
//
//  Author: TVTvirus
//  Version: 1.1
//  License: GPL-3.0
//=============================================================================
import QtQuick 2.2
import MuseScore 3.0

MuseScore {
    version: "1.1"
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
    property var openStrings: [28, 33, 38, 43]
    property var stringNames: ["E", "A", "D", "G"]

    property var posColors: ({
        "Ab": "#000000",
        "1ª": "#0071bb",
        "½":  "#00bcd4",
        "2ª": "#62bc47",
        "3ª": "#f5d000",
        "4ª": "#f99d1c",
        "5ª": "#e21c48",
        "6ª": "#8d5ba6"
    })

    function buildSimandlMap() {
        var pattern = [
            {fret:0,  finger:"0", pos:"Ab"},
            {fret:1,  finger:"1", pos:"½"},
            {fret:2,  finger:"2", pos:"½"},
            {fret:3,  finger:"4", pos:"½"},
            {fret:2,  finger:"1", pos:"1ª"},
            {fret:3,  finger:"2", pos:"1ª"},
            {fret:4,  finger:"4", pos:"1ª"},
            {fret:3,  finger:"1", pos:"2ª"},
            {fret:4,  finger:"2", pos:"2ª"},
            {fret:5,  finger:"4", pos:"2ª"},
            {fret:5,  finger:"1", pos:"3ª"},
            {fret:6,  finger:"2", pos:"3ª"},
            {fret:7,  finger:"4", pos:"3ª"},
            {fret:7,  finger:"1", pos:"4ª"},
            {fret:8,  finger:"2", pos:"4ª"},
            {fret:9,  finger:"4", pos:"4ª"},
            {fret:8,  finger:"1", pos:"5ª"},
            {fret:9,  finger:"2", pos:"5ª"},
            {fret:10, finger:"4", pos:"5ª"},
            {fret:10, finger:"1", pos:"6ª"},
            {fret:11, finger:"2", pos:"6ª"},
            {fret:12, finger:"4", pos:"6ª"}
        ]
        return [pattern, pattern, pattern, pattern]
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

    function posOrder(pos) {
        var order = {"Ab":0, "1ª":1, "½":2, "2ª":3, "3ª":4, "4ª":5, "5ª":6, "6ª":7}
        var val = order[pos]
        return (typeof val !== 'undefined') ? val : 99
    }

    function cost(a, b) {
        if (a === null || a.stringIdx === -1 || b.stringIdx === -1) return 0
        if (b.pos === "Ab") return 0
        if (a.pos === "Ab") return posOrder(b.pos) * 2

        var posA = posOrder(a.pos)
        var posB = posOrder(b.pos)
        var posDiff = Math.abs(posA - posB)
        var stringDiff = Math.abs(a.stringIdx - b.stringIdx)

        var positionPenalty = posB * 2

        var movementCost
        if (posDiff === 0 && stringDiff === 0)    movementCost = 0
        else if (posDiff === 0 && stringDiff > 0) movementCost = 2
        else if (posDiff === 1)                   movementCost = 5
        else if (posDiff === 2)                   movementCost = 12
        else                                      movementCost = 20

        return positionPenalty + movementCost
    }

    // Minimum cost to transition from opt to any option in nextOpts
    function minCostToNext(opt, nextOpts) {
        if (!nextOpts || nextOpts.length === 0) return 0
        var minC = 999999
        for (var k = 0; k < nextOpts.length; k++) {
            var c = cost(opt, nextOpts[k])
            if (c < minC) minC = c
        }
        return minC
    }

    // Count how many of the next N notes have an option in the same position
    function countFutureMatches(opt, futureOptsList) {
        var count = 0
        for (var f = 0; f < futureOptsList.length; f++) {
            var found = false
            for (var k = 0; k < futureOptsList[f].length; k++) {
                if (futureOptsList[f][k].pos === opt.pos) {
                    found = true
                    break
                }
            }
            if (found) count++
        }
        return count
    }

    function bestPath(pitches, simandlMap) {
        var n = pitches.length
        if (n === 0) return []

        var opts = []
        for (var i = 0; i < n; i++) {
            opts.push(allOptions(pitches[i], simandlMap))
        }

        var dp = []
        var parent = []

        // First note: base penalty + min transition to note 2 + lookahead reward
        var firstRow = []
        var firstPar = []
        for (var j = 0; j < opts[0].length; j++) {
            var o = opts[0][j]
            var baseCost = o.pos === "Ab" ? 0 : posOrder(o.pos) * 2
            // Include cost of reaching next note from here
            if (n > 1) baseCost += minCostToNext(o, opts[1])
            // Reward if notes 2 and 3 share this position
            var future = []
            for (var f = 2; f <= 3 && f < n; f++) future.push(opts[f])
            var matches = countFutureMatches(o, future)
            baseCost = Math.max(0, baseCost - matches * 3)
            firstRow.push(baseCost)
            firstPar.push(-1)
        }
        dp.push(firstRow)
        parent.push(firstPar)

        for (var i = 1; i < n; i++) {
            var futureOpts = []
            for (var f = i + 1; f <= i + 2 && f < n; f++) futureOpts.push(opts[f])

            var row = []
            var par = []
            for (var j = 0; j < opts[i].length; j++) {
                var minCost = 999999
                var minPar  = 0
                for (var k = 0; k < opts[i-1].length; k++) {
                    var total = dp[i-1][k] + cost(opts[i-1][k], opts[i][j])
                    var matches = countFutureMatches(opts[i][j], futureOpts)
                    total = Math.max(0, total - matches * 3)
                    if (total < minCost) {
                        minCost = total
                        minPar  = k
                    }
                }
                row.push(minCost)
                par.push(minPar)
            }
            dp.push(row)
            parent.push(par)
        }

        // Traceback — break ties by preferring lower position
        var last  = n - 1
        var bestJ = 0
        var bestC = 999999
        for (var j = 0; j < opts[last].length; j++) {
            var better   = dp[last][j] < bestC
            var tieBreak = dp[last][j] === bestC &&
                           posOrder(opts[last][j].pos) < posOrder(opts[last][bestJ].pos)
            if (better || tieBreak) {
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

                var pitches = []
                while (cursor.segment && (fullScore || cursor.tick < endTick)) {
                    if (cursor.element && cursor.element.type === Element.CHORD) {
                        var notes = cursor.element.notes
                        pitches.push(notes[notes.length - 1].pitch)
                    }
                    cursor.next()
                }

                if (pitches.length === 0) continue

                var path = bestPath(pitches, simandlMap)

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
