#!/usr/bin/env python3
"""Synthesizes every sound effect used by the app (pure Python, no deps).

Run from the project root:
    python3 tool/generate_sounds.py

Writes 16-bit mono WAV files into assets/sounds/. Everything is generated
from scratch (oscillators + filtered noise), so there are no licensing
concerns. Tweak the recipes below and re-run to change how the ref sounds.
"""

import math
import os
import random
import struct
import wave

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')
TAU = 2 * math.pi

rng = random.Random(9)  # deterministic output


# ---------------------------------------------------------------- utilities

def n_samples(seconds):
    return int(seconds * SR)


def silence(seconds):
    return [0.0] * n_samples(seconds)


def mix(*tracks, offsets=None):
    """Sum tracks; offsets (seconds) shift each track's start."""
    offsets = offsets or [0.0] * len(tracks)
    length = max(len(t) + n_samples(o) for t, o in zip(tracks, offsets))
    out = [0.0] * length
    for t, o in zip(tracks, offsets):
        start = n_samples(o)
        for i, v in enumerate(t):
            out[start + i] += v
    return out


def concat(*tracks):
    out = []
    for t in tracks:
        out.extend(t)
    return out


def gain(track, g):
    return [v * g for v in track]


def envelope(length, attack, release, hold_curve=None):
    """Linear attack, sustain at 1, linear release (all in seconds)."""
    a, r = n_samples(attack), n_samples(release)
    env = []
    for i in range(length):
        if i < a:
            v = i / max(a, 1)
        elif i > length - r:
            v = max(0.0, (length - i) / max(r, 1))
        else:
            v = 1.0
        if hold_curve:
            v *= hold_curve(i / SR)
        env.append(v)
    return env


def apply_env(track, env):
    return [v * e for v, e in zip(track, env)]


def exp_decay(length, tau, attack=0.002):
    a = n_samples(attack)
    out = []
    for i in range(length):
        t = i / SR
        v = math.exp(-t / tau)
        if i < a:
            v *= i / max(a, 1)
        out.append(v)
    return out


def noise(seconds):
    return [rng.uniform(-1, 1) for _ in range(n_samples(seconds))]


class Biquad:
    """RBJ audio-EQ-cookbook biquad."""

    def __init__(self, kind, freq, q=0.707):
        self.kind, self.q = kind, q
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0
        self.set_freq(freq)

    def set_freq(self, freq):
        freq = min(max(freq, 20.0), SR * 0.45)
        w0 = TAU * freq / SR
        cos_w0, alpha = math.cos(w0), math.sin(w0) / (2 * self.q)
        if self.kind == 'lp':
            b0, b1, b2 = (1 - cos_w0) / 2, 1 - cos_w0, (1 - cos_w0) / 2
        elif self.kind == 'hp':
            b0, b1, b2 = (1 + cos_w0) / 2, -(1 + cos_w0), (1 + cos_w0) / 2
        else:  # band-pass, constant 0 dB peak gain
            b0, b1, b2 = alpha, 0.0, -alpha
        a0, a1, a2 = 1 + alpha, -2 * cos_w0, 1 - alpha
        self.b0, self.b1, self.b2 = b0 / a0, b1 / a0, b2 / a0
        self.a1, self.a2 = a1 / a0, a2 / a0

    def process(self, x):
        y = (self.b0 * x + self.b1 * self.x1 + self.b2 * self.x2
             - self.a1 * self.y1 - self.a2 * self.y2)
        self.x2, self.x1 = self.x1, x
        self.y2, self.y1 = self.y1, y
        return y


def filt(track, kind, freq, q=0.707, sweep_to=None):
    f = Biquad(kind, freq, q)
    out = []
    n = len(track)
    for i, v in enumerate(track):
        if sweep_to is not None and i % 32 == 0:
            # exponential sweep from freq to sweep_to across the track
            f.set_freq(freq * (sweep_to / freq) ** (i / max(n - 1, 1)))
        out.append(f.process(v))
    return out


def tone(freq_fn, seconds, shape='sine', harmonics=None):
    """Oscillator with a time-varying frequency function freq_fn(t)."""
    out, phase = [], 0.0
    for i in range(n_samples(seconds)):
        t = i / SR
        phase += freq_fn(t) / SR
        p = phase % 1.0
        if shape == 'sine':
            v = math.sin(TAU * p)
        elif shape == 'saw':
            v = 2 * p - 1
        elif shape == 'square':
            v = 1.0 if p < 0.5 else -1.0
        elif shape == 'additive':
            v = sum(a * math.sin(TAU * phase * (k + 1))
                    for k, a in enumerate(harmonics))
        else:
            raise ValueError(shape)
        out.append(v)
    return out


def saturate(track, drive):
    return [math.tanh(v * drive) for v in track]


def bell(freq, seconds, decay=0.35):
    # slightly inharmonic partials give a glassy chime
    partials = [(1.0, 1.0), (2.01, 0.45), (3.0, 0.2), (4.2, 0.12)]
    out = [0.0] * n_samples(seconds)
    for ratio, amp in partials:
        t = tone(lambda _t, f=freq * ratio: f, seconds)
        env = exp_decay(len(t), decay / ratio ** 0.5, attack=0.003)
        for i in range(len(out)):
            out[i] += t[i] * env[i] * amp
    return out


def brass(freq, seconds, vibrato=0.0, vib_rate=5.5, bright=2400):
    f = (lambda t: freq * (1 + vibrato * math.sin(TAU * vib_rate * t) *
                           min(1.0, t / 0.25)))
    t = tone(f, seconds, 'saw')
    t = filt(t, 'lp', bright, q=1.2)
    return saturate(t, 1.6)


def kick(seconds=0.35, start=160, end=45):
    t = tone(lambda x: end + (start - end) * math.exp(-x / 0.045), seconds)
    return apply_env(t, exp_decay(len(t), 0.12, attack=0.001))


def write(name, track, peak=0.89):
    m = max(abs(v) for v in track) or 1.0
    scale = peak / m
    # tiny fade-out to avoid clicks
    fade = n_samples(0.01)
    for i in range(fade):
        track[-1 - i] *= i / fade
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, f'{name}.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(
            struct.pack('<h', int(max(-1, min(1, v * scale)) * 32767))
            for v in track))
    print(f'  {name}.wav  {len(track) / SR:.2f}s')


# ------------------------------------------------------------------ recipes

def whistle(seconds, base=2950.0, trill=46.0):
    """Referee pea whistle: a bright tone warbled by the rattling pea."""
    jitter_phase = [0.0]

    def f(t):
        jitter_phase[0] += rng.uniform(-0.6, 0.6) / SR * 40
        return base + 210 * math.sin(TAU * trill * t + jitter_phase[0])

    main = tone(f, seconds)
    over = tone(lambda t: 2 * f(t), seconds)
    am = [0.72 + 0.28 * math.sin(TAU * trill * i / SR) for i in range(len(main))]
    body = [(m + 0.12 * o) * a for m, o, a in zip(main, over, am)]
    breath = filt(noise(seconds), 'bp', base, q=2.5)
    track = [b + 0.35 * n for b, n in zip(body, breath)]
    return apply_env(track, envelope(len(track), 0.012, 0.07))


def horn(seconds, freqs=(220.0, 233.1, 329.6), drive=2.8):
    tracks = [tone(lambda _t, f=f: f, seconds, 'saw') for f in freqs]
    summed = [sum(v) / len(freqs) for v in zip(*tracks)]
    summed = saturate(summed, drive)
    summed = filt(summed, 'lp', 3200)
    return apply_env(summed, envelope(len(summed), 0.008, 0.06))


def swish(seconds=0.42):
    hiss = filt(noise(seconds), 'bp', 7000, q=0.8, sweep_to=2600)
    hiss = apply_env(hiss, [min(1.0, (i / SR) / 0.025) * math.exp(-(i / SR) / 0.13)
                            for i in range(len(hiss))])
    snap = filt(noise(0.09), 'bp', 1600, q=1.4)
    snap = apply_env(snap, exp_decay(len(snap), 0.025))
    return mix(hiss, gain(snap, 0.6), offsets=[0.0, 0.03])


def crowd(seconds=2.6):
    # broad roar: band-limited noise, swelling then fading
    roar = filt(filt(noise(seconds), 'lp', 2600), 'hp', 280)

    def roar_env(t):
        if t < 0.35:
            return (t / 0.35) ** 1.5
        return max(0.0, 1 - ((t - 0.35) / (seconds - 0.35)) ** 2)
    roar = [v * roar_env(i / SR) for i, v in enumerate(roar)]
    # claps: short bright noise bursts at random times
    claps = [0.0] * len(roar)
    t = 0.05
    while t < seconds - 0.1:
        clap = filt(noise(0.03), 'bp', rng.uniform(1100, 2200), q=1.1)
        clap = apply_env(clap, exp_decay(len(clap), 0.008))
        start = n_samples(t)
        amp = rng.uniform(0.3, 0.9) * roar_env(t)
        for i, v in enumerate(clap):
            if start + i < len(claps):
                claps[start + i] += v * amp
        t += rng.expovariate(38)
    # a few "wooo" voices
    voices = [0.0] * len(roar)
    for _ in range(6):
        f0 = rng.uniform(330, 620)
        dur = rng.uniform(0.7, 1.4)
        st = rng.uniform(0.1, 0.6)
        v = tone(lambda x, f0=f0, dur=dur: f0 * (1 + 0.35 * min(1, x / dur * 2))
                 * (1 + 0.012 * math.sin(TAU * 6 * x)), dur, 'saw')
        v = filt(v, 'bp', 900, q=1.5)
        v = apply_env(v, envelope(len(v), 0.15, 0.35))
        start = n_samples(st)
        for i, x in enumerate(v):
            if start + i < len(voices):
                voices[start + i] += x * 0.18
    return [r * 0.8 + c * 1.4 + v for r, c, v in zip(roar, claps, voices)]


def sad_trombone():
    notes = [(196.0, 0.36), (185.0, 0.36), (174.6, 0.36), (164.8, 1.15)]
    parts = []
    for idx, (f, d) in enumerate(notes):
        last = idx == len(notes) - 1
        b = brass(f, d, vibrato=0.035 if last else 0.0, vib_rate=5.0, bright=1500)
        # "wah": open the tone then close it again
        b = apply_env(b, [math.sin(math.pi * min(1, (i / SR) / d)) ** 0.6
                          for i in range(len(b))])
        parts.append(b)
        parts.append(silence(0.04))
    return concat(*parts)


def brick():
    partials = [(530, 1.0), (1390, 0.6), (2120, 0.45), (3370, 0.3), (4510, 0.15)]
    out = [0.0] * n_samples(0.55)
    for f, a in partials:
        t = tone(lambda _t, f=f: f, 0.55)
        env = exp_decay(len(t), 0.09 + 30 / f)
        for i in range(len(out)):
            out[i] += t[i] * env[i] * a
    thud = kick(0.25, 140, 60)
    return mix(out, gain(thud, 0.9))


def whoosh(seconds=0.38, up=True):
    a, b = (500, 5000) if up else (5000, 500)
    w = filt(noise(seconds), 'bp', a, q=1.6, sweep_to=b)
    return apply_env(w, [math.sin(math.pi * i / len(w)) ** 1.5 for i in range(len(w))])


def fanfare(notes, step=0.09, last_len=0.45):
    parts = []
    for i, f in enumerate(notes):
        d = last_len if i == len(notes) - 1 else step
        b = brass(f, d + 0.05, bright=4200)
        b = apply_env(b, envelope(len(b), 0.006, 0.05))
        parts.append((b, i * step))
    return mix(*[p for p, _ in parts], offsets=[o for _, o in parts])


def build_all():
    print('Synthesizing sounds ->', os.path.normpath(OUT_DIR))

    write('whistle', whistle(0.55))
    write('whistle_long', whistle(1.25))
    write('whistle_double', concat(whistle(0.22), silence(0.09), whistle(0.42)))
    write('buzzer', horn(1.7))
    write('timeout', concat(horn(0.32), silence(0.12), horn(0.32)))
    write('airhorn', concat(
        horn(0.16, (466.2, 587.3, 698.5), 3.5), silence(0.06),
        horn(0.16, (466.2, 587.3, 698.5), 3.5), silence(0.06),
        horn(1.1, (466.2, 587.3, 698.5), 3.5)))
    write('swish', swish())

    # made free throw: swish + soft ding
    write('score1', mix(swish(), gain(bell(1318.5, 0.7), 0.35), offsets=[0, 0.08]))
    # made two: swish + rising two-note chime
    write('score2', mix(swish(), gain(bell(1046.5, 0.5), 0.35),
                        gain(bell(1568.0, 0.8), 0.35), offsets=[0, 0.08, 0.2]))
    # made three: BANG (kick + crack) + swish + brass fanfare
    crack = apply_env(filt(noise(0.12), 'hp', 1800), exp_decay(n_samples(0.12), 0.03))
    write('score3', mix(kick(0.4), gain(crack, 0.7), gain(swish(), 0.6),
                        gain(fanfare([523.3, 659.3, 784.0, 1046.5]), 0.55),
                        offsets=[0, 0, 0.05, 0.12]))
    write('airball', sad_trombone())
    write('crowd', crowd())
    write('brick', brick())
    write('block', mix(kick(0.35, 120, 40), gain(whoosh(0.3, up=False), 0.7),
                       gain(apply_env(filt(noise(0.06), 'bp', 900, q=1.0),
                                      exp_decay(n_samples(0.06), 0.015)), 0.8)))
    write('steal', whoosh(0.34, up=True))
    write('beep', apply_env(tone(lambda _t: 1046.5, 0.12, 'square'),
                            envelope(n_samples(0.12), 0.003, 0.02)), peak=0.5)
    write('tipoff', mix(whistle(0.9), gain(fanfare([392.0, 523.3, 659.3, 784.0],
                                                   step=0.11, last_len=0.6), 0.6),
                        offsets=[0, 0.75]))


if __name__ == '__main__':
    build_all()
