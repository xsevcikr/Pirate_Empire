#!/usr/bin/env python3
"""The music of Pirate Empire: every tune is written out below as notes and chords, arranged for a small pirate band
(accordion, fiddle, tin whistle, crew choir, tuba, bodhran) or a full orchestra, written to MIDI and played by
FluidSynth through the FluidR3 GM soundfont, then encoded to Ogg Vorbis with ffmpeg.

Licences (see audio/LICENSES.md):
  * "Drunken Sailor" is a traditional sea shanty (19th century) and is in the public domain.
  * Every other tune here was written for this game and is released under CC0 with the rest of the project.
  * FluidR3_GM.sf2 by Frank Wen is MIT licensed, so the rendered recordings are free to ship.

Needs: pip install mido; apt install fluidsynth fluid-soundfont-gm ffmpeg.

    python3 tools/gen_music.py              # writes every track to audio/music/*.ogg
    python3 tools/gen_music.py menu_theme   # only the named tracks
    python3 tools/gen_music.py --list       # the track names
"""
import os, random, re, subprocess, sys, tempfile

import mido

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio", "music")
SOUNDFONT = os.environ.get("SOUNDFONT", "/usr/share/sounds/sf2/FluidR3_GM.sf2")
RATE = 32000
TPB = 480          # MIDI ticks per quarter note
EIGHTH = TPB // 2  # the unit every duration below is counted in

# ---- notation ------------------------------------------------------------------------------------------------
# A melody is bars separated by "|"; each note is NAME[#|b]OCTAVE:EIGHTHS ("A4:2" is a quarter note on A above
# middle C, "r:2" a quarter rest). Chords are one name per bar, or two split by "/" for half a bar each.

PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
METER = {"4/4": 8, "6/8": 6, "3/4": 6, "2/4": 4}


def note_num(tok):
    m = re.fullmatch(r"([A-G])([#b]?)(-?\d)", tok)
    if not m:
        raise ValueError("bad note " + tok)
    n = PC[m.group(1)] + {"#": 1, "b": -1, "": 0}[m.group(2)]
    return 12 * (int(m.group(3)) + 1) + n


def parse_melody(text, meter, name):
    bars = [b.split() for b in text.strip().strip("|").split("|")]
    out = []  # (bar, start_eighth, length_eighths, midi or None)
    for i, bar in enumerate(bars):
        at = 0
        for tok in bar:
            pitch, dur = tok.split(":")
            d = float(dur)
            out.append((i, at, d, None if pitch == "r" else note_num(pitch)))
            at += d
        if abs(at - METER[meter]) > 1e-6:
            raise ValueError("%s: bar %d has %s eighths, %s wants %d" % (name, i + 1, at, meter, METER[meter]))
    return out, len(bars)


def chord_notes(name):
    m = re.fullmatch(r"([A-G])([#b]?)(m|dim|sus4|7|m7)?", name)
    if not m:
        raise ValueError("bad chord " + name)
    root = PC[m.group(1)] + {"#": 1, "b": -1, "": 0}[m.group(2)]
    q = m.group(3) or ""
    ivs = {"": [0, 4, 7], "m": [0, 3, 7], "dim": [0, 3, 6], "sus4": [0, 5, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10]}[q]
    return root, ivs


def parse_chords(text, bars, name):
    toks = text.split()
    if len(toks) != bars:
        raise ValueError("%s: %d chord bars for %d melody bars" % (name, len(toks), bars))
    return [t.split("/") for t in toks]


def voicing(root, ivs, low=55):
    """Close position with every note at or above `low`."""
    notes = []
    for iv in ivs:
        n = root + iv
        while n < low:
            n += 12
        while n >= low + 12:
            n -= 12
        notes.append(n)
    return sorted(notes)


# ---- tunes ---------------------------------------------------------------------------------------------------

TUNES = {
    # The game's own theme: a broad minor 6/8 tune for the title screen and the big moments.
    "empire": {
        "meter": "6/8",
        "melody": """D5:3 A4:2 D5:1 | F5:2 E5:1 D5:2 A4:1 | Bb4:2 C5:1 D5:2 Bb4:1 | C5:3 G4:3 |
                     D5:3 A4:2 D5:1 | F5:2 G5:1 A5:2 F5:1 | G5:2 F5:1 E5:2 C#5:1 | D5:6 |
                     A5:3 F5:2 A5:1 | G5:3 E5:2 C5:1 | F5:2 E5:1 D5:2 A4:1 | Bb4:3 D5:3 |
                     G5:2 F5:1 E5:2 D5:1 | F5:2 E5:1 D5:2 F5:1 | E5:2 D5:1 C#5:2 E5:1 | D5:6""",
        "chords": "Dm Dm Bb C Dm Dm Gm/A Dm F C Dm Bb Gm Dm A Dm",
    },
    # Traditional, public domain.
    "drunken_sailor": {
        "meter": "4/4",
        "melody": """A4:2 A4:1 A4:1 A4:2 A4:1 A4:1 | A4:2 D4:2 F4:2 A4:2 | G4:2 G4:1 G4:1 G4:2 G4:1 G4:1 | G4:2 C4:2 E4:2 G4:2 |
                     A4:2 A4:1 A4:1 A4:2 A4:1 A4:1 | A4:2 B4:2 C5:2 D5:2 | C5:2 A4:2 G4:2 E4:2 | D4:4 D4:4 |
                     A4:4 A4:2 A4:2 | A4:2 D4:2 F4:2 A4:2 | G4:4 G4:2 G4:2 | G4:2 C4:2 E4:2 G4:2 |
                     A4:4 A4:2 A4:2 | A4:2 B4:2 C5:2 D5:2 | C5:2 A4:2 G4:2 E4:2 | D4:4 D4:4""",
        "chords": "Dm Dm C C Dm Dm C Dm Dm Dm C C Dm Dm C Dm",
    },
    # A capstan shanty in G: call in the first half, the crew's answer in the second.
    "haul_the_anchor": {
        "meter": "4/4",
        "melody": """D4:2 G4:2 G4:2 B4:2 | A4:2 G4:2 E4:2 D4:2 | G4:2 B4:2 D5:2 B4:2 | A4:6 r:2 |
                     D4:2 G4:2 G4:2 B4:2 | A4:2 G4:2 E4:2 G4:2 | A4:2 B4:2 A4:2 F#4:2 | G4:6 r:2 |
                     D5:3 D5:1 B4:2 G4:2 | C5:3 C5:1 A4:2 F#4:2 | B4:2 G4:2 A4:2 B4:2 | A4:6 D4:2 |
                     G4:3 G4:1 B4:2 D5:2 | E5:2 D5:2 B4:2 G4:2 | A4:2 B4:2 A4:2 F#4:2 | G4:6 r:2""",
        "chords": "G C/G G D G C D G G D G D G C D G",
    },
    # A quick jig in A dorian for open water and the merchant lanes.
    "pieces_of_eight": {
        "meter": "6/8",
        "melody": """E5:2 A4:1 A4:2 B4:1 | C5:2 B4:1 A4:2 G4:1 | E5:2 A4:1 A4:2 B4:1 | C5:1 B4:1 A4:1 G4:3 |
                     E5:2 A4:1 A4:2 B4:1 | C5:2 D5:1 E5:2 G5:1 | E5:2 D5:1 B4:2 G4:1 | A4:3 A4:3 |
                     A5:2 E5:1 E5:2 A5:1 | G5:2 E5:1 D5:2 B4:1 | A5:2 E5:1 E5:2 G5:1 | E5:1 D5:1 B4:1 G4:3 |
                     A5:2 E5:1 E5:2 A5:1 | G5:2 E5:1 D5:2 E5:1 | G5:2 E5:1 D5:1 B4:1 G4:1 | A4:3 A4:3""",
        "chords": "Am Am Am G Am Am Em/G Am Am G Am G Am G Em/G Am",
    },
    # A slow hauling song in E minor: the long pull on the halyard, the bang of the boots.
    "black_gale": {
        "meter": "4/4",
        "melody": """E4:2 G4:2 A4:2 B4:2 | B4:3 A4:1 G4:2 E4:2 | D4:2 E4:2 G4:2 A4:2 | B4:6 r:2 |
                     E5:2 D5:2 B4:2 A4:2 | G4:3 A4:1 B4:2 G4:2 | A4:2 G4:2 F#4:2 D4:2 | E4:6 r:2 |
                     B4:2 B4:2 E5:2 E5:2 | D5:3 B4:1 A4:2 B4:2 | G4:2 A4:2 B4:2 D5:2 | E5:6 r:2 |
                     E5:2 D5:2 B4:2 A4:2 | G4:3 E4:1 G4:2 A4:2 | B4:2 A4:2 F#4:2 D4:2 | E4:6 r:2""",
        "chords": "Em Em D Em Em C D Em Em D G C Em C D Em",
    },
    # A waltz for the harbour: rum, rope and a crooked smile.
    "rum_and_rope": {
        "meter": "3/4",
        "melody": """D4:2 G4:2 B4:2 | A4:3 G4:1 F#4:2 | G4:2 B4:2 D5:2 | C5:4 A4:2 |
                     B4:2 C5:2 D5:2 | E5:3 D5:1 C5:2 | B4:2 A4:2 G4:2 | A4:6 |
                     D4:2 G4:2 B4:2 | A4:3 G4:1 F#4:2 | G4:2 B4:2 D5:2 | E5:4 C5:2 |
                     D5:2 B4:2 G4:2 | C5:2 A4:2 F#4:2 | G4:4 F#4:2 | G4:6""",
        "chords": "G D G C G C G D G D G C G D D G",
    },
    # A hornpipe for busy waters: dotted, bright, a dance on the deck.
    "deck_hornpipe": {
        "meter": "4/4",
        "melody": """G4:1 B4:1 D5:1 B4:1 G5:2 D5:2 | E5:1 C5:1 A4:1 C5:1 F#5:2 D5:2 | G5:1 F#5:1 E5:1 D5:1 C5:1 B4:1 A4:1 G4:1 | A4:2 F#4:2 D4:4 |
                     G4:1 B4:1 D5:1 B4:1 G5:2 D5:2 | E5:1 G5:1 F#5:1 E5:1 D5:1 C5:1 B4:1 A4:1 | B4:1 G4:1 A4:1 F#4:1 D4:2 F#4:2 | G4:4 G4:4 |
                     B5:1 A5:1 G5:1 F#5:1 G5:2 D5:2 | C5:1 E5:1 D5:1 C5:1 B4:2 G4:2 | A4:1 B4:1 C5:1 D5:1 E5:1 F#5:1 G5:1 E5:1 | D5:2 B4:2 A4:4 |
                     B5:1 A5:1 G5:1 F#5:1 G5:2 D5:2 | C5:1 E5:1 D5:1 C5:1 B4:1 C5:1 D5:1 B4:1 | A4:1 B4:1 C5:1 A4:1 D5:2 F#4:2 | G4:4 G4:4""",
        "chords": "G C D D G C D/D G G C D D G C D/D G",
    },
    # A fife-and-drum march for the navy's home waters.
    "albion_march": {
        "meter": "2/4",
        "melody": """G4:1 G4:1 B4:1 D5:1 | G5:2 D5:2 | E5:1 D5:1 C5:1 B4:1 | A4:3 D4:1 |
                     G4:1 G4:1 B4:1 D5:1 | G5:2 B5:2 | A5:1 G5:1 F#5:1 A5:1 | G5:3 D5:1 |
                     E5:1 E5:1 E5:1 C5:1 | D5:2 B4:2 | C5:1 C5:1 C5:1 A4:1 | B4:2 G4:2 |
                     A4:1 B4:1 C5:1 D5:1 | E5:1 C5:1 A4:1 F#4:1 | G4:2 D4:2 | G4:4""",
        "chords": "G G C D G G D G C G D G Am D G G",
    },
    # Steel drums and marimba in the warm reefs.
    "coral_calypso": {
        "meter": "4/4",
        "melody": """C5:1 C5:1 r:1 E5:1 r:1 G5:2 E5:1 | F5:2 E5:1 D5:3 r:2 | B4:1 B4:1 r:1 D5:1 r:1 F5:2 D5:1 | E5:2 D5:1 C5:3 r:2 |
                     C5:1 C5:1 r:1 E5:1 r:1 G5:2 E5:1 | A5:2 G5:1 F5:3 r:2 | D5:1 E5:1 F5:1 D5:1 r:1 B4:2 G4:1 | C5:6 r:2 |
                     E5:2 G5:1 E5:3 C5:2 | F5:2 A5:1 F5:3 D5:2 | G5:2 F5:1 E5:2 D5:1 C5:2 | D5:6 r:2 |
                     E5:2 G5:1 E5:3 C5:2 | F5:2 A5:1 F5:3 D5:2 | G5:1 F5:1 E5:1 D5:1 r:1 B4:2 D5:1 | C5:6 r:2""",
        "chords": "C F G C C F G C C F C/G G C F G C",
    },
    # A heavy minor march for the iron-clad Dominion.
    "iron_march": {
        "meter": "4/4",
        "melody": """C4:3 C4:1 Eb4:2 G4:2 | Ab4:3 G4:1 F4:2 Eb4:2 | D4:3 D4:1 F4:2 Ab4:2 | G4:6 r:2 |
                     C4:3 C4:1 Eb4:2 G4:2 | C5:3 Bb4:1 Ab4:2 G4:2 | F4:2 Eb4:2 D4:2 B3:2 | C4:6 r:2 |
                     G4:3 G4:1 C5:2 G4:2 | Ab4:3 G4:1 F4:2 Eb4:2 | F4:3 F4:1 Ab4:2 C5:2 | B4:6 r:2 |
                     C5:3 Bb4:1 Ab4:2 G4:2 | Ab4:3 G4:1 F4:2 Eb4:2 | D4:2 Eb4:2 F4:2 B3:2 | C4:6 r:2""",
        "chords": "Cm Ab G G Cm Ab G Cm Cm Fm Fm G Ab Fm G Cm",
    },
    # A drowned waltz for the dead waters.
    "dead_waltz": {
        "meter": "3/4",
        "melody": """E5:4 B4:2 | C5:4 A4:2 | B4:2 A4:2 G#4:2 | A4:6 |
                     E5:4 B4:2 | C5:2 D5:2 E5:2 | F5:2 E5:2 D5:2 | E5:6 |
                     A5:4 E5:2 | F5:4 D5:2 | E5:2 C5:2 A4:2 | B4:6 |
                     C5:4 A4:2 | D5:2 C5:2 B4:2 | C5:2 B4:2 G#4:2 | A4:6""",
        "chords": "Am F E Am Am Am Dm E Am Dm Am E Am Dm E Am",
    },
    # The battle tune: driving 6/8 in D minor.
    "broadside": {
        "meter": "6/8",
        "melody": """A4:1 D5:1 E5:1 F5:2 E5:1 | D5:1 E5:1 F5:1 G5:2 A5:1 | Bb5:2 A5:1 G5:2 F5:1 | E5:3 A4:3 |
                     A4:1 D5:1 E5:1 F5:2 E5:1 | D5:1 E5:1 F5:1 G5:2 A5:1 | Bb5:2 A5:1 G5:1 F5:1 E5:1 | D5:3 D5:3 |
                     F5:2 F5:1 E5:2 D5:1 | C5:2 C5:1 Bb4:2 A4:1 | Bb4:2 C5:1 D5:2 E5:1 | F5:3 E5:3 |
                     A5:2 A5:1 G5:2 F5:1 | E5:2 F5:1 G5:2 E5:1 | F5:1 E5:1 D5:1 C#5:2 E5:1 | D5:3 D5:3""",
        "chords": "Dm Dm Gm A Dm Dm Gm Dm F C Bb C Dm C A Dm",
    },
    # The brooding motif when sails close in and for the big monsters.
    "leviathan": {
        "meter": "4/4",
        "melody": """D4:4 F4:2 E4:2 | D4:2 C#4:2 D4:4 | F4:4 A4:2 G4:2 | F4:2 E4:2 F4:4 |
                     A4:4 Bb4:2 A4:2 | G4:2 F4:2 E4:4 | D4:2 F4:2 E4:2 C#4:2 | D4:8 |
                     D5:4 C5:2 Bb4:2 | A4:2 Bb4:2 A4:4 | G4:4 F4:2 E4:2 | F4:2 G4:2 A4:4 |
                     Bb4:4 A4:2 G4:2 | F4:2 E4:2 D4:4 | E4:2 F4:2 G4:2 C#4:2 | D4:8""",
        "chords": "Dm A Dm Dm Dm Gm Dm/A Dm Bb F C F Gm Dm A Dm",
    },
}

# ---- instruments (General MIDI programs) and drum notes ------------------------------------------------------

GM = {
    "accordion": 21, "fiddle": 110, "violin": 40, "cello": 42, "contrabass": 43, "tremolo": 44, "pizz": 45, "harp": 46,
    "timpani": 47, "strings": 48, "choir": 52, "oohs": 53, "trumpet": 56, "trombone": 57, "tuba": 58, "horn": 60,
    "brass": 61, "oboe": 68, "clarinet": 71, "piccolo": 72, "flute": 73, "whistle": 78, "nylon": 24, "steel_gtr": 25,
    "banjo": 105, "marimba": 12, "steel_drums": 114, "celesta": 8, "music_box": 10, "organ": 19, "taiko": 116,
    "acoustic_bass": 32, "concertina": 23, "bagpipe": 109, "harmonica": 22,
}
KICK, SNARE, CLAP, TOM_LO, TOM_HI, CRASH, TAMB, RIDE, SHAKER, CONGA, BONGO, WOOD = 36, 38, 39, 41, 45, 49, 54, 51, 70, 63, 61, 76


# ---- arranging -----------------------------------------------------------------------------------------------

class Track:
    def __init__(self, bpm, meter):
        self.bpm, self.meter = bpm, meter
        self.events = {}  # channel -> list of (tick, kind, a, b)
        self.programs = {}
        self.rng = random.Random(7)

    def program(self, ch, inst, vol=100, pan=64, reverb=60):
        self.programs[ch] = (GM[inst], vol, pan, reverb)

    def note(self, ch, tick, length, pitch, vel):
        if pitch is None or length <= 0:
            return
        jitter = 0 if ch == 9 else self.rng.randint(-6, 6)
        vel = max(1, min(127, int(vel + self.rng.randint(-7, 7))))
        t0 = max(0, int(tick) + jitter)
        self.events.setdefault(ch, []).append((t0, max(t0 + 1, t0 + int(length) - 8), pitch, vel))

    def write(self, path, total_ticks):
        mid = mido.MidiFile(ticks_per_beat=TPB)
        meta = mido.MidiTrack()
        meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(self.bpm)))
        num, den = (int(x) for x in self.meter.split("/"))
        meta.append(mido.MetaMessage("time_signature", numerator=num, denominator=den))
        meta.append(mido.MetaMessage("end_of_track", time=total_ticks))
        mid.tracks.append(meta)
        for ch, evs in sorted(self.events.items()):
            tr = mido.MidiTrack()
            if ch in self.programs:
                prog, vol, pan, rev = self.programs[ch]
                tr.append(mido.Message("program_change", channel=ch, program=prog, time=0))
                tr.append(mido.Message("control_change", channel=ch, control=7, value=vol, time=0))
                tr.append(mido.Message("control_change", channel=ch, control=10, value=pan, time=0))
                tr.append(mido.Message("control_change", channel=ch, control=91, value=rev, time=0))
            else:
                tr.append(mido.Message("control_change", channel=ch, control=91, value=40, time=0))
            # A note may not run into the next one on the same key: its note-off would cut the new note short.
            by_key = {}
            for n in sorted(evs):
                by_key.setdefault(n[2], []).append(n)
            flat = []
            for key_notes in by_key.values():
                for i, (t0, t1, p, v) in enumerate(key_notes):
                    if i + 1 < len(key_notes):
                        t1 = max(t0 + 1, min(t1, key_notes[i + 1][0] - 1))
                    flat += [(t0, 1, p, v), (t1, 0, p, 0)]
            last = 0
            for t, on, p, v in sorted(flat, key=lambda e: (e[0], e[1])):
                kind = "note_on" if on else "note_off"
                tr.append(mido.Message(kind, channel=ch, note=p, velocity=v, time=t - last))
                last = t
            mid.tracks.append(tr)
        mid.save(path)


def bar_ticks(meter):
    return METER[meter] * EIGHTH


def comp(tr, ch, meter, chords, bar0, bars, style, vel, low=55):
    """Chords: oompah (on the off beats), strum (every beat), pad (held), arp (broken eighths), trem (repeated 16ths)."""
    bt = bar_ticks(meter)
    for b in range(bars):
        names = chords[b % len(chords)]
        part = bt // len(names)
        for k, nm in enumerate(names):
            root, ivs = chord_notes(nm)
            vo = voicing(root, ivs, low)
            t0 = (bar0 + b) * bt + k * part
            if style == "pad":
                for n in vo:
                    tr.note(ch, t0, part, n, vel)
            elif style == "oompah":
                for o in _offbeats(meter, part):
                    for n in vo:
                        tr.note(ch, t0 + o, EIGHTH * 0.9, n, vel)
            elif style == "strum":
                step = EIGHTH * (3 if meter == "6/8" else 2)
                for o in range(0, part, step):
                    for j, n in enumerate(vo):
                        tr.note(ch, t0 + o + j * 12, step * 0.8, n, vel - (0 if o == 0 else 12))
            elif style == "arp":
                seq = vo + [vo[1] + 12 if len(vo) > 1 else vo[0] + 12]
                for j, o in enumerate(range(0, part, EIGHTH)):
                    tr.note(ch, t0 + o, EIGHTH * 1.5, seq[j % len(seq)], vel - (0 if j == 0 else 10))
            elif style == "trem":
                for o in range(0, part, EIGHTH // 2):
                    for n in vo:
                        tr.note(ch, t0 + o, EIGHTH // 2, n, vel - 15 + (12 if o == 0 else 0))


def _offbeats(meter, part):
    if meter == "6/8":
        return [o for o in (EIGHTH, 2 * EIGHTH, 4 * EIGHTH, 5 * EIGHTH) if o < part]
    if meter == "3/4":
        return [o for o in (2 * EIGHTH, 4 * EIGHTH) if o < part]
    return [o for o in (2 * EIGHTH, 6 * EIGHTH) if o < part] or [EIGHTH]


def bass(tr, ch, meter, chords, bar0, bars, style, vel, octave=2):
    """Bass: oompah (root and fifth on the strong beats), pedal (held root), drive (repeated eighths), walk."""
    bt = bar_ticks(meter)
    for b in range(bars):
        names = chords[b % len(chords)]
        part = bt // len(names)
        for k, nm in enumerate(names):
            root, ivs = chord_notes(nm)
            r = 12 * (octave + 1) + root
            fifth = r + 7 if r + 7 < 12 * (octave + 2) + 4 else r - 5
            t0 = (bar0 + b) * bt + k * part
            if style == "pedal":
                tr.note(ch, t0, part, r, vel)
            elif style == "oompah":
                strong = [0, 3 * EIGHTH] if meter == "6/8" else ([0] if meter == "3/4" else [0, 4 * EIGHTH])
                for j, o in enumerate(x for x in strong if x < part):
                    tr.note(ch, t0 + o, EIGHTH * 1.6, r if j % 2 == 0 else fifth, vel)
            elif style == "drive":
                for o in range(0, part, EIGHTH):
                    tr.note(ch, t0 + o, EIGHTH * 0.8, r, vel - (0 if o == 0 else 14))
            elif style == "walk":
                seq = [r, r + ivs[1], fifth, r + ivs[1]]
                for j, o in enumerate(range(0, part, 2 * EIGHTH)):
                    tr.note(ch, t0 + o, EIGHTH * 1.8, seq[j % 4], vel)


DRUMS = {  # pattern per meter: list of (eighth offset, note, velocity)
    "shanty": {"4/4": [(0, KICK, 100), (2, TAMB, 70), (4, KICK, 90), (6, TAMB, 75), (6, CLAP, 60)],
               "6/8": [(0, KICK, 100), (3, KICK, 80), (2, TAMB, 60), (5, TAMB, 70)],
               "3/4": [(0, KICK, 95), (2, TAMB, 60), (4, TAMB, 60)], "2/4": [(0, KICK, 100), (2, TAMB, 70)]},
    "jig": {"6/8": [(0, TOM_LO, 105), (1, TOM_HI, 55), (2, TOM_HI, 60), (3, TOM_LO, 90), (4, TOM_HI, 55), (5, TOM_HI, 65)],
            "4/4": [(0, TOM_LO, 100), (1, TOM_HI, 50), (2, TOM_HI, 65), (3, TOM_HI, 50), (4, TOM_LO, 90), (5, TOM_HI, 50), (6, TOM_HI, 65), (7, TOM_HI, 55)],
            "3/4": [(0, TOM_LO, 100), (2, TOM_HI, 60), (4, TOM_HI, 60)], "2/4": [(0, TOM_LO, 100), (2, TOM_HI, 70)]},
    "march": {"2/4": [(0, KICK, 100), (0, SNARE, 90), (1, SNARE, 50), (1.5, SNARE, 45), (2, SNARE, 80), (3, SNARE, 55), (3.5, SNARE, 50)],
              "4/4": [(0, KICK, 100), (0, SNARE, 90), (1, SNARE, 50), (2, SNARE, 75), (3, SNARE, 50), (3.5, SNARE, 45), (4, KICK, 90), (4, SNARE, 85), (6, SNARE, 75), (7, SNARE, 55)]},
    "battle": {"6/8": [(0, KICK, 115), (0, CRASH, 50), (1, SNARE, 60), (2, SNARE, 70), (3, KICK, 105), (4, SNARE, 60), (5, SNARE, 85)],
               "4/4": [(0, KICK, 115), (2, SNARE, 95), (3, KICK, 80), (4, KICK, 105), (6, SNARE, 100), (7, SNARE, 60)]},
    "calypso": {"4/4": [(0, KICK, 90), (1.5, CONGA, 70), (2, BONGO, 60), (3, CONGA, 75), (4, KICK, 85), (5, BONGO, 60), (5.5, CONGA, 65), (6, CONGA, 80), (7, SHAKER, 50)] +
                        [(i * 0.5, SHAKER, 40) for i in range(16)]},
    "heartbeat": {"4/4": [(0, KICK, 95), (0.75, KICK, 70)], "6/8": [(0, KICK, 95), (0.75, KICK, 70)], "3/4": [(0, KICK, 90), (0.75, KICK, 65)]},
    "waltz": {"3/4": [(0, KICK, 70), (2, WOOD, 40), (4, WOOD, 40)]},
}


def drums(tr, meter, bar0, bars, style, vol=1.0, fill=True):
    bt = bar_ticks(meter)
    pat = DRUMS[style].get(meter) or DRUMS[style][next(iter(DRUMS[style]))]
    for b in range(bars):
        for off, n, v in pat:
            tr.note(9, (bar0 + b) * bt + off * EIGHTH, EIGHTH // 2, n, v * vol)
        if fill and b % 8 == 7 and style in ("shanty", "battle", "march", "jig"):
            for k in range(4):
                tr.note(9, (bar0 + b) * bt + bt - (4 - k) * EIGHTH // 2, EIGHTH // 2, SNARE if style != "jig" else TOM_HI, 60 + k * 12)


def lay_melody(tr, ch, mel, bar0, meter, vel, shift=0, legato=0.95, accent=True):
    bt = bar_ticks(meter)
    for bar, at, d, p in mel:
        if p is None:
            continue
        strong = at == 0 or (meter == "6/8" and at == 3) or (meter == "4/4" and at == 4)
        tr.note(ch, (bar0 + bar) * bt + at * EIGHTH, d * EIGHTH * legato, p + shift, vel + (10 if strong and accent else 0))


def harmony_third(mel, chords, meter):
    """A line a chord-tone above the tune: the next note of the bar's chord above each melody note."""
    bt8 = METER[meter]
    out = []
    for bar, at, d, p in mel:
        if p is None:
            out.append((bar, at, d, None))
            continue
        names = chords[bar % len(chords)]
        nm = names[min(int(at / (bt8 / len(names))), len(names) - 1)]
        root, ivs = chord_notes(nm)
        pcs = sorted({(root + i) % 12 for i in ivs})
        h = p + 1
        while h % 12 not in pcs:
            h += 1
        out.append((bar, at, d, h if h - p <= 5 else p + (3 if (p - root) % 12 in (0, 7) else 4)))
    return out


# ---- the arrangements ------------------------------------------------------------------------------------------
# Each recipe plays its tune a number of times; every pass names the voices that play in it.

def arrange(spec):
    tune = TUNES[spec["tune"]]
    meter = tune["meter"]
    mel, bars = parse_melody(tune["melody"], meter, spec["tune"])
    chords = parse_chords(tune["chords"], bars, spec["tune"])
    shift = spec.get("transpose", 0)
    if shift:
        mel = [(b, a, d, None if p is None else p + shift) for b, a, d, p in mel]
        chords = [[_shift_chord(n, shift) for n in names] for names in chords]
    tr = Track(spec["bpm"], meter)
    for ch, inst in spec["voices"].items():
        name, vol, pan = inst if isinstance(inst, tuple) else (inst, 100, 64)
        tr.program(ch, name, vol, pan, spec.get("reverb", 55))
    intro = spec.get("intro", 2)
    bar0 = 0
    if intro:
        comp(tr, 2, meter, chords[:1], 0, intro, spec["comp"], 70, spec.get("comp_low", 55))
        bass(tr, 3, meter, chords[:1], 0, intro, spec["bass"], 85, spec.get("bass_oct", 2))
        if spec.get("drums"):
            drums(tr, meter, 0, intro, spec["drums"], spec.get("drum_vol", 1.0), fill=False)
        bar0 = intro
    harm = harmony_third(mel, chords, meter)
    for p, voices in enumerate(spec["passes"]):
        if "lead" in voices:
            lay_melody(tr, 0, mel, bar0, meter, 88, spec.get("lead_oct", 0))
        if "double" in voices:
            lay_melody(tr, 1, mel, bar0, meter, 78, spec.get("double_oct", 12))
        if "harm" in voices:
            lay_melody(tr, 4, harm, bar0, meter, 70, spec.get("harm_oct", 0))
        if "choir" in voices:
            lay_melody(tr, 5, mel, bar0, meter, 84, spec.get("choir_oct", -12), legato=1.0, accent=False)
        if "comp" in voices:
            comp(tr, 2, meter, chords, bar0, bars, spec["comp"], spec.get("comp_vel", 72), spec.get("comp_low", 55))
        if "pad" in voices:
            comp(tr, 6, meter, chords, bar0, bars, "pad", 58, 50)
        if "trem" in voices:
            comp(tr, 6, meter, chords, bar0, bars, "trem", 70, 50)
        if "bass" in voices:
            bass(tr, 3, meter, chords, bar0, bars, spec["bass"], 92, spec.get("bass_oct", 2))
        if "drums" in voices and spec.get("drums"):
            drums(tr, meter, bar0, bars, spec["drums"], spec.get("drum_vol", 1.0))
        if "timp" in voices:
            bt = bar_ticks(meter)
            for b in range(bars):
                root, _ = chord_notes(chords[b][0])
                r = 43 + (root - 7) % 12  # the chord's root between G2 and F#3
                tr.note(7, (bar0 + b) * bt, EIGHTH * 2, r, 100 if b % 4 == 0 else 80)
                if b % 4 == 3:
                    for k in range(6):
                        tr.note(7, (bar0 + b) * bt + bt - (6 - k) * EIGHTH // 3, EIGHTH // 3, r, 60 + 8 * k)
        bar0 += bars
    return tr, bar0 * bar_ticks(meter), 60.0 / spec["bpm"] * bar0 * METER[meter] / 2.0


def _shift_chord(name, k):
    m = re.fullmatch(r"([A-G][#b]?)(.*)", name)
    names = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
    root = PC[m.group(1)[0]] + {"#": 1, "b": -1}.get(m.group(1)[1:], 0)
    return names[(root + k) % 12] + m.group(2)


SHANTY_BAND = {0: ("accordion", 100, 50), 1: ("fiddle", 85, 84), 2: ("accordion", 70, 40), 3: ("tuba", 105, 64),
               4: ("whistle", 70, 90), 5: ("choir", 105, 64), 6: ("strings", 60, 64)}
ORCHESTRA = {0: ("strings", 110, 54), 1: ("horn", 95, 76), 2: ("strings", 80, 64), 3: ("cello", 110, 64),
             4: ("trumpet", 80, 84), 5: ("choir", 95, 64), 6: ("brass", 85, 44), 7: ("timpani", 110, 64)}

TRACKS = {
    # title screen
    "menu_theme": {"tune": "empire", "bpm": 92, "voices": {**ORCHESTRA, **{0: ("horn", 105, 54), 1: ("strings", 95, 76)}},
                   "comp": "arp", "bass": "oompah", "drums": "", "intro": 2, "reverb": 75,
                   "passes": [["lead", "comp", "bass", "pad"], ["lead", "double", "choir", "comp", "bass", "trem", "timp", "harm"]]},
    # layers
    "layer_explore": {"tune": "haul_the_anchor", "bpm": 104, "voices": SHANTY_BAND, "comp": "oompah", "bass": "oompah", "drums": "shanty",
                      "passes": [["lead", "comp", "bass", "drums"], ["lead", "double", "comp", "bass", "drums", "harm"]], "drum_vol": 0.8},
    "layer_tension": {"tune": "leviathan", "bpm": 84, "voices": {0: ("pizz", 100, 50), 1: ("cello", 90, 80), 2: ("pizz", 70, 64), 3: ("contrabass", 100, 64), 6: ("tremolo", 70, 64), 7: ("timpani", 90, 64)},
                      "comp": "arp", "bass": "pedal", "drums": "heartbeat", "intro": 1, "lead_oct": 0,
                      "passes": [["lead", "bass", "drums", "trem"], ["lead", "double", "bass", "drums", "trem", "timp"]], "double_oct": -12},
    "layer_combat": {"tune": "broadside", "bpm": 164, "voices": {**ORCHESTRA, **{0: ("strings", 115, 54), 1: ("brass", 100, 76), 2: ("strings", 85, 64)}},
                     "comp": "trem", "bass": "drive", "drums": "battle", "intro": 1,
                     "passes": [["lead", "comp", "bass", "drums", "timp"], ["lead", "double", "harm", "comp", "bass", "drums", "timp", "choir"]], "choir_oct": 0},
    "layer_boarding": {"tune": "drunken_sailor", "bpm": 172, "voices": {**SHANTY_BAND, **{0: ("fiddle", 110, 50), 1: ("whistle", 85, 84), 3: ("tuba", 110, 64)}},
                       "comp": "oompah", "bass": "oompah", "drums": "battle", "intro": 1, "drum_vol": 0.9,
                       "passes": [["lead", "comp", "bass", "drums"], ["lead", "double", "choir", "comp", "bass", "drums"]], "choir_oct": -12},
    "layer_boss": {"tune": "leviathan", "bpm": 112, "voices": {**ORCHESTRA, **{0: ("brass", 115, 54), 1: ("choir", 100, 76), 3: ("cello", 115, 64)}},
                   "comp": "trem", "bass": "drive", "drums": "battle", "intro": 1, "transpose": 0,
                   "passes": [["lead", "comp", "bass", "drums", "timp"], ["lead", "double", "comp", "bass", "drums", "timp", "harm"]], "double_oct": 12},
    "layer_port": {"tune": "rum_and_rope", "bpm": 132, "voices": {**SHANTY_BAND, **{0: ("accordion", 105, 50), 1: ("fiddle", 80, 80), 3: ("tuba", 95, 64)}},
                   "comp": "oompah", "bass": "oompah", "drums": "waltz",
                   "passes": [["lead", "comp", "bass", "drums"], ["lead", "double", "comp", "bass", "drums", "harm"]]},
    "layer_storm": {"tune": "empire", "bpm": 80, "transpose": -2, "voices": {0: ("horn", 100, 54), 1: ("cello", 95, 76), 2: ("tremolo", 85, 64), 3: ("contrabass", 110, 64), 5: ("choir", 80, 64), 6: ("tremolo", 75, 64), 7: ("timpani", 110, 64)},
                    "comp": "trem", "bass": "pedal", "drums": "", "intro": 2, "reverb": 85,
                    "passes": [["lead", "comp", "bass", "timp"], ["lead", "double", "comp", "bass", "timp", "choir"]], "double_oct": -12, "choir_oct": 0},
    # region themes (the explore music in each sea)
    "region_albion_shallows": {"tune": "albion_march", "bpm": 108, "voices": {0: ("piccolo", 100, 50), 1: ("flute", 80, 80), 2: ("brass", 60, 64), 3: ("tuba", 95, 64), 4: ("trumpet", 70, 90)},
                               "comp": "oompah", "bass": "oompah", "drums": "march",
                               "passes": [["lead", "bass", "drums", "comp"], ["lead", "double", "harm", "bass", "drums", "comp"], ["lead", "comp", "bass", "drums"]], "lead_oct": 12, "double_oct": 0},
    "region_merchants_reach": {"tune": "deck_hornpipe", "bpm": 104, "voices": {**SHANTY_BAND, **{0: ("fiddle", 110, 50), 1: ("whistle", 75, 84), 2: ("steel_gtr", 80, 40)}},
                               "comp": "strum", "bass": "walk", "drums": "jig",
                               "passes": [["lead", "comp", "bass", "drums"], ["lead", "double", "comp", "bass", "drums"]], "drum_vol": 0.75},
    "region_haven_waters": {"tune": "pieces_of_eight", "bpm": 118, "voices": {**SHANTY_BAND, **{0: ("fiddle", 110, 50), 1: ("accordion", 85, 80), 2: ("nylon", 85, 40)}},
                            "comp": "strum", "bass": "oompah", "drums": "jig",
                            "passes": [["lead", "comp", "bass", "drums"], ["lead", "double", "comp", "bass", "drums", "harm"]], "double_oct": 0},
    "region_coral_isles": {"tune": "coral_calypso", "bpm": 112, "voices": {0: ("steel_drums", 110, 50), 1: ("marimba", 95, 80), 2: ("nylon", 80, 40), 3: ("acoustic_bass", 110, 64), 4: ("flute", 70, 90)},
                           "comp": "strum", "bass": "walk", "drums": "calypso",
                           "passes": [["lead", "comp", "bass", "drums"], ["lead", "double", "harm", "comp", "bass", "drums"]], "double_oct": -12},
    "region_iron_marches": {"tune": "iron_march", "bpm": 92, "voices": {0: ("brass", 105, 50), 1: ("cello", 90, 80), 2: ("strings", 70, 64), 3: ("tuba", 110, 64), 6: ("tremolo", 60, 64), 7: ("timpani", 110, 64)},
                            "comp": "pad", "bass": "drive", "drums": "march", "drum_vol": 0.8,
                            "passes": [["lead", "comp", "bass", "drums", "timp"], ["lead", "double", "comp", "bass", "drums", "timp", "trem"]], "double_oct": -12},
    "region_dead_reach": {"tune": "dead_waltz", "bpm": 96, "voices": {0: ("music_box", 100, 50), 1: ("oohs", 80, 80), 2: ("harp", 70, 40), 3: ("contrabass", 90, 64), 6: ("tremolo", 55, 64)},
                          "comp": "arp", "bass": "pedal", "drums": "", "reverb": 100,
                          "passes": [["lead", "comp", "bass"], ["lead", "double", "comp", "bass", "trem"]], "double_oct": -12},
    # the tavern band and the shanties the crew sings
    "tavern_band": {"tune": "pieces_of_eight", "bpm": 126, "voices": {**SHANTY_BAND, **{0: ("fiddle", 110, 50), 1: ("whistle", 85, 84), 2: ("banjo", 85, 40)}},
                    "comp": "strum", "bass": "oompah", "drums": "jig",
                    "passes": [["lead", "comp", "bass", "drums"], ["lead", "double", "comp", "bass", "drums"], ["lead", "harm", "comp", "bass", "drums"]], "double_oct": 0},
    "shanty_drunken_sailor": {"tune": "drunken_sailor", "bpm": 120, "voices": SHANTY_BAND, "comp": "oompah", "bass": "oompah", "drums": "shanty",
                              "passes": [["choir", "comp", "bass", "drums"], ["choir", "lead", "comp", "bass", "drums", "double"]], "choir_oct": -12, "lead_oct": 12},
    "shanty_haul_the_anchor": {"tune": "haul_the_anchor", "bpm": 96, "voices": SHANTY_BAND, "comp": "oompah", "bass": "oompah", "drums": "shanty",
                               "passes": [["choir", "comp", "bass", "drums"], ["choir", "lead", "harm", "comp", "bass", "drums"]], "choir_oct": -12},
    "shanty_black_gale": {"tune": "black_gale", "bpm": 84, "voices": {**SHANTY_BAND, **{0: ("concertina", 95, 50)}}, "comp": "oompah", "bass": "oompah", "drums": "shanty",
                          "passes": [["choir", "bass", "drums"], ["choir", "lead", "comp", "bass", "drums", "double"]], "choir_oct": -12, "intro": 1},
    "shanty_pieces_of_eight": {"tune": "pieces_of_eight", "bpm": 112, "voices": SHANTY_BAND, "comp": "oompah", "bass": "oompah", "drums": "jig",
                               "passes": [["choir", "comp", "bass", "drums"], ["choir", "lead", "double", "comp", "bass", "drums"]], "choir_oct": -12},
    "shanty_rum_and_rope": {"tune": "rum_and_rope", "bpm": 120, "voices": SHANTY_BAND, "comp": "oompah", "bass": "oompah", "drums": "waltz",
                            "passes": [["choir", "comp", "bass", "drums"], ["choir", "lead", "harm", "comp", "bass", "drums"]], "choir_oct": -12},
}

# Boss and rival themes: the boss motif or the battle tune, in their own key and colours.
_BOSSES = {
    "kraken": ("leviathan", -2, 104, {0: ("tuba", 115, 50), 1: ("choir", 100, 76)}),
    "sea_serpent": ("leviathan", 2, 120, {0: ("strings", 115, 50), 1: ("oboe", 90, 76)}),
    "shell_king": ("broadside", -3, 150, {0: ("marimba", 115, 50), 1: ("brass", 95, 76)}),
    "ghost_admiral": ("dead_waltz", -1, 104, {0: ("organ", 105, 50), 1: ("choir", 95, 76)}),
    "brass_colossus": ("iron_march", 2, 104, {0: ("brass", 115, 50), 1: ("trombone", 100, 76)}),
    "ice_leviathan": ("leviathan", -4, 96, {0: ("celesta", 105, 50), 1: ("strings", 95, 76)}),
    "valcourt": ("broadside", -2, 156, {0: ("trumpet", 105, 50), 1: ("strings", 95, 76)}),
    "black_ibrahim": ("broadside", -5, 150, {0: ("brass", 115, 50), 1: ("choir", 95, 76)}),
    "molly": ("drunken_sailor", 2, 168, {0: ("fiddle", 115, 50), 1: ("whistle", 90, 76)}),
    "isabeau": ("pieces_of_eight", 3, 140, {0: ("violin", 110, 50), 1: ("harp", 90, 76)}),
    "saltjaw": ("black_gale", -3, 120, {0: ("bagpipe", 90, 50), 1: ("cello", 95, 76)}),
    "vale": ("broadside", 1, 158, {0: ("strings", 115, 50), 1: ("horn", 95, 76)}),
}
for _k, (_tune, _tr, _bpm, _lead) in _BOSSES.items():
    _meter = TUNES[_tune]["meter"]
    TRACKS["boss_" + _k] = {"tune": _tune, "bpm": _bpm, "transpose": _tr, "voices": {**ORCHESTRA, **_lead},
                            "comp": "trem", "bass": "drive", "drums": "battle" if _meter in ("4/4", "6/8") else "", "intro": 1,
                            "passes": [["lead", "comp", "bass", "drums", "timp"], ["lead", "double", "comp", "bass", "drums", "timp", "harm"]],
                            "double_oct": 0 if _lead[1][0] == "choir" else 12}


# ---- rendering -----------------------------------------------------------------------------------------------

def render(name, spec, out_dir):
    tr, ticks, seconds = arrange(spec)
    with tempfile.TemporaryDirectory() as tmp:
        mid = os.path.join(tmp, name + ".mid")
        wav = os.path.join(tmp, name + ".wav")
        tr.write(mid, ticks)
        subprocess.run(["fluidsynth", "-ni", "-g", "0.6", "-r", str(RATE), "-F", wav, SOUNDFONT, mid],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        # Cut at the loop point (the reverb tail is folded away by a short fade) and even out the loudness.
        out = os.path.join(out_dir, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-t", "%.3f" % seconds,
                        "-af", "afade=t=out:st=%.3f:d=0.25,loudnorm=I=-18:TP=-2:LRA=11" % max(0.0, seconds - 0.25),
                        "-ar", str(RATE), "-c:a", "libvorbis", "-q:a", "1", out], check=True)
    return seconds


def main():
    if "--list" in sys.argv:
        print("\n".join(sorted(TRACKS)))
        return
    for k, t in TUNES.items():  # catches a bar with the wrong length before anything is rendered
        _, bars = parse_melody(t["melody"], t["meter"], k)
        parse_chords(t["chords"], bars, k)
    want = [a for a in sys.argv[1:] if not a.startswith("-")] or sorted(TRACKS)
    os.makedirs(ROOT, exist_ok=True)
    for name in want:
        secs = render(name, TRACKS[name], ROOT)
        print("%-28s %5.1f s" % (name, secs))


if __name__ == "__main__":
    main()
