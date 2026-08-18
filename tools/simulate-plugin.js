#!/usr/bin/env node
// Runs the plugin end to end against a stubbed MuseScore API: readEvents,
// computeFingerings and writeFingerings, exactly as they appear in the .qml.
//
// This catches runtime errors in the score-facing half of the plugin, which
// qml-check.py cannot see (it only parses) and test-core.js does not touch
// (it only runs the engine). MuseScore reports such errors nowhere the user
// can see: the plugin just silently does nothing.
//
//     node tools/simulate-plugin.js

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const QML = fs.readFileSync(path.join(ROOT, 'DoubleBassSimandl.qml'), 'utf8');

// ---- stub of the MuseScore plugin API --------------------------------------
const Element = { STAFF_TEXT: 'staff-text', CHORD: 'chord', REST: 'rest' };
const Cursor = { SELECTION_START: 0, SELECTION_END: 1, SCORE_START: 2 };
const division = 480;

let added = [];      // every text the plugin writes
let removed = [];    // every element it deletes
let colored = [];    // every note it recolours

function newElement(type) {
    return { type, text: '', autoplace: false, offsetX: 0, align: 0, track: 0 };
}
function removeElement(e) { removed.push(e); }

function makeNote(pitch, tieBack) {
    return { pitch, tieBack: tieBack || null,
             set color(c) { colored.push({ pitch, color: c }); },
             get color() { return null; } };
}

// One staff, one voice, a handful of segments.
function buildScore(spec) {
    let tick = 0;
    const segments = spec.map(s => {
        const seg = { tick, annotations: [], element: null };
        if (s.rest) {
            seg.element = { type: Element.REST, duration: { ticks: s.ticks } };
        } else {
            seg.element = {
                type: Element.CHORD,
                duration: { ticks: s.ticks },
                notes: s.pitches.map(p => makeNote(p, s.tieBack))
            };
        }
        tick += s.ticks;
        return seg;
    });
    return { segments, lastTick: tick };
}

function makeCursor(score) {
    let i = 0;
    return {
        voice: 0,
        staffIdx: 0,
        get segment() { return i < score.segments.length ? score.segments[i] : null; },
        get element() { return this.segment ? this.segment.element : null; },
        get tick() { return this.segment ? this.segment.tick : score.lastTick; },
        rewind() { i = 0; },
        next() { i++; return i < score.segments.length; },
        add(el) {
            if (!this.segment) throw new Error('add() with no segment');
            added.push({ tick: this.tick, text: el.text });
            this.segment.annotations.push(el);
        }
    };
}

// ---- pull the plugin's own functions out of the .qml ------------------------
const start = QML.indexOf('    function isOurLabel');
const end = QML.lastIndexOf('}');
let body = QML.slice(start, end);

// property blocks the functions read
function propObject(name) {
    const marker = `property var ${name}: ({`;
    const a = QML.indexOf(marker) + marker.length;
    // newline before the close: the last entry may end in a // comment
    return `({${QML.slice(a, QML.indexOf('\n    })', a))}\n})`;
}
const settings = eval(propObject('settings'));
const posColors = eval(propObject('posColors'));
const posNames = eval(propObject('posNames'));

const coreSrc = QML.split('// ===== CORE START =====')[1]
                   .split('// ===== CORE END =====')[0];

let language = 'en';
let stringNaming = 'auto';
let colorNotes = true;
let labelEveryNote = false;
let labelEveryFinger = false;
let showPositionName = false;

function positionName(key) {
    const table = posNames[language] || posNames['en'];
    return table[key] || key;
}

eval(coreSrc);
// onRun is a signal handler in QML; here we just need the functions it calls
eval(body.slice(0, body.indexOf('onRun:')));

// ---- the cases -------------------------------------------------------------
const Q = 480, S = 120, H = 960, W = 1920;

const CASES = {
    'escala de negras': [
        { pitches: [43], ticks: Q }, { pitches: [45], ticks: Q },
        { pitches: [47], ticks: Q }, { pitches: [48], ticks: Q },
        { pitches: [50], ticks: Q }, { pitches: [52], ticks: Q }
    ],
    'semicorcheas (etiquetas aligeradas)': [
        { pitches: [38], ticks: S }, { pitches: [42], ticks: S },
        { pitches: [45], ticks: S }, { pitches: [50], ticks: S },
        { pitches: [45], ticks: S }, { pitches: [42], ticks: S }
    ],
    'con silencios': [
        { pitches: [33], ticks: Q }, { rest: true, ticks: W },
        { pitches: [62], ticks: Q }, { pitches: [64], ticks: Q }
    ],
    'dobles cuerdas': [
        { pitches: [38, 45], ticks: H }, { pitches: [40, 47], ticks: H }
    ],
    'notas ligadas': [
        { pitches: [43], ticks: Q },
        { pitches: [43], ticks: Q, tieBack: {} },
        { pitches: [45], ticks: Q }
    ],
    'registro agudo (pulgar)': [
        { pitches: [62], ticks: Q }, { pitches: [64], ticks: Q },
        { pitches: [65], ticks: Q }, { pitches: [67], ticks: Q }
    ],
    'una sola nota': [{ pitches: [43], ticks: W }],
    'fuera de rango (grave)': [
        { pitches: [20], ticks: Q }, { pitches: [43], ticks: Q }
    ],
    'fuera de rango (agudo)': [
        { pitches: [90], ticks: Q }, { pitches: [43], ticks: Q }
    ],
    'solo silencios': [{ rest: true, ticks: W }]
};

let failures = 0;
for (const [lang, naming] of [['en', 'auto'], ['es', 'auto'], ['en', 'solfege']]) {
    language = lang;
    stringNaming = naming;
    const solfege = naming === 'solfege' || (naming === 'auto' && lang === 'es');
    const cfg = Object.assign({}, settings);
    cfg.division = division;
    cfg.stringNames = solfege ? cfg.stringSolfege : cfg.stringLetters;

    for (const [name, spec] of Object.entries(CASES)) {
        added = []; removed = []; colored = [];
        const score = buildScore(spec);
        const cursor = makeCursor(score);
        try {
            cursor.rewind();
            clearPrevious(cursor, 0, score.lastTick, true);
            cursor.rewind();
            const events = readEvents(cursor, score.lastTick, true);
            if (events.length === 0) {
                console.log(`  [${lang}/${naming}] ${name}: sin notas, no escribe (ok)`);
                continue;
            }
            const p = computeFingerings(events, cfg);
            cursor.rewind();
            writeFingerings(cursor, score.lastTick, true, events, p);
            const labels = added.map(a => a.text).join(' ');
            console.log(`  [${lang}/${naming}] ${name}: ${added.length} etiquetas, ` +
                        `${colored.length} notas coloreadas | ${labels}`);
        } catch (e) {
            failures++;
            console.log(`  [${lang}/${naming}] ${name}: ✗ ${e.message}`);
        }
    }
}

// re-running must replace its own labels, not stack them
{
    language = 'en'; stringNaming = 'auto';
    const cfg = Object.assign({}, settings);
    cfg.division = division;
    cfg.stringNames = cfg.stringLetters;
    const score = buildScore(CASES['escala de negras']);
    const cursor = makeCursor(score);
    let counts = [];
    for (let run = 0; run < 2; run++) {
        added = [];
        cursor.rewind();
        clearPrevious(cursor, 0, score.lastTick, true);
        // clearPrevious collects; emulate MuseScore actually removing them
        for (const seg of score.segments)
            seg.annotations = seg.annotations.filter(a => !removed.includes(a));
        cursor.rewind();
        const events = readEvents(cursor, score.lastTick, true);
        const p = computeFingerings(events, cfg);
        cursor.rewind();
        writeFingerings(cursor, score.lastTick, true, events, p);
        counts.push(score.segments.reduce((n, s) => n + s.annotations.length, 0));
    }
    const ok = counts[0] === counts[1];
    if (!ok) failures++;
    console.log(`\n  reejecutar: ${counts[0]} -> ${counts[1]} etiquetas ` +
                `${ok ? '(ok, las reemplaza)' : '✗ SE ACUMULAN'}`);
}

console.log(failures === 0
    ? '\n✓ el plugin corre entero sin errores de runtime'
    : `\n✗ ${failures} fallo(s)`);
process.exit(failures === 0 ? 0 : 1);
