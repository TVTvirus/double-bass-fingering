#!/usr/bin/env python3
"""Apply the plugin's fingering engine to a MusicXML file, without MuseScore.

Reads the score, runs the very same computeFingerings() that lives in the .qml,
and writes a copy with string+finger labels and per-position note colours. Handy
for eyeballing the result (export it to PNG with `mscore -o out.png out.musicxml`)
and for checking the engine end to end on a real file.

    python3 tools/apply-musicxml.py in.musicxml out.musicxml
"""
import json
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QML = (ROOT / 'DoubleBassSimandl.qml').read_text(encoding='utf-8')
TICKS_PER_QUARTER = 480

STEP = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def run_engine(events, solfege=False):
    """Call the plugin's own core function under Node and get the path back."""
    core = QML.split('// ===== CORE START =====')[1].split('// ===== CORE END =====')[0]
    marker = 'property var settings: ({'
    start = QML.index(marker) + len(marker)
    cfg_src = QML[start:QML.index('})', start)]

    script = f"""
{core}
const cfg = {{{cfg_src}}};
cfg.division = {TICKS_PER_QUARTER};
cfg.stringNames = {str(solfege).lower()} ? cfg.stringSolfege : cfg.stringLetters;
const events = {json.dumps(events)};
const path = computeFingerings(events, cfg);
console.log(JSON.stringify(path.map(o => ({{
    label: o.label, colorKey: o.colorKey, posName: o.posName,
    handFree: o.handFree, anchor: o.anchor, mainStr: o.mainStr, thumb: o.thumb
}}))));
"""
    out = subprocess.run(['node', '-e', script], capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(f'engine failed:\n{out.stderr}')
    return json.loads(out.stdout)


def colors_from_qml():
    block = QML.split('property var posColors: ({')[1].split('})')[0]
    colors = {}
    for line in block.splitlines():
        line = line.split('//')[0].strip().rstrip(',')
        if ':' in line:
            k, v = line.split(':', 1)
            colors[k.strip().strip('"')] = v.strip().strip('"')
    return colors


def position_names(lang):
    """The same table the plugin uses, read straight out of the .qml."""
    block = QML.split('property var posNames: ({')[1].split('\n    })')[0]
    table, cur = {}, None
    for chunk in block.replace('\n', ' ').split('"'):
        pass
    import re
    for m in re.finditer(r'"(\w\w)":\s*\{([^}]*)\}', block):
        entries = {}
        for k, v in re.findall(r'"([^"]+)":\s*"([^"]*)"', m.group(2)):
            entries[k] = v
        table[m.group(1)] = entries
    return table.get(lang, table.get('en', {}))


def main(src, dst, lang='en'):
    tree = ET.parse(src)
    root = tree.getroot()

    for part in root.findall('part'):
        divisions, transpose = 1, 0
        events, anchors = [], []   # anchors: the <note> elements of each event
        tick = 0

        for measure in part.findall('measure'):
            for attrs in measure.findall('attributes'):
                if attrs.find('divisions') is not None:
                    divisions = int(attrs.find('divisions').text)
                tr = attrs.find('transpose')
                if tr is not None:
                    chromatic = int((tr.findtext('chromatic') or 0))
                    octave = int((tr.findtext('octave-change') or 0))
                    transpose = chromatic + 12 * octave

            for note in measure.findall('note'):
                dur = int(note.findtext('duration') or 0)
                ticks = round(dur * TICKS_PER_QUARTER / divisions)
                is_chord = note.find('chord') is not None

                if note.find('rest') is not None:
                    tick += ticks
                    continue

                pitch = note.find('pitch')
                if pitch is None:
                    tick += ticks
                    continue

                midi = (STEP[pitch.findtext('step')]
                        + int(pitch.findtext('alter') or 0)
                        + (int(pitch.findtext('octave')) + 1) * 12
                        + transpose)          # written -> sounding

                # continuation of a tie: lengthens the previous event
                tied_stop = any(t.get('type') == 'stop'
                                for t in note.findall('./notations/tied'))
                if tied_stop and events and not is_chord:
                    events[-1]['ticks'] += ticks
                    tick += ticks
                    continue

                if is_chord and events:
                    events[-1]['pitches'].append(midi)
                    events[-1]['pitches'].sort()
                    anchors[-1].append(note)
                else:
                    events.append({'pitches': [midi], 'tick': tick, 'ticks': ticks})
                    anchors.append([note])
                    tick += ticks

        if not events:
            continue

        path = run_engine(events, solfege=(lang == 'es'))
        colors = colors_from_qml()
        names = position_names(lang)

        # write labels and colours back into the tree
        # same rule as the plugin: only label where it says something new,
        # otherwise fast passages turn into an unreadable staircase of texts
        shown_label, shown_base, prev_pos, prev_str = None, None, None, -1
        recent = []
        for i, (ev_notes, opt) in enumerate(zip(anchors, path)):
            color = colors.get(opt['colorKey'], '#000000')
            for n in ev_notes:
                n.set('color', color)

            fast = events[i]['ticks'] < TICKS_PER_QUARTER / 2
            shifted = not opt['handFree'] and opt['posName'] != prev_pos
            moved = shifted or (not fast and opt['mainStr'] != prev_str)
            worth = (moved if fast else True) or i == 0

            prev_str = opt['mainStr']
            if not opt['handFree']:
                prev_pos = opt['posName']
            label = opt['label']
            hidden = any(b == label and pz != opt['posName'] for b, pz in recent)
            if shifted and hidden and not opt['thumb']:
                label += f" ({names.get(opt['posName'], opt['posName'])})"
            if not worth or label == shown_label:
                continue
            shown_label, shown_base = label, opt['label']
            recent.append((opt['label'], opt['posName']))
            del recent[:-4]

            note = ev_notes[0]
            measure = next(m for m in part.findall('measure') if note in list(m))
            direction = ET.Element('direction', {'placement': 'above'})
            dtype = ET.SubElement(direction, 'direction-type')
            words = ET.SubElement(dtype, 'words')
            words.set('font-size', '9')
            words.set('color', color)
            words.text = label
            measure.insert(list(measure).index(note), direction)

    tree.write(dst, encoding='UTF-8', xml_declaration=True)
    print(f'escrito {dst}')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else 'en')
