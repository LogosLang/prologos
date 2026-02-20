# Dashboard Visualization Improvements + Split Threshold Refinement

**Date**: 2026-02-20
**Status**: COMPLETE

## Changes

### Dashboard (benchmark-dashboard.py)

1. **Crosshair value annotations** — Replaced top-bar x,y coordinate readout with per-plot annotations that follow the crosshair. Suite Overview and Per-File Trend show y value (wall time in seconds); Run Breakdown shows x value (wall time). Uses delete-and-recreate pattern for `dpg.add_plot_annotation()` every 10 frames.

2. **DateTime on Suite Overview x-axis** — X-axis ticks now show `MM-DD HH:MM` above the commit hash (multiline labels). Added `_format_short_datetime()` helper.

3. **Run Breakdown nav buttons moved right** — `< >` buttons now appear after the metadata text, pushed to the right edge via flexible spacer.

4. **Total test count in Run Breakdown header** — Shows `83 files, 2717 tests` instead of just `83 files`.

### Test Splitting (bench-lib.rkt)

5. **`split-min-test-count` parameter** (default: 10) — Third splitting criterion: files must have at least N tests for splitting to be considered. Prevents splitting files with few tests where preamble overhead can't be overcome by parallelism.

6. **CLI flags** — `--split-min-tests N` added to both `run-affected-tests.rkt` and `benchmark-tests.rkt`.

## Files Modified

- `tools/benchmark-dashboard.py` — crosshair annotations, datetime ticks, nav layout, test count
- `tools/bench-lib.rkt` — `split-min-test-count` parameter + 4th criterion
- `tools/run-affected-tests.rkt` — `--split-min-tests` CLI flag
- `tools/benchmark-tests.rkt` — `--split-min-tests` CLI flag

## Verification

- `min-tests=10`: 118 work items (37 split from 2 whales) — test-lang (20) + test-lang-errors (17)
- `min-tests=25`: 83 work items (0 split) — both excluded correctly
- All 2717 tests pass
