#!/usr/bin/env python3
"""Build the demo score used for the README screenshots.

Each system is one case the fingering engine is supposed to get right, with a
caption saying what it demonstrates. Captions go below the staff so they never
collide with the fingerings, which the plugin writes above it.

    python3 tools/make-demo-score.py out.musicxml [en|es]
"""
import sys

STEP = {0: ('C', 0), 1: ('C', 1), 2: ('D', 0), 3: ('D', 1), 4: ('E', 0),
        5: ('F', 0), 6: ('F', 1), 7: ('G', 0), 8: ('G', 1), 9: ('A', 0),
        10: ('A', 1), 11: ('B', 0)}
TYPE = {1: '16th', 2: 'eighth', 4: 'quarter', 8: 'half', 16: 'whole'}
Q, S, H, W = 4, 1, 8, 16

TITLE = {'en': 'Double Bass Simandl, what the engine decides',
         'es': 'Double Bass Simandl, lo que decide el motor'}
PART = {'en': 'Double Bass', 'es': 'Contrabajo'}

# (caption_en, caption_es, [(pitch(es), duration), ...])
CASES = [
    ("Low register: stays down, crosses strings instead of shifting",
     "Registro grave: se queda abajo y cruza cuerdas en vez de hacer shift",
     [(36, Q), (38, Q), (40, Q), (41, Q), (43, Q), (45, Q), (47, Q), (48, Q)]),

    ("Ascending scale: shifts up landing on the 1st finger",
     "Escala ascendente: sube llegando con el dedo 1",
     [(43, Q), (45, Q), (47, Q), (48, Q), (50, Q), (52, Q), (54, Q), (55, Q)]),

    ("Fast arpeggio: one hand position, crossing D-G, labels thinned out",
     "Arpegio rápido: una sola posición cruzando Re-Sol, etiquetas aligeradas",
     [(38, S), (42, S), (45, S), (50, S), (45, S), (42, S), (38, S), (42, S),
      (38, S), (42, S), (45, S), (50, S), (45, S), (42, S), (38, S), (42, S)]),

    ("Half step: never played across two strings",
     "Semitono: nunca se toca cruzando dos cuerdas",
     [(44, H), (45, H), (44, H), (45, H), (47, H), (48, H), (47, W)]),

    ("High register: thumb position, entered once and kept",
     "Registro agudo: posición de pulgar, se entra una vez y se mantiene",
     [(62, Q), (64, Q), (65, Q), (67, Q), (65, Q), (64, Q), (62, Q), (60, Q),
      (62, H), (67, H)]),

    ("Double stops: both notes under the same hand position",
     "Dobles cuerdas: las dos notas bajo la misma posición de la mano",
     [([38, 45], H), ([40, 47], H), ([41, 48], H), ([43, 50], H),
      ([40, 47], W)]),

    ("Long notes: stopped rather than open, so the tone matches",
     "Notas largas: pisadas en vez de al aire, para que el timbre case",
     [(38, W), (43, W), (38, H), (43, H), (45, W)]),
]


def pitch_xml(midi):
    step, alter = STEP[midi % 12]
    alter_tag = f'<alter>{alter}</alter>' if alter else ''
    return (f'<pitch><step>{step}</step>{alter_tag}'
            f'<octave>{midi // 12 - 1}</octave></pitch>')


def note_xml(midis, dur):
    if not isinstance(midis, list):
        midis = [midis]
    out = []
    for i, m in enumerate(midis):
        chord = '<chord/>' if i else ''
        out.append(f'<note>{chord}{pitch_xml(m + 12)}<duration>{dur}</duration>'
                   f'<voice>1</voice><type>{TYPE[dur]}</type></note>')
    return ''.join(out)


def build(lang):
    measures, number = [], 0
    for case_i, (cap_en, cap_es, notes) in enumerate(CASES):
        caption = cap_en if lang == 'en' else cap_es

        # split the case into 4/4 bars
        bars, bar, filled = [], [], 0
        for midis, dur in notes:
            bar.append((midis, dur))
            filled += dur
            if filled >= 16:
                bars.append(bar)
                bar, filled = [], 0
        if bar:
            bars.append(bar)

        for bar_i, bar in enumerate(bars):
            number += 1
            head = ''
            if number == 1:
                head = ('<attributes><divisions>4</divisions>'
                        '<key><fifths>0</fifths></key>'
                        '<time><beats>4</beats><beat-type>4</beat-type></time>'
                        '<clef><sign>F</sign><line>4</line></clef>'
                        '<transpose><diatonic>0</diatonic><chromatic>0</chromatic>'
                        '<octave-change>-1</octave-change></transpose></attributes>')
            # every case starts on a new system, so each caption sits under its own line
            if bar_i == 0 and case_i > 0:
                head += '<print new-system="yes"/>'

            cap = ''
            if bar_i == 0:
                cap = ('<direction placement="below"><direction-type>'
                       f'<words font-size="8" font-style="italic" color="#777777">'
                       f'{caption}</words></direction-type></direction>')

            body = ''.join(note_xml(m, d) for m, d in bar)
            measures.append(f'<measure number="{number}">{head}{cap}{body}</measure>')

    return f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="4.0">
  <work><work-title>{TITLE[lang]}</work-title></work>
  <defaults><system-layout><system-distance>90</system-distance></system-layout></defaults>
  <part-list><score-part id="P1">
    <part-name>{PART[lang]}</part-name>
    <score-instrument id="P1-I1"><instrument-name>Contrabass</instrument-name></score-instrument>
    <midi-instrument id="P1-I1"><midi-program>44</midi-program></midi-instrument>
  </score-part></part-list>
  <part id="P1">{''.join(measures)}</part>
</score-partwise>'''


if __name__ == '__main__':
    lang = sys.argv[2] if len(sys.argv) > 2 else 'en'
    open(sys.argv[1], 'w', encoding='utf-8').write(build(lang))
    print(f'{sys.argv[1]} ({lang})')
