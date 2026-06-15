#!/usr/bin/env python3
"""Generate a small, copyright-free synthetic xylophone melody + its timings file
so the visualizer's music-synced playback can be demoed without downloading
anything. (For a real song, use ../extract-song-timings.py with a URL.)

    python3 make-demo-song.py     # writes demo-xylophone.mp3 + demo-xylophone.timings.json

Each note is a short, fast-decaying tone burst at a known onset time; running the
onset detector over the result recovers those onsets, so the demo doubles as a
self-check that the extraction pipeline works end to end.
"""
import json, os, subprocess, sys

SR = 22050
# (onset seconds, frequency Hz) — an irregular little xylophone phrase
SCORE = [(0.30, 880), (0.62, 988), (0.95, 1047), (1.10, 1175), (1.55, 1319),
         (1.88, 1047), (2.20, 880), (2.35, 1319), (2.80, 1175), (3.15, 1047),
         (3.50, 988), (3.65, 1175), (4.10, 880)]
DUR = 4.6


def main():
    try:
        import numpy as np
    except ImportError:
        sys.exit("numpy required: pip install numpy")
    here = os.path.dirname(os.path.abspath(__file__))
    x = np.zeros(int(DUR * SR), dtype=np.float32)
    for t, f in SCORE:
        i = int(t * SR)
        n = int(0.35 * SR)
        env = np.exp(-np.linspace(0, 9, n)).astype(np.float32)          # fast mallet decay
        k = np.arange(n)
        tone = np.sin(2 * np.pi * f * k / SR) + 0.4 * np.sin(2 * np.pi * 2 * f * k / SR)
        seg = (env * tone * 0.7).astype(np.float32)
        m = min(n, len(x) - i)
        x[i:i + m] += seg[:m]
    x = np.clip(x, -1, 1)
    pcm = (x * 32767).astype("<i2").tobytes()

    mp3 = os.path.join(here, "demo-xylophone.mp3")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(SR),
                    "-ac", "1", "-i", "-", mp3], input=pcm, check=True)

    # the timings ARE the score onsets (ground truth for the demo)
    hits = [round(t, 4) for t, _ in SCORE]
    doc = {"source": "synthetic demo (make-demo-song.py)", "sampleRate": SR,
           "durationSec": DUR, "count": len(hits), "hits": hits}
    with open(os.path.join(here, "demo-xylophone.timings.json"), "w") as fp:
        json.dump(doc, fp, indent=0)
    print(f"wrote demo-xylophone.mp3 + demo-xylophone.timings.json ({len(hits)} hits)")


if __name__ == "__main__":
    main()
