# Propagator-network visualizer

`index.html` is a single-file, no-build React + SVG viewer for the propagator
network a Prologos program executes on. Generate a trace and drop it in:

```
racket tools/viz-export.rkt FILE.prologos -o out.json [--reduce]
```

Open `index.html` (it pulls React / d3 / Babel from CDNs, so it needs network),
then drop the JSON onto the page.

## Playback

Two ways to step the execution timeline:

1. **Timer playback** — the `▶` button advances one round every *speed* ms.
2. **Music-synced playback** — load an audio file **and** a timings file, then
   play the audio. Each hit timestamp in the timings file advances the timeline
   one step, so the network's reduction plays back *in time with the music*. The
   two controls are independent; starting the audio pauses the timer.

### Timings file format

A timings file lists hit onsets in seconds. Any of these is accepted:

- a bare JSON array: `[0.30, 0.62, 0.95, ...]`
- a JSON object keyed by `hits` / `timings` / `beats` / `onsets` / `times`
  (numbers, or `{ "time": 0.3 }` objects):
  `{ "hits": [0.30, 0.62, ...] }`
- plain text — whitespace/comma/newline-separated numbers.

## Extracting timings from a song

`extract-song-timings.py` turns a song into a timings file by detecting
percussive onsets (e.g. xylophone hits) via spectral flux:

```
# from a URL (needs yt-dlp + ffmpeg; pass cookies if YouTube demands sign-in):
python3 tools/viz/extract-song-timings.py 'https://youtu.be/VIDEO' \
    -o song.timings.json --keep-audio song.mp3 --cookies-from-browser chrome

# from a local audio file:
python3 tools/viz/extract-song-timings.py mysong.mp3 -o mysong.timings.json

# tune: lower --threshold = more hits; --min-gap = min seconds between hits
python3 tools/viz/extract-song-timings.py in.wav -o out.json --threshold 1.4 --min-gap 0.08
```

Dependencies: `numpy`, `ffmpeg` on PATH (`pip install static-ffmpeg` provides a
static binary), and `yt-dlp` for URLs. No librosa required.

> Note: downloading from YouTube in a datacenter / CI environment is frequently
> blocked by YouTube's bot detection and PO-token / DRM gating. Run the script on
> a machine with a logged-in browser (`--cookies-from-browser`) to fetch a real
> song, or point it at an audio file you already have.

## Demo

`examples/` ships a small, copyright-free synthetic xylophone phrase so the
music-sync feature is testable out of the box:

- `examples/demo-xylophone.mp3` — the audio
- `examples/demo-xylophone.timings.json` — its 13 hit onsets
- `examples/make-demo-song.py` — regenerates both (and doubles as an end-to-end
  check that the onset detector recovers the known onsets)

Load a vizTrace, then load those two files in the **music-synced playback**
panel and press play.

## Headless checks

`check.js` node-verifies the viewer's pure core (graph build, layouts, timings
parsing, step mapping) against real vizTrace envelopes:

```
node tools/viz/check.js tools/viz/index.html out.json
```
