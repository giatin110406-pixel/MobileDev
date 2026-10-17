"""Writes the two print sounds (assets/sfx/printer.wav, stamp.wav).

Synthesised from noise and sine waves, so there is nothing to license.
Run from the project root: python tools/gen_print_sounds.py
"""
import math
import random
import struct
import wave

RATE = 22050
random.seed(7)


def write(path, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(
            b"".join(
                struct.pack("<h", int(max(-1, min(1, s / peak * 0.85)) * 32767))
                for s in samples
            )
        )


def printer():
    # 7 jerks over 0.9 s, like the 7 steps of the sheet; each is a burst of
    # dot-matrix needle clicks over a low motor hum, then a short rest.
    total = int(RATE * 0.95)
    out = [0.0] * total
    step = 0.9 / 7
    for k in range(7):
        start = int(RATE * k * step)
        burst = int(RATE * step * 0.72)
        for n in range(burst):
            t = n / RATE
            hum = 0.18 * math.sin(2 * math.pi * 95 * t) * (1 - n / burst * 0.3)
            out[start + n] += hum
        clicks = 9
        for c in range(clicks):
            at = start + int(c * burst / clicks)
            for n in range(int(RATE * 0.006)):
                if at + n >= total:
                    break
                env = math.exp(-n / (RATE * 0.0012))
                tone = math.sin(2 * math.pi * 2400 * n / RATE)
                out[at + n] += (random.uniform(-1, 1) * 0.7 + tone * 0.5) * env
    return out


def stamp():
    total = int(RATE * 0.4)
    out = []
    for n in range(total):
        t = n / RATE
        thud = math.sin(2 * math.pi * (70 - 25 * t) * t) * math.exp(-t / 0.09)
        knock = random.uniform(-1, 1) * math.exp(-t / 0.012) * 0.8
        out.append(thud + knock)
    return out


write("assets/sfx/printer.wav", printer())
write("assets/sfx/stamp.wav", stamp())
