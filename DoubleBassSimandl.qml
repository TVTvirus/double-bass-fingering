//=============================================================================
//  Double Bass Fingering - Simandl System
//  Context-aware fingering using dynamic programming
//
//  The cost model encodes the standard pedagogical rules of double bass
//  fingering (see COST MODEL below), not just "prefer low positions".
//
//  Author: TVTvirus
//  Version: 2.0
//  License: GPL-3.0
//=============================================================================
import QtQuick 2.2
import MuseScore 3.0

MuseScore {
    version: "2.0"
    description: "Double Bass fingering with Simandl positions, context-aware"

    // MuseScore 4.4+ manifest. On MuseScore 3.x and 4.0-4.3, replace these
    // three lines with:  menuPath: "Plugins.Fingering.DoubleBassSimandl"
    title: "Double Bass Simandl"
    categoryCode: "composing-arranging-tools"
    requiresScore: true

    id: doubleBassSimandl

    //=========================================================================
    //  CONFIGURATION
    //=========================================================================
    property var settings: ({
        // --- instrument ---------------------------------------------------
        openStrings: [28, 33, 38, 43],      // E1 A1 D2 G2 (sounding MIDI)
        stringNames: ["E", "A", "D", "G"],  // filled in from stringNaming below
        stringLetters: ["E", "A", "D", "G"],
        stringSolfege: ["Mi", "La", "Re", "Sol"],
        maxFret: 24,

        // --- what the left hand is allowed to do ----------------------------
        useThumb: true,
        thumbMinFret: 12,       // octave harmonic on the G string
        thumbMinPitch: 55,      // G3 sounding = written G on the 3rd ledger line,
                                // which is where the sources put thumb position.
                                // Without this the solver "discovers" thumb
                                // position in the bass register, where nobody plays.
        thumbStrings: [2, 3],   // thumb only on D and G
        useHalfPositions: true, // 2½, 3½, 5½ ... intermediate positions

        // --- ergonomic cost of each neck position, per note ------------------
        // Indexed by anchor = fret under the 1st finger.
        // 1st position is home (0). Half position is the most awkward spot on the
        // instrument. Intermediate positions are playable but less idiomatic.
        // Above the heel (anchor 8+) the hand has to rotate around the neck.
        //            a=0   ½    1ª   2ª   2½   3ª   3½   4ª   5ª   5½   6ª   6½   7ª
        neckEase:   [ 0.0, 2.2, 0.0, 0.4, 2.6, 0.8, 3.0, 1.2, 2.6, 4.6, 3.4, 5.6, 5.5 ],
        thumbEase:  6.0,        // cost of the first thumb position
        thumbSlope: 0.35,       // extra cost per semitone above thumbMinFret
        wThumbClosed: 1.2,      // chromatic thumb shape (T-1-2-3 all semitones)

        // --- movement -------------------------------------------------------
        wShiftBase:  2.2,       // fixed cost of breaking position at all
                                // (this is "at least two notes per position")
        wShift:      1.4,       // per semitone travelled
        wThumbSwitch: 9.0,      // entering or leaving thumb position

        // --- string crossing ------------------------------------------------
        wCrossTone:  1.1,       // timbre cost, does NOT scale with tempo
        wCrossBow:  2.4,       // bow-arm cost, scales with tempo. Low values let
                                // fast passages zigzag across strings on every
                                // note, which is neither idiomatic nor readable.
        crossFactor: [0, 1.0, 2.6, 4.5],   // by number of strings crossed
        wHalfStepCross: 9.0,    // "never cross strings for a half step"
        wHalfStepCrossOpen: 5.0, // extra when one of them is an open string
        wSameFinger: 2.4,       // same finger on a new string = audible gap
        wSameFingerDown: 1.8,   // worse going from a higher to a lower string

        // --- shift direction vs finger --------------------------------------
        // "shift higher with lower fingers (1-1-4), lower with higher fingers (4-4-1)"
        wShiftFinger: 2.0,

        // --- open strings ---------------------------------------------------
        wOpenLyric: 4.6,        // open strings stick out in slow, lyrical playing.
                                // Has to outweigh two string crossings, or the
                                // solver parks on an open string to avoid them.
                                // Scales with length beyond half a quarter, so
                                // passing notes pay nothing.
        wOpenRun:   2.2,        // two open strings in a row
        wFinger4Long: 0.5,      // per quarter: 4th finger is poor for vibrato

        // --- phrasing -------------------------------------------------------
        beatBonus: 0.8,         // shifting on a beat is easier to hide
        restRelief: 0.30,       // urgency multiplier after a rest >= 1 quarter
        longRestRelief: 0.06,   // after a rest >= 4 quarters
        urgencyMin: 0.15,
        urgencyMax: 5.0
    })

    // Language of the position names printed in the labels ("1st" vs "1ª").
    // Fingerings themselves (G1, D4, GT) are language neutral.
    property string language: "en"      // "en" or "es"

    // How to name the strings in the labels: "E1 D4 G0" or "Mi1 Re4 Sol0".
    // "auto" follows `language`; set it explicitly to mix the two.
    property string stringNaming: "auto" // "auto", "letters" or "solfege"

    property var posNames: ({
        "en": {"Ab": "open", "½": "½",  "1ª": "1st", "2ª": "2nd", "2½": "2½",
               "3ª": "3rd",  "3½": "3½", "4ª": "4th", "5ª": "5th", "5½": "5½",
               "6ª": "6th",  "6½": "6½", "7ª": "7th", "Pu": "TP",  "X": "?"},
        "es": {"Ab": "aire", "½": "½",  "1ª": "1ª",  "2ª": "2ª",  "2½": "2½",
               "3ª": "3ª",   "3½": "3½", "4ª": "4ª",  "5ª": "5ª",  "5½": "5½",
               "6ª": "6ª",   "6½": "6½", "7ª": "7ª",  "Pu": "Pu",  "X": "?"}
    })

    function positionName(key) {
        var table = posNames[language] || posNames["en"]
        return table[key] || key
    }

    // Note colours by position. Set colorNotes to false to leave notes alone.
    property bool colorNotes: true
    // A label on every note stacks up into an unreadable staircase in fast
    // passages, because MuseScore pushes overlapping texts out of each other's
    // way. By default only print one where it actually tells you something: when
    // the string or the position changes.
    property bool labelEveryNote: false   // true = a label on every single note
    property bool labelEveryFinger: false // true = also when only the finger changes
    property bool showPositionName: false // true = "A1 (3ª)" when the position changes

    property var posColors: ({
        "Ab": "#000000",   // open string
        "½":  "#00bcd4",
        "1ª": "#0071bb",
        "2ª": "#62bc47",
        "2½": "#9ccc65",
        "3ª": "#f5d000",
        "3½": "#ffd54f",
        "4ª": "#f99d1c",
        "5ª": "#e21c48",
        "5½": "#ef5350",
        "6ª": "#8d5ba6",
        "6½": "#ab7bc4",
        "7ª": "#6a1b9a",
        "Pu": "#795548",   // thumb position
        "X":  "#9e9e9e"    // out of range
    })

    //=========================================================================
    //  COST MODEL - the rules this encodes
    //
    //  R1  at least two notes per position       -> wShiftBase
    //  R2  never cross strings for a half step   -> wHalfStepCross
    //  R3  fast passages: stay in position, cross strings
    //                                            -> shift scales with urgency,
    //                                               crossing barely does
    //  R4  melodic passages: shift along one string
    //                                            -> crossing keeps a fixed
    //                                               timbre cost at any tempo
    //  R5  don't cross strings on the same finger-> wSameFinger(+Down)
    //  R6  no open strings in lyrical playing    -> wOpenLyric, by note length
    //  R6b no two open strings in a row          -> wOpenRun
    //  R7  shift up with lower fingers (1-1-4)   -> wShiftFinger
    //  R8  shift down with higher fingers (4-4-1)-> wShiftFinger
    //  R10 avoid crossing two strings            -> crossFactor
    //  R12 fingers 1-2 for lyrical notes         -> wFinger4Long
    //  R15 shift on a beat, not mid-gesture      -> beatBonus
    //
    //  Everything below this line is pure JavaScript with no MuseScore API in
    //  it, so tools/test-core.js can extract and run it outside MuseScore.
    //=========================================================================

    // ===== CORE START =====
    function computeFingerings(events, cfg) {
        var n = events.length
        if (n === 0) return []

        var OPEN = cfg.openStrings
        var SN   = cfg.stringNames
        var DIV  = cfg.division

        //---------------------------------------------------------------------
        // Hand frames: every shape the left hand can take, keyed by the fret it
        // is anchored on. Neck frames use Simandl 1-2-4. Thumb frames use
        // T-1-2-3, either the standard whole/half/half shape or a chromatic one.
        //---------------------------------------------------------------------
        function buildFrames() {
            var neck = [
                {p: "½",  a: 1,  half: false},
                {p: "1ª", a: 2,  half: false},
                {p: "2ª", a: 3,  half: false},
                {p: "2½", a: 4,  half: true },
                {p: "3ª", a: 5,  half: false},
                {p: "3½", a: 6,  half: true },
                {p: "4ª", a: 7,  half: false},
                {p: "5ª", a: 8,  half: false},
                {p: "5½", a: 9,  half: true },
                {p: "6ª", a: 10, half: false},
                {p: "6½", a: 11, half: true },
                {p: "7ª", a: 12, half: false}
            ]
            var out = []
            for (var i = 0; i < neck.length; i++) {
                if (neck[i].half && !cfg.useHalfPositions) continue
                var a = neck[i].a
                var m = {}
                m[a] = "1"; m[a + 1] = "2"; m[a + 2] = "4"
                out.push({key: neck[i].p, anchor: a, thumb: false, pen: 0, map: m})
            }
            if (cfg.useThumb) {
                for (var t = cfg.thumbMinFret; t + 4 <= cfg.maxFret; t++) {
                    var ms = {}
                    ms[t] = "T"; ms[t + 2] = "1"; ms[t + 3] = "2"; ms[t + 4] = "3"
                    out.push({key: "Pu", anchor: t, thumb: true, pen: 0, map: ms})
                    var mc = {}
                    mc[t] = "T"; mc[t + 1] = "1"; mc[t + 2] = "2"; mc[t + 3] = "3"
                    out.push({key: "Pu", anchor: t, thumb: true, pen: cfg.wThumbClosed, map: mc})
                }
            }
            return out
        }
        var FRAMES = buildFrames()

        function frameEase(fr) {
            if (fr.thumb)
                return cfg.thumbEase + cfg.thumbSlope * (fr.anchor - cfg.thumbMinFret) + fr.pen
            var t = cfg.neckEase
            return (fr.anchor < t.length ? t[fr.anchor] : t[t.length - 1]) + fr.pen
        }

        function fingerNum(f) {
            if (f === "T") return 0
            if (f === "0") return -1
            return parseInt(f, 10)
        }

        //---------------------------------------------------------------------
        // Stops: every (string, finger) that produces a pitch inside a frame.
        //---------------------------------------------------------------------
        function stopsIn(pitch, fr) {
            var res = []
            for (var s = 0; s < OPEN.length; s++) {
                var fret = pitch - OPEN[s]
                if (fret < 0 || fret > cfg.maxFret) continue
                if (fret === 0) { res.push({s: s, f: "0"}); continue }
                if (fr.thumb && (pitch < cfg.thumbMinPitch ||
                                 cfg.thumbStrings.indexOf(s) < 0)) continue
                var f = fr.map[fret]
                if (f) res.push({s: s, f: f})
            }
            return res
        }

        function makeOption(parts, fr, playable) {
            var top = parts[parts.length - 1]
            var allOpen = true
            var label = ""
            for (var i = 0; i < parts.length; i++) {
                if (parts[i].f !== "0") allOpen = false
                label += (i ? "/" : "") + SN[parts[i].s] + parts[i].f
            }
            return {
                parts:    parts,
                label:    playable ? label : "?",
                colorKey: playable ? (allOpen ? "Ab" : fr.key) : "X",
                posName:  playable ? fr.key : "?",
                anchor:   fr.anchor,
                thumb:    fr.thumb,
                ease:     playable ? frameEase(fr) : 0,
                mainStr:  playable ? top.s : 0,
                topFing:  playable ? top.f : "0",
                openOnly: playable && allOpen,
                handFree: !playable || allOpen,
                dead:     !playable
            }
        }

        //---------------------------------------------------------------------
        // Options per event. An event with only open strings (or one that is
        // unplayable) leaves the hand free, so it gets one option per candidate
        // anchor: the hand either stays put or travels during that note.
        //---------------------------------------------------------------------
        function stoppedOptions(ev) {
            var out = []
            var ps  = ev.pitches
            var i, j, k

            // double stop: both notes under the same frame, on different strings
            if (ps.length === 2) {
                for (i = 0; i < FRAMES.length; i++) {
                    var lo = stopsIn(ps[0], FRAMES[i])
                    var hi = stopsIn(ps[1], FRAMES[i])
                    for (j = 0; j < lo.length; j++)
                        for (k = 0; k < hi.length; k++)
                            if (lo[j].s < hi[k].s)
                                out.push(makeOption([lo[j], hi[k]], FRAMES[i], true))
                }
                if (out.length > 0) return out
            }

            // single note (or fallback: the top note of a bigger chord)
            var p = ps[ps.length - 1]
            for (i = 0; i < FRAMES.length; i++) {
                var st = stopsIn(p, FRAMES[i])
                for (j = 0; j < st.length; j++)
                    if (st[j].f !== "0")
                        out.push(makeOption([st[j]], FRAMES[i], true))
            }
            return out
        }

        // Playing a note open leaves the left hand free, so it gets one option
        // per candidate anchor: during that note the hand either stays where it
        // was or travels to where it is needed next. Same for a note that is out
        // of the instrument's range.
        function freeHandOptions(ev, anchors, hasStopped) {
            var p = ev.pitches[ev.pitches.length - 1]
            var openStr = -1
            for (var s = 0; s < OPEN.length; s++) if (p === OPEN[s]) openStr = s
            if (openStr < 0 && hasStopped) return []   // nothing to add

            var out = []
            for (var i = 0; i < anchors.length; i++) {
                var fr = anchors[i]
                out.push(openStr >= 0
                    ? makeOption([{s: openStr, f: "0"}], fr, true)
                    : makeOption([{s: 0, f: ""}], fr, false))
            }
            return out
        }

        // ---- build the option lists -----------------------------------------
        var stopped = []
        for (var i = 0; i < n; i++) stopped.push(stoppedOptions(events[i]))

        // Where could the hand plausibly be while an open string rings? Only
        // somewhere it is actually needed: the anchors of the nearest stopped
        // notes on either side, plus this note's own stopped alternatives.
        function anchorsAround(idx) {
            var seen = {}
            var res  = []
            function harvest(list) {
                if (!list || list.length === 0) return false
                for (var j = 0; j < list.length; j++) {
                    var key = list[j].anchor + "|" + (list[j].thumb ? "T" : "N")
                    if (seen[key]) continue
                    seen[key] = true
                    res.push({key: list[j].colorKey, anchor: list[j].anchor,
                              thumb: list[j].thumb, pen: 0, map: {}})
                }
                return true
            }
            harvest(stopped[idx])
            for (var b = idx - 1; b >= 0; b--) if (harvest(stopped[b])) break
            for (var f = idx + 1; f < n; f++)  if (harvest(stopped[f])) break
            if (res.length === 0)
                res.push({key: "1ª", anchor: 2, thumb: false, pen: 0, map: {}})
            return res
        }

        var opts = []
        for (i = 0; i < n; i++) {
            var extra = freeHandOptions(events[i], anchorsAround(i), stopped[i].length > 0)
            opts.push(stopped[i].concat(extra))
        }

        //---------------------------------------------------------------------
        // Context between two consecutive events
        //---------------------------------------------------------------------
        function contextAt(i) {
            var cur  = events[i]
            var prev = events[i - 1]
            var delta = Math.max(1, cur.tick - prev.tick)
            var gap   = cur.tick - (prev.tick + prev.ticks)

            var u = DIV / delta
            if (gap >= DIV * 4)     u *= cfg.longRestRelief
            else if (gap >= DIV)    u *= cfg.restRelief
            if (u < cfg.urgencyMin) u = cfg.urgencyMin
            if (u > cfg.urgencyMax) u = cfg.urgencyMax

            var pPrev = prev.pitches[prev.pitches.length - 1]
            var pCur  = cur.pitches[cur.pitches.length - 1]
            return {
                urg:      u,
                interval: Math.abs(pCur - pPrev),
                onBeat:   (cur.tick % DIV) === 0
            }
        }

        function noteCost(o, ev) {
            if (o.dead) return 0
            var quarters = Math.min(4.0, ev.ticks / DIV)
            var lyric    = Math.max(0, quarters - 0.5)
            var c = o.ease
            if (o.openOnly)          c += cfg.wOpenLyric   * lyric   // R6
            if (o.topFing === "4")   c += cfg.wFinger4Long * lyric   // R12
            return c
        }

        function stepCost(a, b, ctx) {
            if (a.dead || b.dead) return 0
            var c = 0
            var shift = Math.abs(a.anchor - b.anchor)
            var sd    = Math.abs(a.mainStr - b.mainStr)

            // R1 + shift distance, heavily tempo dependent
            if (shift > 0) {
                var sc = (cfg.wShiftBase + cfg.wShift * shift) * ctx.urg
                if (ctx.onBeat) sc = Math.max(0, sc - cfg.beatBonus)      // R15
                c += sc

                // R7 / R8: which finger you land on depends on the direction
                if (!a.handFree && !b.handFree) {
                    var fb = fingerNum(b.topFing)
                    if (fb > 0) {
                        var wrong = (b.anchor > a.anchor) ? (fb - 1) : (4 - fb)
                        c += cfg.wShiftFinger * (wrong / 3.0)
                    }
                }
            }

            // R4 (fixed timbre cost) + R3 (bow cost scales) + R10
            if (sd > 0) {
                var f = cfg.crossFactor[Math.min(sd, cfg.crossFactor.length - 1)]
                c += (cfg.wCrossTone + cfg.wCrossBow * ctx.urg) * f

                // R2: a half step across strings sounds wrong, doubly so when
                // one of the two notes is open
                if (ctx.interval > 0 && ctx.interval <= 1) {
                    c += cfg.wHalfStepCross
                    if (a.openOnly || b.openOnly) c += cfg.wHalfStepCrossOpen
                }

                // R5: same finger on a new string leaves a gap in the sound
                if (!a.handFree && !b.handFree && a.topFing === b.topFing) {
                    c += cfg.wSameFinger
                    if (b.mainStr < a.mainStr) c += cfg.wSameFingerDown
                }
            }

            // R6b
            if (a.openOnly && b.openOnly) c += cfg.wOpenRun

            if (a.thumb !== b.thumb) c += cfg.wThumbSwitch * ctx.urg

            return c
        }

        //---------------------------------------------------------------------
        // Viterbi. No clamping, no heuristic look-ahead: the recurrence is
        // already globally optimal for this cost model.
        //---------------------------------------------------------------------
        var dp = [], parent = []
        var row = [], par = []
        for (var j = 0; j < opts[0].length; j++) {
            row.push(noteCost(opts[0][j], events[0]))
            par.push(-1)
        }
        dp.push(row); parent.push(par)

        for (i = 1; i < n; i++) {
            var ctx = contextAt(i)
            row = []; par = []
            for (j = 0; j < opts[i].length; j++) {
                var best = Infinity, bestK = 0
                for (var k = 0; k < opts[i - 1].length; k++) {
                    var tot = dp[i - 1][k] + stepCost(opts[i - 1][k], opts[i][j], ctx)
                    if (tot < best) { best = tot; bestK = k }
                }
                row.push(best + noteCost(opts[i][j], events[i]))
                par.push(bestK)
            }
            dp.push(row); parent.push(par)
        }

        var last = n - 1, bestJ = 0, bestC = Infinity
        for (j = 0; j < opts[last].length; j++) {
            var d = dp[last][j]
            var tie = (d === bestC) && (opts[last][j].anchor < opts[last][bestJ].anchor)
            if (d < bestC || tie) { bestC = d; bestJ = j }
        }

        var path = []
        var cur = bestJ
        for (i = last; i >= 0; i--) {
            path.unshift(opts[i][cur])
            if (i > 0) cur = parent[i][cur]
        }
        return path
    }
    // ===== CORE END =====

    //=========================================================================
    //  SCORE I/O
    //=========================================================================

    // Anything this plugin wrote before, so a second run replaces it instead of
    // stacking labels on top of each other.
    function isOurLabel(s) {
        return /^[EADG](0|1|2|3|4|T)(\s*\([^)]*\))?(\/[EADG](0|1|2|3|4|T))?$/.test(s)
    }

    function clearPrevious(cursor, track, endTick, fullScore) {
        var doomed = []
        while (cursor.segment && (fullScore || cursor.tick < endTick)) {
            var ann = cursor.segment.annotations
            for (var i = 0; ann && i < ann.length; i++) {
                var a = ann[i]
                if (a.type === Element.STAFF_TEXT && a.track === track &&
                    a.text && isOurLabel(a.text))
                    doomed.push(a)
            }
            cursor.next()
        }
        for (var d = 0; d < doomed.length; d++) removeElement(doomed[d])
    }

    function readEvents(cursor, endTick, fullScore) {
        var events = []
        while (cursor.segment && (fullScore || cursor.tick < endTick)) {
            if (cursor.element && cursor.element.type === Element.CHORD) {
                var ch = cursor.element
                var notes = ch.notes
                var live = []
                for (var i = 0; i < notes.length; i++)
                    if (!notes[i].tieBack) live.push(notes[i].pitch)

                if (live.length === 0) {
                    // continuation of a tie: it is the same stopped note, so it
                    // just makes the previous event longer
                    if (events.length > 0)
                        events[events.length - 1].ticks += ch.duration.ticks
                } else {
                    live.sort(function (a, b) { return a - b })
                    events.push({
                        pitches: live,
                        tick:    cursor.tick,
                        ticks:   ch.duration.ticks
                    })
                }
            }
            cursor.next()
        }
        return events
    }

    function writeFingerings(cursor, endTick, fullScore, events, path) {
        var idx = 0
        var shownLabel = ""   // last label actually printed
        var shownBase  = ""   // ...without its position suffix
        var recent     = []   // the last few printed labels, to spot hidden shifts
        var prevPos    = ""
        var prevStr    = -1
        while (cursor.segment && (fullScore || cursor.tick < endTick) && idx < events.length) {
            if (cursor.element && cursor.element.type === Element.CHORD &&
                cursor.tick === events[idx].tick) {

                var opt = path[idx]

                if (colorNotes) {
                    var color = posColors[opt.colorKey] || "#000000"
                    var cn = cursor.element.notes
                    for (var i = 0; i < cn.length; i++) cn[i].color = color
                }

                var label = opt.label

                // In a fast passage the labels do not physically fit between the
                // noteheads, and MuseScore pushes the overlapping ones away into a
                // staircase. There, mark only the change of position and let the
                // note colour carry the string.
                var fast    = cursor.element.duration.ticks < division / 2
                var shifted = !opt.handFree && opt.posName !== prevPos
                var moved   = shifted || (!fast && opt.mainStr !== prevStr)

                // When the notes are long enough to carry a label, every change
                // of finger is worth printing: that is what the player reads.
                // Only in fast passages does it collapse to position changes.
                var worth = labelEveryNote || labelEveryFinger || idx === 0 ||
                            (fast ? moved : true)

                // Name the position on every shift. Without it the same "G1" can
                // mean three different places on the neck within one line, and the
                // player has no way to see the hand moved.
                // Name the position only when the shift would otherwise be
                // invisible: the same string and finger already appeared a few
                // notes ago in a different position, so "G1 ... G1" would read as
                // if the hand had never moved. "Pu" is always redundant, since the
                // T in the label already says thumb.
                var hidden = false
                for (var r = 0; r < recent.length; r++)
                    if (recent[r].base === opt.label && recent[r].pos !== opt.posName)
                        hidden = true
                if ((shifted && hidden) || (showPositionName && !opt.handFree))
                    if (!opt.thumb) label += " (" + positionName(opt.posName) + ")"

                if (worth && label !== shownLabel) {
                    var text = newElement(Element.STAFF_TEXT)
                    text.autoplace = true
                    text.offsetX   = 0.65
                    text.align     = 2
                    text.text      = label
                    cursor.add(text)
                    shownLabel = label
                    shownBase  = opt.label
                    recent.push({base: opt.label, pos: opt.posName})
                    if (recent.length > 4) recent.shift()
                }
                prevStr   = opt.mainStr
                if (!opt.handFree) prevPos = opt.posName
                idx++
            }
            cursor.next()
        }
    }

    onRun: {
        if (!curScore) {
            (typeof quit === 'undefined' ? Qt.quit : quit)()
            return
        }

        var cfg = settings
        cfg.division = division

        var solfege = (stringNaming === "solfege") ||
                      (stringNaming === "auto" && language === "es")
        cfg.stringNames = solfege ? cfg.stringSolfege : cfg.stringLetters

        var cursor = curScore.newCursor()
        var fullScore = false
        var startStaff, endStaff, endTick = 0

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

        function toStart(voice, staff) {
            if (fullScore) cursor.rewind(Cursor.SCORE_START)
            else           cursor.rewind(Cursor.SELECTION_START)
            cursor.voice    = voice
            cursor.staffIdx = staff
        }

        curScore.startCmd()

        for (var staff = startStaff; staff <= endStaff; staff++) {
            for (var voice = 0; voice < 4; voice++) {
                toStart(voice, staff)
                clearPrevious(cursor, staff * 4 + voice, endTick, fullScore)

                toStart(voice, staff)
                var events = readEvents(cursor, endTick, fullScore)
                if (events.length === 0) continue

                var path = computeFingerings(events, cfg)

                toStart(voice, staff)
                writeFingerings(cursor, endTick, fullScore, events, path)
            }
        }

        curScore.endCmd()
        ;(typeof quit === 'undefined' ? Qt.quit : quit)()
    }
}
