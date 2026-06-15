#!/usr/bin/env python3
"""Extract percussive-hit timings (e.g. xylophone onsets) from a song into a
timings file the propagator-network visualizer can play the timeline against.

Pipeline:
    URL or audio file  --(yt-dlp)-->  audio  --(ffmpeg)-->  mono PCM
                       --(spectral-flux onset detection)-->  hit times (seconds)
                       -->  timings JSON  { "hits": [...] }

The visualizer (tools/viz/index.html) advances ONE timeline step per hit, so the
network's reduction is played back in time with the music.

Usage
-----
    # straight from YouTube (needs network + yt-dlp; pass cookies if YouTube
    # asks you to "confirm you're not a bot" — see --cookies-from-browser):
    python3 extract-song-timings.py 'https://youtu.be/PoH5hC5PzSQ' -o song.timings.json --keep-audio song.mp3

    # from a local audio file you already have:
    python3 extract-song-timings.py mysong.mp3 -o mysong.timings.json

    # tune sensitivity (lower threshold = more hits) and minimum spacing:
    python3 extract-song-timings.py in.wav -o out.json --threshold 1.4 --min-gap 0.08

Dependencies: numpy, ffmpeg on PATH, and (for URLs) yt-dlp. No librosa needed.

Timings file format (also accepted: a bare JSON array, or whitespace/newline
separated numbers):
    { "source": "...", "sampleRate": 22050, "count": N, "hits": [0.51, 0.93, ...] }
"""
import argparse, json, os, subprocess, sys, tempfile, shutil, datetime

SR = 22050  # analysis sample rate (mono)


def have(cmd):
    return shutil.which(cmd) is not None


def fetch_audio(url, dest_dir, cookies_from_browser=None):
    """Download bestaudio from a URL via yt-dlp; return the audio file path."""
    if not have("yt-dlp"):
        sys.exit("yt-dlp not found on PATH. Install with: pip install yt-dlp")
    out = os.path.join(dest_dir, "audio.%(ext)s")
    cmd = ["yt-dlp", "-f", "bestaudio/best", "-x", "--audio-format", "mp3",
           "-o", out, url]
    if cookies_from_browser:
        cmd[1:1] = ["--cookies-from-browser", cookies_from_browser]
    print("[extract] downloading audio:", " ".join(cmd), file=sys.stderr)
    subprocess.run(cmd, check=True)
    for f in os.listdir(dest_dir):
        if f.startswith("audio."):
            return os.path.join(dest_dir, f)
    sys.exit("yt-dlp produced no audio file")


def decode_pcm(path):
    """Decode any audio file to mono float32 samples at SR via ffmpeg."""
    if not have("ffmpeg"):
        sys.exit("ffmpeg not found on PATH (try: pip install static-ffmpeg).")
    import numpy as np
    cmd = ["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR),
           "-f", "s16le", "-"]
    raw = subprocess.run(cmd, check=True, stdout=subprocess.PIPE).stdout
    x = np.frombuffer(raw, dtype="<i2").astype("float32") / 32768.0
    return x


def detect_onsets(x, threshold=1.5, min_gap=0.06, hop=512, win=1024,
                  band_low=0.0, band_high=0.0, min_strength=0.0):
    """Spectral-flux onset detection tuned for sharp percussive hits.

    Returns a sorted list of onset times in seconds. `threshold` scales the
    adaptive (local-mean + std) picking threshold; `min_gap` is the minimum
    seconds between consecutive onsets.

    `band_low`/`band_high` (Hz) restrict the flux to a frequency band so you can
    isolate ONE instrument's onsets — e.g. a low xylophone / marimba sits in a
    low-mid band (a few hundred Hz), distinct from arpeggiated strings higher up
    and the kick/bass below. `band_high <= 0` means "up to Nyquist".

    `min_strength` (0..1) is an absolute loudness floor: a peak is kept only if
    its flux reaches this fraction of the song's 99.5th-percentile flux. This is
    what separates the loud mallet hits from the quiet bass/percussion bleed in
    the same band — raise it to thin a dense band down to just the strong notes.
    """
    import numpy as np
    if len(x) < win:
        return []
    window = np.hanning(win).astype("float32")
    n_frames = 1 + (len(x) - win) // hop
    # short-time magnitude spectra
    mags = np.empty((n_frames, win // 2 + 1), dtype="float32")
    for i in range(n_frames):
        frame = x[i * hop: i * hop + win] * window
        mags[i] = np.abs(np.fft.rfft(frame))
    # spectral flux: sum of positive bin-to-bin magnitude increases
    diff = np.diff(mags, axis=0)
    pos = np.maximum(diff, 0.0)
    if band_low > 0 or band_high > 0:
        n_bins = pos.shape[1]
        freqs = np.arange(n_bins) * (SR / 2) / (n_bins - 1)
        hi = band_high if band_high > 0 else SR / 2
        mask = ((freqs >= band_low) & (freqs <= hi)).astype("float32")
        flux = (pos * mask).sum(axis=1)
    else:
        flux = pos.sum(axis=1)
    flux = np.concatenate([[0.0], flux])
    # absolute strength floor, normalized by a robust (99.5th-pct) loudness scale
    scale = np.percentile(flux, 99.5) if flux.size else 0.0
    strength = flux / scale if scale > 0 else flux
    if flux.max() > 0:
        flux = flux / flux.max()
    # adaptive threshold over a local window
    w = max(3, int(round(0.10 * SR / hop)))     # ~100ms half-window
    pad = np.pad(flux, w, mode="edge")
    csum = np.cumsum(np.insert(pad, 0, 0.0))
    local_mean = (csum[2 * w + 1:] - csum[:-(2 * w + 1)]) / (2 * w + 1)
    local_mean = local_mean[:len(flux)]
    sq = np.pad(flux * flux, w, mode="edge")
    csq = np.cumsum(np.insert(sq, 0, 0.0))
    local_ms = (csq[2 * w + 1:] - csq[:-(2 * w + 1)]) / (2 * w + 1)
    local_ms = local_ms[:len(flux)]
    local_std = np.sqrt(np.maximum(local_ms - local_mean * local_mean, 0.0))
    thr = local_mean + threshold * local_std + 1e-4
    min_frames = max(1, int(round(min_gap * SR / hop)))
    onsets, last = [], -10 ** 9
    for i in range(1, len(flux) - 1):
        if flux[i] >= thr[i] and flux[i] >= flux[i - 1] and flux[i] >= flux[i + 1] \
                and strength[i] >= min_strength:
            if i - last >= min_frames:
                onsets.append(round(i * hop / SR, 4))
                last = i
    return onsets


def band_onset_envelope(x, band_low=0.0, band_high=0.0, hop=256, win=1024):
    """Positive spectral-flux envelope (optionally band-limited), + frames/sec."""
    import numpy as np
    window = np.hanning(win).astype("float32")
    n_frames = 1 + (len(x) - win) // hop
    mags = np.empty((n_frames, win // 2 + 1), dtype="float32")
    for i in range(n_frames):
        mags[i] = np.abs(np.fft.rfft(x[i * hop: i * hop + win] * window))
    pos = np.maximum(np.diff(mags, axis=0), 0.0)
    if band_low > 0 or band_high > 0:
        freqs = np.arange(pos.shape[1]) * (SR / 2) / (pos.shape[1] - 1)
        hi = band_high if band_high > 0 else SR / 2
        mask = ((freqs >= band_low) & (freqs <= hi)).astype("float32")
        env = (pos * mask).sum(axis=1)
    else:
        env = pos.sum(axis=1)
    return np.concatenate([[0.0], env]), SR / hop


def beat_grid(x, dur, bpm=0.0, phase=-1.0, band_low=0.0, band_high=0.0,
              tempo_min=50.0, tempo_max=100.0):
    """Lock a steady beat grid to ONE instrument's metronomic pulse.

    Some instruments (a low xylophone here) play a dead-steady pulse but are
    quieter than the kick/snare on the loud beats — so per-onset picking grabs
    the wrong transients and misses the quiet ones. The fix: estimate the tempo
    (period) from the band onset envelope's autocorrelation, lock the phase to
    where that band's energy actually lands, and emit a grid `phase + k·period`.
    Constant-tempo tracks stay aligned for their whole length (no drift).

    `bpm` (0 = auto-estimate within tempo_min..tempo_max); `phase` start seconds
    (<0 = auto). Returns the grid times in seconds.
    """
    import numpy as np
    env, fps = band_onset_envelope(x, band_low, band_high)
    e = env - env.mean(); e[e < 0] = 0.0
    tol = int(round(0.05 * fps))

    def score(P, ph):
        idx = np.round(np.arange(ph, dur - 0.1, P) * fps).astype(int)
        return sum(env[max(0, i - tol): i + tol + 1].max()
                   for i in idx if 0 <= i < len(env)) / max(1, len(idx))

    # candidate period: explicit bpm, else autocorrelation within the tempo range
    if bpm > 0:
        cand = 60.0 / bpm
    else:
        ac = np.correlate(e, e, mode="full")[len(e) - 1:]
        lags = np.arange(len(ac)) / fps
        win = (lags >= 60.0 / tempo_max) & (lags <= 60.0 / tempo_min)
        idx = np.where(win)[0]
        cand = lags[idx[np.argmax(ac[idx])]]

    # Phase: when a quiet instrument is the target, blind phase-finding locks onto
    # the LOUDER beat. So if --phase anchors the pulse (e.g. its first audible
    # hit), constrain the search near it; otherwise take the globally best-aligned
    # phase. Refine the period jointly (±3%) — a coarse period drifts over a long
    # track; the per-beat tolerance-max keeps the grid on the metrical position.
    if bpm > 0:
        periods = [cand]
    else:
        periods = np.arange(cand * 0.97, cand * 1.03, 0.0002)
    if phase >= 0:
        phases = np.arange(max(0.0, phase - 0.12), phase + 0.12, 0.01)
    else:
        phases = np.arange(0.0, cand, 0.02)
    best = (-1.0, cand, phases[0])
    for P in periods:
        for ph in phases:
            s = score(P, ph)
            if s > best[0]:
                best = (s, float(P), float(ph))
    _, period, phase = best
    return [round(float(t), 4) for t in np.arange(phase, dur - 0.02, period)], period, phase


def tempo_map(dur, segments, phase=-1.0):
    """Piecewise-constant beat grid: a list of (start_sec, bpm) segments, each
    emitting beats at its own tempo from its start until the next segment (or the
    end). The first segment may be anchored with `phase` (else it starts at its
    own start time); later segments start exactly on their boundary, so a tempo
    switch lands a beat right on the drop. Lets you e.g. hold a slow intro pulse
    then rush 10x faster at the chorus.
    """
    segs = sorted(segments, key=lambda s: s[0])
    times = []
    for i, (start, bpm) in enumerate(segs):
        end = segs[i + 1][0] if i + 1 < len(segs) else dur
        period = 60.0 / bpm
        t = phase if (i == 0 and phase >= 0) else start
        while t < start:
            t += period
        while t < end - 1e-4:
            times.append(round(t, 4))
            t += period
    return sorted(set(times))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source", help="YouTube/other URL, or a local audio file")
    ap.add_argument("-o", "--out", default="song.timings.json", help="output timings JSON")
    ap.add_argument("--threshold", type=float, default=1.5, help="onset sensitivity (lower = more hits)")
    ap.add_argument("--min-gap", type=float, default=0.06, help="min seconds between hits")
    ap.add_argument("--band-low", type=float, default=0.0,
                    help="restrict onsets to freqs >= this (Hz) — isolate one instrument's band")
    ap.add_argument("--band-high", type=float, default=0.0,
                    help="restrict onsets to freqs <= this (Hz); 0 = up to Nyquist")
    ap.add_argument("--min-strength", type=float, default=0.0,
                    help="loudness floor 0..1 (fraction of 99.5pct flux) — thin a band to just the strong hits")
    ap.add_argument("--grid", action="store_true",
                    help="emit a steady beat grid locked to the band's pulse (best for a quiet metronomic "
                         "instrument like a low xylophone) instead of per-onset picking")
    ap.add_argument("--bpm", type=float, default=0.0, help="grid tempo (0 = auto-estimate)")
    ap.add_argument("--phase", type=float, default=-1.0, help="grid start offset in seconds (<0 = auto)")
    ap.add_argument("--tempo-min", type=float, default=50.0, help="auto-tempo lower bound (BPM)")
    ap.add_argument("--tempo-max", type=float, default=100.0, help="auto-tempo upper bound (BPM)")
    ap.add_argument("--segments", default="",
                    help="piecewise tempo map as 'startSec:bpm,startSec:bpm,...' "
                         "(e.g. '0:67.5,28.5:675' = slow intro then 10x burst at 28.5s); "
                         "uses --phase to anchor the first segment")
    ap.add_argument("--keep-audio", metavar="PATH", help="also save the decoded/downloaded audio here")
    ap.add_argument("--cookies-from-browser", help="pass to yt-dlp if YouTube demands sign-in (e.g. chrome, firefox)")
    args = ap.parse_args()

    try:
        import numpy  # noqa: F401
    except ImportError:
        sys.exit("numpy is required: pip install numpy")

    tmp = tempfile.mkdtemp(prefix="songtimings-")
    try:
        is_url = "://" in args.source
        audio = fetch_audio(args.source, tmp, args.cookies_from_browser) if is_url else args.source
        if not os.path.exists(audio):
            sys.exit(f"audio not found: {audio}")
        x = decode_pcm(audio)
        dur = len(x) / SR
        mode = "onset"
        grid_period = grid_phase = None
        if args.segments:
            mode = "segments"
            segs = [(float(a), float(b)) for a, b in
                    (p.split(":") for p in args.segments.split(","))]
            hits = tempo_map(dur, segs, phase=args.phase)
            print(f"[extract] {dur:.1f}s audio → {len(hits)} beats over "
                  f"{len(segs)} tempo segments {segs} ({len(hits) / dur:.1f}/s avg)",
                  file=sys.stderr)
        elif args.grid:
            mode = "grid"
            hits, grid_period, grid_phase = beat_grid(
                x, dur, bpm=args.bpm, phase=args.phase,
                band_low=args.band_low, band_high=args.band_high,
                tempo_min=args.tempo_min, tempo_max=args.tempo_max)
            print(f"[extract] {dur:.1f}s audio → {len(hits)} grid beats "
                  f"@ {60 / grid_period:.1f} BPM (period {grid_period:.4f}s, phase "
                  f"{grid_phase:.3f}s, {len(hits) / dur:.1f}/s)", file=sys.stderr)
        else:
            hits = detect_onsets(x, threshold=args.threshold, min_gap=args.min_gap,
                                 band_low=args.band_low, band_high=args.band_high,
                                 min_strength=args.min_strength)
            print(f"[extract] {dur:.1f}s audio → {len(hits)} hits "
                  f"({len(hits) / dur:.1f}/s)", file=sys.stderr)
        doc = {
            "source": args.source,
            "generated": datetime.datetime.utcnow().isoformat() + "Z",
            "mode": mode,
            "sampleRate": SR,
            "durationSec": round(dur, 3),
            "threshold": args.threshold,
            "minGap": args.min_gap,
            "bandLow": args.band_low,
            "bandHigh": args.band_high,
            "minStrength": args.min_strength,
            "count": len(hits),
            "hits": hits,
        }
        if mode == "grid":
            doc["bpm"] = round(60 / grid_period, 3)
            doc["periodSec"] = round(grid_period, 5)
            doc["phaseSec"] = round(grid_phase, 4)
        elif mode == "segments":
            doc["segments"] = [{"startSec": s, "bpm": b} for s, b in segs]
        with open(args.out, "w") as f:
            json.dump(doc, f, indent=0)
        print(f"[extract] wrote {args.out}", file=sys.stderr)
        if args.keep_audio and is_url:
            shutil.copy(audio, args.keep_audio)
            print(f"[extract] saved audio → {args.keep_audio}", file=sys.stderr)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
