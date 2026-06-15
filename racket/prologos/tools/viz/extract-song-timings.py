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


def detect_onsets(x, threshold=1.5, min_gap=0.06, hop=512, win=1024, hifreq=False):
    """Spectral-flux onset detection tuned for sharp percussive hits.

    Returns a sorted list of onset times in seconds. `threshold` scales the
    adaptive (local-mean + std) picking threshold; `min_gap` is the minimum
    seconds between consecutive onsets. With `hifreq`, the flux is weighted
    toward high frequencies — bright mallet/xylophone/glockenspiel hits sit
    there, so this isolates the melodic-percussion line from bass/kick/vocals.
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
    if hifreq:
        n_bins = pos.shape[1]
        freqs = np.arange(n_bins) * (SR / 2) / (n_bins - 1)
        wt = (freqs >= 1500).astype("float32")   # emphasize > ~1.5 kHz (mallet range)
        flux = (pos * wt).sum(axis=1)
    else:
        flux = pos.sum(axis=1)
    flux = np.concatenate([[0.0], flux])
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
        if flux[i] >= thr[i] and flux[i] >= flux[i - 1] and flux[i] >= flux[i + 1]:
            if i - last >= min_frames:
                onsets.append(round(i * hop / SR, 4))
                last = i
    return onsets


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source", help="YouTube/other URL, or a local audio file")
    ap.add_argument("-o", "--out", default="song.timings.json", help="output timings JSON")
    ap.add_argument("--threshold", type=float, default=1.5, help="onset sensitivity (lower = more hits)")
    ap.add_argument("--min-gap", type=float, default=0.06, help="min seconds between hits")
    ap.add_argument("--hifreq", action="store_true",
                    help="weight onsets toward high freqs (isolate bright mallet/xylophone hits)")
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
        hits = detect_onsets(x, threshold=args.threshold, min_gap=args.min_gap, hifreq=args.hifreq)
        print(f"[extract] {dur:.1f}s audio → {len(hits)} hits "
              f"({len(hits) / dur:.1f}/s)", file=sys.stderr)
        doc = {
            "source": args.source,
            "generated": datetime.datetime.utcnow().isoformat() + "Z",
            "sampleRate": SR,
            "durationSec": round(dur, 3),
            "threshold": args.threshold,
            "minGap": args.min_gap,
            "hifreq": args.hifreq,
            "count": len(hits),
            "hits": hits,
        }
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
