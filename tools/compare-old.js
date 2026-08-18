#!/usr/bin/env node
// Runs v1.1 and v2.0 side by side on the same passages.
// v1.1 is pulled straight out of git so the comparison is honest.
// Run: node tools/compare-old.js

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const QML = fs.readFileSync(path.join(ROOT, 'DoubleBassSimandl.qml'), 'utf8');

// ---- new engine ------------------------------------------------------------
const core = QML.slice(
  QML.indexOf('// ===== CORE START =====') + '// ===== CORE START ====='.length,
  QML.indexOf('// ===== CORE END ====='));
const cfgStart = QML.indexOf('property var settings: ({');
const CFG = eval(`({${QML.slice(cfgStart + 'property var settings: ({'.length, QML.indexOf('})', cfgStart))}})`);
CFG.division = 480;
eval(core);

// ---- old engine, pinned to the last v1.1 commit ----------------------------
// Pinned rather than HEAD: once v2.0 is committed, HEAD is the new engine and
// the comparison would silently be v2.0 against itself.
const V1 = '0e1e951';
const OLD = execSync(`git show ${V1}:DoubleBassSimandl.qml`, { cwd: ROOT }).toString();
const oldFns = OLD.slice(OLD.indexOf('function buildSimandlMap'), OLD.indexOf('function octave'));
const openStrings = [28, 33, 38, 43];
const stringNames = ['E', 'A', 'D', 'G'];
eval(oldFns);

function oldPath(pitches) {
  return bestPath(pitches, buildSimandlMap());
}

// ---------------------------------------------------------------------------
const NAMES = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
const nm = p => NAMES[p % 12] + (Math.floor(p / 12) - 1);
const Q = 480, S = 120, H = 960, W = 1920;

function shiftsOf(path_, key) {
  let s = 0;
  for (let i = 1; i < path_.length; i++) if (path_[i][key] !== path_[i-1][key]) s++;
  return s;
}
// the old engine has no anchors, only position names; map them to a fret so the
// two can be compared on the same scale
const OLDANCHOR = {'Ab':-1,'½':1,'1ª':2,'2ª':3,'3ª':5,'4ª':7,'5ª':8,'6ª':10};

function compare(title, pitches, dur) {
  const events = pitches.map((p, i) => ({ pitches: [p], tick: i * dur, ticks: dur }));
  const nueva = computeFingerings(events, CFG);
  const vieja = oldPath(pitches);

  const w = 5;
  console.log(`\n── ${title}  (${dur === S ? 'semicorcheas' : dur === H ? 'blancas' : 'negras'})`);
  console.log(`   nota   ${pitches.map(p => nm(p).padStart(w)).join('')}`);
  console.log(`   v1.1   ${vieja.map(o => (o.stringName + o.finger).padStart(w)).join('')}`);
  console.log(`          ${vieja.map(o => o.pos.padStart(w)).join('')}`);
  console.log(`   v2.0   ${nueva.map(o => o.label.padStart(w)).join('')}`);
  console.log(`          ${nueva.map(o => (o.handFree ? '·' : o.posName).padStart(w)).join('')}`);

  let so = 0;
  for (let i = 1; i < vieja.length; i++)
    if (OLDANCHOR[vieja[i].pos] !== OLDANCHOR[vieja[i-1].pos]) so++;
  const co = shiftsOf(vieja, 'stringIdx');
  const sn = shiftsOf(nueva, 'anchor');
  const cn = shiftsOf(nueva, 'mainStr');
  console.log(`          v1.1: ${so} shifts / ${co} cruces      v2.0: ${sn} shifts / ${cn} cruces`);
}

console.log('v1.1 vs v2.0 sobre los mismos pasajes');

compare('Frase que cabe entera en 1ª posición', [40,42,45,47,45,42,40,42], S);
compare('La misma frase, lenta',                [40,42,45,47,45,42,40,42], H);
compare('Do mayor grave',                       [36,38,40,41,43,45,47,48], Q);
compare('Semitono G#2–A2 (nunca cruzar)',       [44,45,44,45],             H);
compare('Melodía de 1ª a 2ª posición',          [40,41,43,41,40,38],       Q);
compare('Arpegio de Re mayor rápido',           [38,42,45,50,45,42,38,42], S);
compare('Escala de Sol mayor',                  [43,45,47,48,50,52,54,55], Q);
compare('Registro agudo (pide pulgar)',         [62,64,65,67,65,64],       Q);
console.log('');
