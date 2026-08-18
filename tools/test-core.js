#!/usr/bin/env node
// Extracts the pure-JS core out of DoubleBassSimandl.qml and runs it against
// real double bass passages, so the algorithm can be checked without opening
// MuseScore. Run: node tools/test-core.js

const fs = require('fs');
const path = require('path');

const QML = fs.readFileSync(path.join(__dirname, '..', 'DoubleBassSimandl.qml'), 'utf8');

function extract(open, close) {
  const a = QML.indexOf(open), b = QML.indexOf(close);
  if (a < 0 || b < 0) throw new Error(`marker not found: ${open}`);
  return QML.slice(a + open.length, b);
}

// --- the algorithm, verbatim from the plugin -------------------------------
const core = extract('// ===== CORE START =====', '// ===== CORE END =====');

// --- the config block, turned back into a plain object ---------------------
const cfgStart = QML.indexOf('property var settings: ({');
const cfgEnd = QML.indexOf('})', cfgStart);
const cfgSrc = QML.slice(cfgStart + 'property var settings: ({'.length, cfgEnd);

const CFG = eval(`({${cfgSrc}})`);
CFG.division = 480; // MuseScore ticks per quarter note

eval(core);

// ---------------------------------------------------------------------------
const NAMES = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
const nm = p => NAMES[p % 12] + (Math.floor(p / 12) - 1);

const Q = 480, E = 240, S = 120, H = 960, W = 1920;

// build events from [pitch, duration] pairs, laid end to end
function seq(pairs) {
  let tick = 0;
  return pairs.map(([p, d]) => {
    const ev = { pitches: Array.isArray(p) ? p : [p], tick, ticks: d };
    tick += d;
    return ev;
  });
}
// same, but with a rest of `gap` ticks before the note
function seqGaps(triples) {
  let tick = 0;
  return triples.map(([p, d, gap]) => {
    tick += (gap || 0);
    const ev = { pitches: Array.isArray(p) ? p : [p], tick, ticks: d };
    tick += d;
    return ev;
  });
}

function metrics(path_) {
  let shifts = 0, crosses = 0;
  for (let i = 1; i < path_.length; i++) {
    if (path_[i].anchor !== path_[i-1].anchor) shifts++;
    if (path_[i].mainStr !== path_[i-1].mainStr) crosses++;
  }
  return { shifts, crosses };
}

function run(title, events, expectation) {
  const path_ = computeFingerings(events, CFG);
  const notes = events.map(e => nm(e.pitches[e.pitches.length - 1]).padStart(4));
  const labs  = path_.map(o => o.label.padStart(4));
  const poss  = path_.map(o => (o.handFree ? '·' : o.posName).padStart(4));
  console.log(`\n── ${title}`);
  if (expectation) console.log(`   se espera: ${expectation}`);
  console.log(`   nota  ${notes.join(' ')}`);
  console.log(`   dedo  ${labs.join(' ')}`);
  console.log(`   pos   ${poss.join(' ')}`);
  const m = metrics(path_);
  console.log(`   -> ${m.shifts} shifts, ${m.crosses} cruces de cuerda`);
  return path_;
}

// ===========================================================================
console.log('CASOS DE PRUEBA, contrabajo, pitches sonantes (E1=28 A1=33 D2=38 G2=43)');

// 1. Escala de Sol mayor ascendente en la cuerda G, negras.
//    Simandl clásico: subir llegando con el dedo 1 (1-1-4 / R7).
run('1. Escala de Sol mayor ascendente (negras, cuerda G)',
    seq([[43,Q],[45,Q],[47,Q],[48,Q],[50,Q],[52,Q],[54,Q],[55,Q]]),
    'subir por la cuerda G llegando con dedo 1 a cada posición nueva');

// 2. La misma escala en semicorcheas: R3 dice quedarse en posición y cruzar.
run('2. La misma escala en semicorcheas',
    seq([[43,S],[45,S],[47,S],[48,S],[50,S],[52,S],[54,S],[55,S]]),
    'menos shifts que en el caso 1, aunque suponga cruzar');

// 3. Escala de Do mayor grave, la zona natural de 1ª/½ posición.
run('3. Do mayor grave C1..C2 (negras)',
    seq([[36,Q],[38,Q],[40,Q],[41,Q],[43,Q],[45,Q],[47,Q],[48,Q]]),
    'quedarse abajo, cruzando E→A→D, sin subir de posición');

// 4. R2: semitono entre dos notas que caen en cuerdas distintas.
//    G#2(44)=D fret6 / G fret1 ; A2(45)=D fret7 / G fret2
run('4. Semitono G#2–A2 repetido (blancas)',
    seq([[44,H],[45,H],[44,H],[45,H]]),
    'las dos notas en la MISMA cuerda, nunca cruzando para un semitono');

// 5. R6/R6b: pasaje lento con dos cuerdas al aire disponibles seguidas.
run('5. D2–G2 lentas (redondas), ambas disponibles al aire',
    seq([[38,W],[43,W],[38,W],[43,W]]),
    'evitar dos cuerdas al aire seguidas en notas largas: pisar alguna');

// 6. Las mismas dos notas rápidas: ahí el aire sí vale.
run('6. D2–G2 en semicorcheas',
    seq([[38,S],[43,S],[38,S],[43,S]]),
    'aquí sí puede usar las cuerdas al aire, son notas de paso');

// 7. R15 + silencio: un shift grande con un silencio largo por delante.
run('7. Salto de registro con 2 compases de silencio en medio',
    seqGaps([[33,Q,0],[35,Q,0],[36,Q,0],[62,Q,W*2],[64,Q,0],[65,Q,0]]),
    'abajo en 1ª posición, y tras el silencio subir sin pagar el viaje');

// 8. Pulgar: pasaje agudo por encima de G3 (55).
run('8. Pasaje agudo D4–G4 (negras)',
    seq([[62,Q],[64,Q],[65,Q],[67,Q],[65,Q],[64,Q]]),
    'posición de pulgar, sin entrar y salir de ella todo el rato');

// 9. Arpegio rápido de Re mayor: debería cruzar cuerdas quieto en posición.
run('9. Arpegio de Re mayor en semicorcheas',
    seq([[38,S],[42,S],[45,S],[50,S],[45,S],[42,S],[38,S],[42,S]]),
    'una sola posición, cruzando D→G');

// 10. Doble cuerda.
run('10. Dobles cuerdas (quintas y sextas)',
    seq([[[38,45],H],[[40,47],H],[[41,48],H]]),
    'dos etiquetas por acorde, ambas notas en la misma posición');

// 11. Nota ligada / repetida larga y luego movimiento rápido.
run('11. Nota larga y luego corrida rápida',
    seq([[43,W],[45,S],[47,S],[48,S],[50,S],[52,S],[54,S],[55,S],[57,S]]),
    'la nota larga pisada (no al aire), la corrida quieta en posición');

// 12. El caso que rompía la versión vieja: melodía que sólo necesita
//     un shift de 1ª a 2ª posición, y que la versión vieja resolvía
//     cruzando de cuerda porque medía mal la distancia.
run('12. Melodía de 1ª a 2ª posición (negras, cuerda D)',
    seq([[40,Q],[41,Q],[43,Q],[41,Q],[40,Q],[38,Q]]),
    'un shift corto y quedarse; no saltar de cuerda por un tono');

// ===========================================================================
// 13. La prueba cuantitativa de R3/R4: el MISMO pasaje a tres velocidades.
//     Al acelerar, el número de shifts tiene que bajar y el de cruces subir.
console.log('\n══ 13. El mismo pasaje a tres velocidades (R3 vs R4)');
console.log('   (frase que cabe entera en 1ª posición cruzando D->G)');
// E2 F#2 A2 B2: las cuatro caben en 1ª posición cruzando D->G,
// y también en la sola cuerda D repartidas en varias posiciones.
const frase = [40,42,45,47,45,42,40,42,45,47,45,42];
for (const [nombre, dur] of [['blancas', H], ['negras', Q], ['semicorcheas', S]]) {
  const p = computeFingerings(seq(frase.map(x => [x, dur])), CFG);
  const m = metrics(p);
  console.log(`   ${nombre.padEnd(13)} ${String(m.shifts).padStart(2)} shifts, ` +
              `${String(m.crosses).padStart(2)} cruces   ${p.map(o => o.label).join(' ')}`);
}

console.log('');
