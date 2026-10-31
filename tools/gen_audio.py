#!/usr/bin/env python3
"""Self-made audio for Pirate Empire: every sound and loop is synthesised here from noise, sines and simple
filters (no samples from anywhere), then encoded to Ogg Vorbis with ffmpeg. The output is released under CC0.

    python3 tools/gen_audio.py            # writes audio/{sfx,voice,ambience}/*.ogg (music: tools/gen_music.py)
    python3 tools/gen_audio.py sfx        # only one group
"""
import math, os, random, struct, subprocess, sys, tempfile

SR = 16000
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")


# ---- building blocks ---------------------------------------------------------------------------------------

def silence(sec):
    return [0.0] * int(sec * SR)


def env_ad(n, attack, decay_pow=3.0):
    a = max(int(attack * SR), 1)
    return [(i / a) if i < a else (1.0 - (i - a) / max(n - a, 1)) ** decay_pow for i in range(n)]


def noise(sec, rng, color=0.0):
    """White noise; color 0..1 low-passes it (brown-ish when high)."""
    out = []
    y = 0.0
    for _ in range(int(sec * SR)):
        x = rng.uniform(-1, 1)
        y = y + (1.0 - color) * (x - y) if color > 0 else x
        out.append(y if color == 0 else y * (1.0 + color * 2.0))
    return out


def lowpass(x, cutoff):
    a = min(1.0, 2 * math.pi * cutoff / SR)
    y = 0.0
    out = []
    for v in x:
        y += a * (v - y)
        out.append(y)
    return out


def highpass(x, cutoff):
    lp = lowpass(x, cutoff)
    return [v - l for v, l in zip(x, lp)]


def bandpass(x, lo, hi):
    return highpass(lowpass(x, hi), lo)


def sine(freq, sec, vol=1.0, phase=0.0):
    return [vol * math.sin(2 * math.pi * freq * i / SR + phase) for i in range(int(sec * SR))]


def sweep(f0, f1, sec, vol=1.0):
    n = int(sec * SR)
    out = []
    ph = 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * i / n
        ph += 2 * math.pi * f / SR
        out.append(vol * math.sin(ph))
    return out


def saw(freq, n, vol=1.0, start=0):
    return [vol * (2.0 * ((freq * (i + start) / SR) % 1.0) - 1.0) for i in range(n)]


def mix(*tracks, gains=None):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for k, t in enumerate(tracks):
        g = 1.0 if gains is None else gains[k]
        for i, v in enumerate(t):
            out[i] += v * g
    return out


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def scale(a, g):
    return [x * g for x in a]


def normalise(x, peak=0.9):
    m = max((abs(v) for v in x), default=1.0) or 1.0
    return [v * peak / m for v in x]


def fade_edges(x, ms=8):
    n = int(ms / 1000.0 * SR)
    for i in range(min(n, len(x) // 2)):
        g = i / n
        x[i] *= g
        x[-1 - i] *= g
    return x


def write_ogg(samples, path, quality=3):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32000)) for v in samples)
    with tempfile.NamedTemporaryFile(suffix=".raw", delete=False) as f:
        f.write(pcm)
        raw = f.name
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", raw, "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)
    os.remove(raw)


# ---- sound effects -----------------------------------------------------------------------------------------

def cannon(rng, weight):
    sec = 0.5 + weight * 0.9
    n = int(sec * SR)
    boom = mul(lowpass(noise(sec, rng), 500 - weight * 250), env_ad(n, 0.002, 3.5 - weight))
    thump = mul(sweep(140 - weight * 60, 35, sec, 1.0), env_ad(n, 0.003, 2.2))
    crack = mul(highpass(noise(sec, rng), 1500), env_ad(n, 0.001, 12.0))
    return normalise(mix(boom, thump, crack, gains=[1.0, 1.2, 0.35]))


def sfx_all():
    r = random.Random(7)
    out = {}
    out["cannon_swivel"] = normalise(mix(mul(highpass(noise(0.3, r), 700), env_ad(int(0.3 * SR), 0.001, 9)), mul(sweep(300, 90, 0.3), env_ad(int(0.3 * SR), 0.002, 5))))
    out["cannon_6pdr"] = cannon(r, 0.1)
    out["cannon_12pdr"] = cannon(r, 0.5)
    out["cannon_24pdr"] = cannon(r, 0.9)
    out["ball_whistle"] = mul(sweep(2400, 1500, 0.8, 0.5), [math.sin(math.pi * i / (0.8 * SR)) for i in range(int(0.8 * SR))])
    out["splash"] = normalise(mul(bandpass(noise(0.9, r), 300, 3500), env_ad(int(0.9 * SR), 0.01, 2.5)))
    out["wood_impact"] = normalise(mix(mul(lowpass(noise(0.35, r), 900), env_ad(int(0.35 * SR), 0.001, 6)), mul(sweep(180, 70, 0.35), env_ad(int(0.35 * SR), 0.001, 7))))
    spl = silence(0.6)
    for k in range(9):
        at = int(r.uniform(0, 0.4) * SR)
        c = mul(highpass(noise(0.08, r), 1800), env_ad(int(0.08 * SR), 0.0005, 6))
        for i, v in enumerate(c):
            spl[at + i] += v * r.uniform(0.4, 1.0)
    out["splinter"] = normalise(spl)
    out["mast_creak"] = normalise(mul(mix(sweep(180, 90, 1.4, 0.5), mul(noise(1.4, r), [0.0] * 0 or [1.0] * int(1.4 * SR))), [math.sin(math.pi * i / (1.4 * SR)) for i in range(int(1.4 * SR))]), 0.5)
    snap = mix(mul(highpass(noise(1.0, r), 400), env_ad(int(SR), 0.001, 5)), mul(sweep(200, 50, 1.0), env_ad(int(SR), 0.002, 3)))
    out["mast_snap"] = normalise(snap)
    fire = silence(2.0)
    for k in range(60):
        at = int(r.uniform(0, 1.9) * SR)
        c = mul(highpass(noise(0.03, r), 1200), env_ad(int(0.03 * SR), 0.0003, 4))
        for i, v in enumerate(c):
            fire[at + i] += v * r.uniform(0.2, 1.0)
    out["fire_crackle"] = normalise(mix(fire, scale(lowpass(noise(2.0, r), 300), 0.5)), 0.7)
    out["explosion"] = normalise(mix(mul(lowpass(noise(1.8, r), 350), env_ad(int(1.8 * SR), 0.004, 2.0)), mul(sweep(90, 20, 1.8), env_ad(int(1.8 * SR), 0.004, 1.5))))
    bell = mix(*[mul(sine(f, 2.2, v), env_ad(int(2.2 * SR), 0.002, 3.0)) for f, v in [(523, 1.0), (1046, 0.5), (1570, 0.25), (2090, 0.12)]])
    out["bell"] = normalise(bell, 0.7)
    out["sail_flap"] = normalise(mul(bandpass(noise(0.7, r), 200, 1200), [abs(math.sin(i / SR * 38)) * env for i, env in enumerate(env_ad(int(0.7 * SR), 0.01, 1.5))]))
    out["sail_fill"] = normalise(mul(lowpass(noise(1.0, r), 600), [math.sin(math.pi * i / SR) ** 2 for i in range(SR)]), 0.6)
    out["rope_creak"] = normalise(mul(mix(sweep(300, 420, 0.6, 0.6), sweep(450, 360, 0.6, 0.3)), [math.sin(math.pi * i / (0.6 * SR)) for i in range(int(0.6 * SR))]), 0.4)
    out["hull_groan"] = normalise(mul(mix(sweep(70, 45, 2.0, 1.0), sweep(105, 66, 2.0, 0.5), scale(lowpass(noise(2.0, r), 150), 0.3)), [math.sin(math.pi * i / (2.0 * SR)) for i in range(2 * SR)]), 0.6)
    out["thunder"] = normalise(mul(lowpass(noise(3.5, r), 220), [(1 - i / (3.5 * SR)) ** 1.6 * (0.6 + 0.4 * math.sin(i / SR * 9)) for i in range(int(3.5 * SR))]))
    out["sword_clash"] = normalise(mix(*[mul(sine(f, 0.8, v), env_ad(int(0.8 * SR), 0.0008, 5)) for f, v in [(1900, 1.0), (2700, 0.7), (3400, 0.4), (4500, 0.2)]], mul(highpass(noise(0.8, r), 2500), env_ad(int(0.8 * SR), 0.0005, 14)), gains=[1, 1, 1, 1, 0.6]))
    out["parry_ring"] = normalise(mix(*[mul(sine(f, 1.2, v), env_ad(int(1.2 * SR), 0.0006, 2.5)) for f, v in [(1250, 1.0), (1875, 0.6), (3100, 0.3)]]), 0.8)
    out["pistol"] = normalise(mix(mul(highpass(noise(0.35, r), 600), env_ad(int(0.35 * SR), 0.0005, 10)), mul(sweep(400, 120, 0.35), env_ad(int(0.35 * SR), 0.001, 6))))
    out["musket"] = normalise(mix(mul(highpass(noise(0.5, r), 400), env_ad(int(0.5 * SR), 0.0005, 8)), mul(sweep(300, 70, 0.5), env_ad(int(0.5 * SR), 0.001, 5))))
    out["blunderbuss"] = normalise(mix(mul(lowpass(noise(0.7, r), 900), env_ad(int(0.7 * SR), 0.001, 4)), mul(sweep(150, 40, 0.7), env_ad(int(0.7 * SR), 0.002, 3))))
    out["step_wood"] = normalise(mix(mul(lowpass(noise(0.15, r), 800), env_ad(int(0.15 * SR), 0.001, 7)), mul(sweep(160, 90, 0.15), env_ad(int(0.15 * SR), 0.001, 8))), 0.6)
    out["step_sand"] = normalise(mul(bandpass(noise(0.2, r), 500, 3000), env_ad(int(0.2 * SR), 0.01, 3.5)), 0.4)
    coin = mix(*[mul(sine(f, 0.5, v), env_ad(int(0.5 * SR), 0.001, 4)) for f, v in [(1800, 1.0), (2400, 0.7)]])
    coin2 = [0.0] * int(0.08 * SR) + coin
    out["coin"] = normalise(mix(coin, coin2), 0.7)
    out["chest"] = normalise(mix(mul(sweep(130, 70, 0.5), env_ad(int(0.5 * SR), 0.002, 4)), mul(highpass(noise(0.5, r), 2000), env_ad(int(0.5 * SR), 0.0005, 12)), coin2), 0.8)
    for name, f0, f1, sec in [("roar_kraken", 70, 30, 2.4), ("roar_serpent", 220, 90, 2.0), ("roar_crab", 400, 200, 1.0), ("roar_colossus", 60, 45, 2.2), ("roar_leviathan", 110, 40, 2.8), ("roar_ghost", 330, 160, 2.4)]:
        n = int(sec * SR)
        body = mix(sweep(f0, f1, sec, 1.0), sweep(f0 * 2.01, f1 * 2.0, sec, 0.5), scale(bandpass(noise(sec, r), f0, f0 * 6), 0.7))
        wob = [0.7 + 0.3 * math.sin(i / SR * 17) for i in range(n)]
        out[name] = normalise(mul(mul(body, wob), [math.sin(math.pi * i / n) ** 0.6 for i in range(n)]), 0.9)
    out["ui_click"] = normalise(mul(sine(900, 0.07), env_ad(int(0.07 * SR), 0.001, 4)), 0.5)
    out["ui_confirm"] = normalise(mix(mul(sine(660, 0.25), env_ad(int(0.25 * SR), 0.002, 3)), [0.0] * int(0.1 * SR) + mul(sine(880, 0.25), env_ad(int(0.25 * SR), 0.002, 3))), 0.6)
    arp = []
    for k, f in enumerate([523, 659, 784, 1046]):
        arp = mix(arp, [0.0] * int(0.09 * k * SR) + mul(sine(f, 0.5), env_ad(int(0.5 * SR), 0.003, 2.5))) if arp else mul(sine(f, 0.5), env_ad(int(0.5 * SR), 0.003, 2.5))
    out["level_up"] = normalise(arp, 0.7)
    out["achievement"] = normalise(mix(arp, scale([0.0] * int(0.12 * SR) + arp, 0.6)), 0.7)
    out["dice_roll"] = normalise(mul(bandpass(noise(0.6, r), 600, 4000), [abs(math.sin(i / SR * 55)) ** 3 * (1 - i / (0.6 * SR)) for i in range(int(0.6 * SR))]), 0.6)
    out["card"] = normalise(mul(highpass(noise(0.15, r), 1500), env_ad(int(0.15 * SR), 0.002, 4)), 0.5)
    out["gulls"] = normalise(mix(*[[0.0] * int(at * SR) + mul(sweep(1900, 1300, 0.45, 1.0), [math.sin(math.pi * i / (0.45 * SR)) for i in range(int(0.45 * SR))]) for at in (0.0, 0.7, 1.5)]), 0.35)
    # Damage control (crash damage and crew repair): own seed so the sounds above stay as they were.
    r2 = random.Random(23)
    crash = mix(mul(lowpass(noise(1.4, r2), 500), env_ad(int(1.4 * SR), 0.002, 3.0)), mul(sweep(110, 35, 1.4, 1.0), env_ad(int(1.4 * SR), 0.003, 2.5)))
    crack = silence(1.4)
    for k in range(16):
        at = int(r2.uniform(0, 0.7) * SR)
        c = mul(highpass(noise(0.06, r2), 1500), env_ad(int(0.06 * SR), 0.0005, 6))
        for i, v in enumerate(c):
            crack[at + i] += v * r2.uniform(0.3, 1.0) * (1.0 - at / (1.4 * SR))
    out["hull_crash"] = normalise(mix(crash, crack, gains=[1.0, 0.7]))
    knock = mix(mul(lowpass(noise(0.12, r2), 2500), env_ad(int(0.12 * SR), 0.0005, 9)), mul(sweep(420, 260, 0.12, 0.8), env_ad(int(0.12 * SR), 0.0005, 8)))
    ham = silence(1.2)
    for at in (0.0, 0.35, 0.7):
        for i, v in enumerate(knock):
            ham[int(at * SR) + i] += v
    out["hammer"] = normalise(ham, 0.7)
    n = int(1.6 * SR)
    stroke = [abs(math.sin(math.pi * i / (0.8 * SR))) ** 2 for i in range(n)]
    out["pump"] = normalise(mul(mix(bandpass(noise(1.6, r2), 180, 900), sweep(140, 120, 1.6, 0.4)), stroke), 0.45)
    return out


def ambience_all():
    r = random.Random(11)
    out = {}
    for name, cut, depth in [("waves_calm", 400, 0.5), ("waves_mid", 700, 0.7), ("waves_rough", 1100, 0.9)]:
        n = 6 * SR
        base = lowpass(noise(6, r), cut)
        sw = [1.0 - depth + depth * (0.5 + 0.5 * math.sin(2 * math.pi * i / SR / 6.0 * (1 + k))) for i in range(n) for k in [0]]
        out[name] = fade_edges(normalise(mul(base, sw), 0.6), 400)
    out["wind"] = fade_edges(normalise(mul(bandpass(noise(6, r), 200, 900), [0.7 + 0.3 * math.sin(2 * math.pi * i / SR / 3.0) for i in range(6 * SR)]), 0.5), 400)
    out["rain"] = fade_edges(normalise(highpass(lowpass(noise(5, r), 6000), 1200), 0.5), 400)
    return out


# ---- voices (barks are formant babble: they carry tone and timing, the words are subtitles) ---------------------

def vowel(f0, formants, sec):
    n = int(sec * SR)
    out = [0.0] * n
    src = saw(f0, n)
    for f, bw in formants:
        band = bandpass(src, max(f - bw, 80), f + bw)
        for i in range(n):
            out[i] += band[i]
    return out


def voice_all():
    r = random.Random(17)
    out = {}
    forms = [[(700, 120), (1100, 150)], [(400, 90), (2000, 200)], [(300, 80), (900, 120)], [(550, 100), (1700, 180)]]
    for name, f0, syll in [("bark_a", 120, 4), ("bark_b", 105, 3), ("bark_c", 135, 5), ("captain_a", 98, 4), ("captain_b", 90, 5), ("taunt_a", 110, 6), ("taunt_b", 128, 5)]:
        track = []
        for s in range(syll):
            sec = r.uniform(0.09, 0.17)
            v = vowel(f0 * r.uniform(0.9, 1.2), r.choice(forms), sec)
            e = [math.sin(math.pi * i / len(v)) for i in range(len(v))]
            track += mul(v, e) + silence(r.uniform(0.01, 0.04))
        out[name] = normalise(track, 0.6)
    return out


def main():
    groups = {"sfx": ("sfx", sfx_all), "voice": ("voice", voice_all), "ambience": ("ambience", ambience_all)}
    want = sys.argv[1:] or list(groups.keys())
    for g in want:
        folder, fn = groups[g]
        for name, samples in fn().items():
            write_ogg(fade_edges(list(samples)), os.path.join(ROOT, folder, name + ".ogg"), quality=3)
            print(g, name, len(samples) / SR)


if __name__ == "__main__":
    main()
