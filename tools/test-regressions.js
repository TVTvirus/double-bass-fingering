const fs = require('fs');
const path = require('path');
const assert = require('assert');
const q = fs.readFileSync(path.join(__dirname, '..', 'DoubleBassSimandl.qml'), 'utf8');
const marker = 'property var settings: ({';
const a = q.indexOf(marker);
const cfg = eval('({' + q.slice(a + marker.length, q.indexOf('})', a)) + '})');
cfg.division = 480;
eval(q.split('// ===== CORE START =====')[1].split('// ===== CORE END =====')[0]);
const event = (pitches, tick = 0, tempo = 2) => ({ pitches, tick, ticks: 480, tempo });
for (const style of ['study', 'arco']) {
    const c = {...cfg, playingStyle: style};
    for (let lo = 28; lo < 60; lo++) for (let hi = lo + 1; hi < 65; hi++) {
        const o = computeFingerings([event([lo, hi])], c)[0];
        if (!o.dead) {
            assert.equal(o.parts.length, 2, 'Never drop a chord note');
            assert.equal(o.parts[1].s - o.parts[0].s, 1, 'Adjacent strings for arco/study');
        }
    }
}
assert(computeFingerings([event([28, 29])], cfg)[0].dead);
assert(computeFingerings([event([28, 33, 38])], cfg)[0].dead);
assert.equal(computeFingerings([event([33, 38])], cfg)[0].label, 'A0/D0');
assert.equal(computeFingerings([{...event([43]), ticks:1920}], cfg)[0].label, 'G0');
const body = q.match(/function isOurLabel\(s\) \{([\s\S]*?)\n    \}/)[1];
const isOurLabel = new Function('s', body);
for (const s of ['E1', 'Mi1', 'Re0/Sol1', 'Re1/Sol4 (1ª)', 'G1 (3rd)', '?']) assert(isOurLabel(s), s);
for (const s of ['Allegro', 'Mi mayor', 'D7', 'Solo']) assert(!isOurLabel(s), s);
// Tempo must affect actual choices, not only be collected from the score.
let differences = 0;
for (let p = 30; p < 56; p++) {
    const notes = [p, p + 2, p + 4, p + 5, p + 7];
    const run = tempo => computeFingerings(notes.map((n,i) => event([n], i*480, tempo)), cfg).map(o => o.label).join();
    if (run(1) !== run(3)) differences++;
}
assert(differences > 0, '60 and 180 BPM must produce different choices on some passages');
console.log('PASS: chord integrity, adjacent strings, open strings, Spanish cleanup, tempo sensitivity');
