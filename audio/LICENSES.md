# Audio licences

Everything under `audio/` may be shipped with the game.

## Music (`audio/music/`, made by `tools/gen_music.py`)

The tunes are written out as notes in `tools/gen_music.py`, arranged there, and played by FluidSynth with the
FluidR3 General MIDI soundfont.

| What | Source | Licence |
| --- | --- | --- |
| "Drunken Sailor" (used in `shanty_drunken_sailor`, `layer_boarding`, `boss_molly`) | Traditional sea shanty, 19th century | Public domain |
| Every other tune: the Pirate Empire theme, "Haul the Anchor", "Pieces of Eight", "The Black Gale", "Rum and Rope", the deck hornpipe, the Albion march, the coral calypso, the iron march, the dead waltz, "Broadside", "Leviathan" | Written for this game | CC0 1.0 |
| The arrangements and the rendered `.ogg` recordings | Made for this game | CC0 1.0 |
| Instrument sounds: FluidR3_GM.sf2 by Frank Wen (Debian/Ubuntu package `fluid-soundfont-gm`) | https://packages.ubuntu.com/fluid-soundfont-gm | MIT |

The MIT licence of FluidR3 covers the soundfont itself; audio rendered with it carries no further conditions.
The soundfont is only needed to re-render the music and is not part of the game.

## Sound effects, voices and ambience (`audio/sfx`, `audio/voice`, `audio/ambience`)

Synthesised from noise and simple waveforms by `tools/gen_audio.py`, no samples from anywhere. CC0 1.0.
