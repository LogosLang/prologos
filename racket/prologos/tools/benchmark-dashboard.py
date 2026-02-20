#!/usr/bin/env python3
"""
Prologos Benchmark Dashboard — DearPyGui desktop visualization.

Usage:
    python tools/benchmark-dashboard.py                      # default
    python tools/benchmark-dashboard.py --file path.jsonl    # explicit file
    python tools/benchmark-dashboard.py --threshold 15       # regression % (default: 10)
    python tools/benchmark-dashboard.py --generate-sample    # write synthetic test data

Reads data/benchmarks/timings.jsonl (produced by benchmark-tests.rkt).
See docs/tracking/2026-02-19_BENCHMARKING_INFRASTRUCTURE.md
"""

import argparse
import json
import os
import random
import subprocess
import sys
import time
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

import dearpygui.dearpygui as dpg

# ============================================================
# Path resolution
# ============================================================

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent  # racket/prologos/
DEFAULT_TIMINGS = PROJECT_ROOT / "data" / "benchmarks" / "timings.jsonl"

# ============================================================
# Colors
# ============================================================

GREEN = [0, 180, 0, 255]
RED = [220, 0, 0, 255]
ORANGE = [255, 165, 0, 255]
BLUE = [70, 130, 210, 255]
YELLOW_THRESHOLD = [255, 200, 0, 180]
LIGHT_GRAY = [180, 180, 180, 100]

# ============================================================
# Global state
# ============================================================

runs = []
all_files = []
test_counts = {}
regression_map = {}
timings_file = DEFAULT_TIMINGS
reg_threshold = 10
current_breakdown_idx = -1
last_mtime = 0.0
auto_reload = False
frame_counter = 0
active_process = None
active_process_label = ""
active_process_start = 0.0

# ============================================================
# Data layer
# ============================================================

def load_runs():
    """Read JSONL file, return list of run dicts."""
    if not timings_file.exists():
        return []
    result = []
    with open(timings_file) as f:
        for line in f:
            stripped = line.strip()
            if stripped:
                try:
                    result.append(json.loads(stripped))
                except json.JSONDecodeError:
                    continue
    return result


def derive_all_files(runs_data):
    """Extract sorted list of all unique test filenames across all runs."""
    files = set()
    for run in runs_data:
        for r in run.get("results", []):
            files.add(r["file"])
    return sorted(files)


def detect_regressions(runs_data, threshold_pct):
    """For consecutive run pairs, find files with >threshold% wall_ms increase.

    Returns: {run_index: [{file, prev_ms, curr_ms, delta_pct}]}
    """
    reg = {}
    for i in range(1, len(runs_data)):
        prev_by_file = {r["file"]: r for r in runs_data[i - 1].get("results", [])}
        regs = []
        for r in runs_data[i].get("results", []):
            prev = prev_by_file.get(r["file"])
            if prev and prev["wall_ms"] > 0:
                pct = 100.0 * (r["wall_ms"] - prev["wall_ms"]) / prev["wall_ms"]
                if pct > threshold_pct:
                    regs.append({
                        "file": r["file"],
                        "prev_ms": prev["wall_ms"],
                        "curr_ms": r["wall_ms"],
                        "delta_pct": pct,
                    })
        if regs:
            reg[i] = regs
    return reg


def get_file_trend(runs_data, filename):
    """Extract (xs, ys, statuses) for one file across all runs."""
    xs, ys, statuses = [], [], []
    for i, run in enumerate(runs_data):
        for r in run.get("results", []):
            if r["file"] == filename:
                xs.append(float(i))
                ys.append(r["wall_ms"] / 1000.0)
                statuses.append(r["status"])
                break
    return xs, ys, statuses


def derive_test_counts(runs_data):
    """Extract test count per file from the latest run that includes each file."""
    counts = {}
    for run in reversed(runs_data):
        for r in run.get("results", []):
            if r["file"] not in counts:
                counts[r["file"]] = r.get("tests", 0)
    return counts


def get_commit_label(run, idx):
    """Short label for a run (commit hash or index)."""
    commit = run.get("commit", "")
    return commit[:7] if commit else f"#{idx}"


# ============================================================
# Sample data generator
# ============================================================

SAMPLE_FILES = [
    "test-prelude.rkt", "test-syntax.rkt", "test-parser.rkt",
    "test-elaborator.rkt", "test-typing.rkt", "test-qtt.rkt",
    "test-reduction.rkt", "test-unify.rkt", "test-trait-impl.rkt",
    "test-stdlib.rkt", "test-quote.rkt", "test-introspection.rkt",
    "test-pipe-compose.rkt", "test-numerics.rkt", "test-lang.rkt",
]


def generate_sample_data(target_file, n_runs=20, n_files=None):
    """Write synthetic benchmark JSONL for dashboard testing."""
    if n_files is None:
        n_files = len(SAMPLE_FILES)
    files = SAMPLE_FILES[:n_files]
    # Base times per file (ms)
    base_times = {f: random.randint(500, 25000) for f in files}
    base_tests = {f: random.randint(5, 200) for f in files}

    target_file.parent.mkdir(parents=True, exist_ok=True)
    with open(target_file, "w") as out:
        for run_idx in range(n_runs):
            ts = datetime(2026, 2, 15 + run_idx // 3, 10 + run_idx % 10,
                          random.randint(0, 59), 0, tzinfo=timezone.utc)
            commit = f"{random.randint(0, 0xfffffff):07x}"
            results = []
            for f in files:
                base = base_times[f]
                # Normal jitter +-8%
                jitter = random.uniform(-0.08, 0.08)
                wall_ms = int(base * (1 + jitter))
                # Intentional regression spike at run 12 for test-stdlib.rkt
                if run_idx == 12 and f == "test-stdlib.rkt":
                    wall_ms = int(base * 1.45)
                # Occasional failure
                status = "pass"
                if random.random() < 0.03:
                    status = "fail"
                results.append({
                    "file": f,
                    "wall_ms": wall_ms,
                    "status": status,
                    "tests": base_tests[f],
                })
            total_ms = sum(r["wall_ms"] for r in results)
            all_pass = all(r["status"] == "pass" for r in results)
            record = {
                "timestamp": ts.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "commit": commit,
                "branch": "master",
                "machine": "macosx-aarch64",
                "jobs": 10,
                "total_wall_ms": total_ms,
                "total_tests": sum(r["tests"] for r in results),
                "file_count": len(results),
                "all_pass": all_pass,
                "results": results,
            }
            out.write(json.dumps(record) + "\n")
    print(f"Generated {n_runs} sample runs ({n_files} files each) -> {target_file}")


# ============================================================
# Theme helpers
# ============================================================

def make_scatter_theme(color):
    with dpg.theme() as theme:
        with dpg.theme_component(dpg.mvScatterSeries):
            dpg.add_theme_color(dpg.mvPlotCol_MarkerFill, color,
                                category=dpg.mvThemeCat_Plots)
            dpg.add_theme_color(dpg.mvPlotCol_MarkerOutline, color,
                                category=dpg.mvThemeCat_Plots)
    return theme


def make_line_theme(color):
    with dpg.theme() as theme:
        with dpg.theme_component(dpg.mvLineSeries):
            dpg.add_theme_color(dpg.mvPlotCol_Line, color,
                                category=dpg.mvThemeCat_Plots)
    return theme


def make_bar_theme(color):
    with dpg.theme() as theme:
        with dpg.theme_component(dpg.mvBarSeries):
            dpg.add_theme_color(dpg.mvPlotCol_Fill, color,
                                category=dpg.mvThemeCat_Plots)
    return theme


# ============================================================
# Chart builders
# ============================================================

def build_suite_overview():
    """Tab 1: Total wall time per run with regression annotations."""
    if not runs:
        dpg.add_text("No benchmark data. Run benchmark-tests.rkt or --generate-sample.",
                      parent="tab_suite")
        return

    xs = list(range(len(runs)))
    ys = [r["total_wall_ms"] / 1000.0 for r in runs]

    # Split by pass/fail
    pass_xs = [i for i, r in enumerate(runs) if r.get("all_pass", True)]
    pass_ys = [runs[i]["total_wall_ms"] / 1000.0 for i in pass_xs]
    fail_xs = [i for i, r in enumerate(runs) if not r.get("all_pass", True)]
    fail_ys = [runs[i]["total_wall_ms"] / 1000.0 for i in fail_xs]

    with dpg.group(parent="tab_suite"):
        # Slider for "show last N runs"
        dpg.add_slider_int(label="Show last N runs", min_value=3,
                           max_value=max(len(runs), 3),
                           default_value=min(50, len(runs)),
                           callback=_on_suite_slider, tag="suite_slider",
                           width=300)

        with dpg.plot(label="Total Suite Wall Time", height=-1, width=-1,
                      tag="suite_plot", crosshairs=True):
            dpg.add_plot_legend()
            sx = dpg.add_plot_axis(dpg.mvXAxis, label="Run", tag="suite_xaxis")
            sy = dpg.add_plot_axis(dpg.mvYAxis, label="Wall Time (s)", tag="suite_yaxis")

            # Line series
            line = dpg.add_line_series([float(x) for x in xs],
                                       ys, label="Total Time",
                                       parent=sy, tag="suite_line")
            dpg.bind_item_theme(line, make_line_theme(BLUE))

            # Pass scatter
            if pass_xs:
                ps = dpg.add_scatter_series([float(x) for x in pass_xs],
                                            pass_ys, label="All Pass",
                                            parent=sy, tag="suite_pass")
                dpg.bind_item_theme(ps, make_scatter_theme(GREEN))

            # Fail scatter
            if fail_xs:
                fs = dpg.add_scatter_series([float(x) for x in fail_xs],
                                            fail_ys, label="Has Failures",
                                            parent=sy, tag="suite_fail")
                dpg.bind_item_theme(fs, make_scatter_theme(RED))

            # Regression annotations
            for idx, regs in regression_map.items():
                worst = max(regs, key=lambda r: r["delta_pct"])
                dpg.add_plot_annotation(
                    label=f"+{worst['delta_pct']:.0f}%",
                    default_value=(float(idx), runs[idx]["total_wall_ms"] / 1000.0),
                    color=RED, offset=(0, -20), parent="suite_plot")

            # X-axis tick labels with commit hashes
            _set_suite_xticks(xs)


def _set_suite_xticks(xs):
    """Set x-axis ticks to commit hashes, showing every Nth for readability."""
    if not runs:
        return
    n = max(1, len(runs) // 15)
    ticks = []
    for i in xs:
        if i % n == 0 or i == len(runs) - 1:
            ticks.append((get_commit_label(runs[i], i), float(i)))
    if ticks:
        dpg.set_axis_ticks("suite_xaxis", tuple(ticks))


def _on_suite_slider(sender, app_data):
    """Filter suite overview to show last N runs."""
    n = app_data
    start = max(0, len(runs) - n)
    xs = list(range(start, len(runs)))
    ys = [runs[i]["total_wall_ms"] / 1000.0 for i in xs]
    dpg.set_value("suite_line", [[float(x) for x in xs], ys])
    dpg.fit_axis_data("suite_xaxis")
    dpg.fit_axis_data("suite_yaxis")


def _file_label(filename):
    """Format file name with test count for display."""
    count = test_counts.get(filename, 0)
    return f"{filename} ({count})" if count else filename


def _file_from_label(label):
    """Extract filename from a display label like 'test-foo.rkt (42)'."""
    idx = label.rfind(" (")
    return label[:idx] if idx > 0 and label.endswith(")") else label


def build_file_trend_tab():
    """Tab 2: Per-file trend with file selector."""
    with dpg.group(horizontal=True, parent="tab_trend"):
        # Left panel: filter + listbox
        with dpg.child_window(width=270, tag="trend_left_panel"):
            dpg.add_input_text(label="Filter", callback=_on_filter_files,
                               tag="file_filter", width=200)
            items = [_file_label(f) for f in all_files] if all_files else ["(no data)"]
            dpg.add_listbox(items=items, num_items=30,
                            callback=_on_file_selected,
                            tag="file_selector", width=250)

        # Right panel: plot
        with dpg.child_window(tag="trend_right_panel"):
            if not runs:
                dpg.add_text("No benchmark data available.")
                return
            with dpg.plot(label="Per-File Trend", height=-1, width=-1,
                          tag="trend_plot", crosshairs=True):
                dpg.add_plot_legend()
                dpg.add_plot_axis(dpg.mvXAxis, label="Run #", tag="trend_xaxis")
                ty = dpg.add_plot_axis(dpg.mvYAxis, label="Wall Time (s)",
                                        tag="trend_yaxis")
                # Line series (empty initially)
                line = dpg.add_line_series([], [], label="File Time",
                                           parent=ty, tag="trend_line")
                dpg.bind_item_theme(line, make_line_theme(BLUE))
                # Threshold line
                thresh = dpg.add_line_series([], [], label="Threshold (+10%)",
                                              parent=ty, tag="trend_threshold")
                dpg.bind_item_theme(thresh, make_line_theme(YELLOW_THRESHOLD))
                # Regression scatter
                reg_s = dpg.add_scatter_series([], [], label="Regression",
                                                parent=ty, tag="trend_reg_scatter")
                dpg.bind_item_theme(reg_s, make_scatter_theme(RED))


def _on_filter_files(sender, app_data):
    """Filter file listbox by substring."""
    query = app_data.lower()
    filtered = [_file_label(f) for f in all_files if query in f.lower()]
    dpg.configure_item("file_selector", items=filtered if filtered else ["(no match)"])


def _on_file_selected(sender, app_data):
    """Update per-file trend chart when a file is selected."""
    selected = _file_from_label(app_data)
    if selected.startswith("("):
        return  # placeholder

    xs, ys, statuses = get_file_trend(runs, selected)
    if not xs:
        return

    dpg.set_value("trend_line", [xs, ys])
    dpg.configure_item("trend_plot", label=f"Trend: {selected}")

    # Threshold line at mean * (1 + threshold%)
    if ys:
        mean_val = sum(ys) / len(ys)
        thresh_val = mean_val * (1 + reg_threshold / 100.0)
        dpg.set_value("trend_threshold", [[xs[0], xs[-1]], [thresh_val, thresh_val]])

    # Regression scatter: red dots where this file regressed
    reg_xs, reg_ys = [], []
    for idx, regs in regression_map.items():
        for reg in regs:
            if reg["file"] == selected:
                # Find this file's y-value at run idx
                for j, x in enumerate(xs):
                    if int(x) == idx:
                        reg_xs.append(xs[j])
                        reg_ys.append(ys[j])
                        break
    dpg.set_value("trend_reg_scatter", [reg_xs, reg_ys])

    dpg.fit_axis_data("trend_xaxis")
    dpg.fit_axis_data("trend_yaxis")


def build_run_breakdown():
    """Tab 3: Horizontal bar chart with navigation through all runs."""
    if not runs:
        dpg.add_text("No benchmark data available.", parent="tab_latest")
        return

    run = runs[current_breakdown_idx]
    results = sorted(run.get("results", []), key=lambda r: r["wall_ms"])
    files = [r["file"] for r in results]
    times = [r["wall_ms"] / 1000.0 for r in results]
    statuses = [r["status"] for r in results]

    commit = get_commit_label(run, current_breakdown_idx)
    ts = run.get("timestamp", "")[:10]

    plot_height = max(500, len(results) * 22)

    with dpg.group(parent="tab_latest"):
        # Navigation controls
        with dpg.group(horizontal=True):
            dpg.add_button(label="<", callback=_on_breakdown_prev,
                           tag="breakdown_prev",
                           enabled=current_breakdown_idx > 0)
            dpg.add_text(
                f"Run {current_breakdown_idx + 1}/{len(runs)}: "
                f"{commit} ({ts}) — {len(results)} files",
                tag="breakdown_label")
            dpg.add_button(label=">", callback=_on_breakdown_next,
                           tag="breakdown_next",
                           enabled=current_breakdown_idx < len(runs) - 1)

        with dpg.plot(label="Per-File Timing", height=plot_height, width=-1,
                      tag="latest_plot", crosshairs=True):
            dpg.add_plot_legend()
            lx = dpg.add_plot_axis(dpg.mvXAxis, label="Wall Time (s)",
                                    tag="latest_xaxis")
            ly = dpg.add_plot_axis(dpg.mvYAxis, label="", tag="latest_yaxis")

            # Y-axis ticks = file names with test counts
            ticks = tuple(
                (f"{f} ({r.get('tests', '')})", float(i))
                for i, (f, r) in enumerate(zip(files, results))
            )
            dpg.set_axis_ticks(ly, ticks)

            # Group by status for color-coded bar series
            for status, color, label in [
                ("pass", GREEN, "Pass"),
                ("fail", RED, "Fail"),
                ("timeout", ORANGE, "Timeout"),
            ]:
                idxs = [i for i, s in enumerate(statuses) if s == status]
                if idxs:
                    bar_x = [times[i] for i in idxs]
                    bar_y = [float(i) for i in idxs]
                    series = dpg.add_bar_series(bar_x, bar_y, label=label,
                                                parent=ly, horizontal=True,
                                                tag=f"latest_bar_{status}")
                    dpg.bind_item_theme(series, make_bar_theme(color))


def _on_breakdown_prev(sender=None, app_data=None):
    """Navigate to previous run in breakdown tab."""
    global current_breakdown_idx
    if current_breakdown_idx > 0:
        current_breakdown_idx -= 1
        _rebuild_breakdown_tab()


def _on_breakdown_next(sender=None, app_data=None):
    """Navigate to next run in breakdown tab."""
    global current_breakdown_idx
    if current_breakdown_idx < len(runs) - 1:
        current_breakdown_idx += 1
        _rebuild_breakdown_tab()


def _rebuild_breakdown_tab():
    """Clear and rebuild only the breakdown tab."""
    children = dpg.get_item_children("tab_latest", 1)
    if children:
        for child in children:
            dpg.delete_item(child)
    build_run_breakdown()


# ============================================================
# Reload
# ============================================================

def reload_data():
    """Reload JSONL data and recompute derived state."""
    global runs, all_files, test_counts, regression_map, current_breakdown_idx
    global last_mtime
    runs = load_runs()
    all_files = derive_all_files(runs)
    test_counts = derive_test_counts(runs)
    regression_map = detect_regressions(runs, reg_threshold)
    if current_breakdown_idx < 0 or current_breakdown_idx >= len(runs):
        current_breakdown_idx = max(0, len(runs) - 1)
    try:
        last_mtime = os.path.getmtime(timings_file)
    except FileNotFoundError:
        last_mtime = 0.0


def rebuild_ui():
    """Clear and rebuild all chart content."""
    # Clear tab contents
    for tag in ["tab_suite", "tab_trend", "tab_latest"]:
        children = dpg.get_item_children(tag, 1)
        if children:
            for child in children:
                dpg.delete_item(child)

    build_suite_overview()
    build_file_trend_tab()
    build_run_breakdown()
    update_status_text()


def on_reload(sender=None, app_data=None):
    """Callback for reload button."""
    reload_data()
    rebuild_ui()


def update_status_text():
    """Update the status bar text."""
    if not runs:
        text = (f"No benchmark data found. "
                f"Run: racket tools/benchmark-tests.rkt "
                f"or: python {Path(__file__).name} --generate-sample")
    else:
        last = runs[-1]
        commit = last.get("commit", "?")[:7]
        ts = last.get("timestamp", "")[:10]
        n_files = last.get("file_count", 0)
        n_tests = last.get("total_tests", 0)
        n_regs = sum(len(v) for v in regression_map.values())
        text = (f"{len(runs)} runs loaded | Last: {commit} ({ts}) | "
                f"{n_files} files, {n_tests} tests")
        if n_regs:
            text += f" | {n_regs} regressions detected"
    dpg.set_value("status_text", text)


# ============================================================
# Subprocess controls
# ============================================================

def _start_process(mode):
    """Launch a benchmark or test subprocess."""
    global active_process, active_process_label, active_process_start
    if active_process is not None:
        return  # already running

    jobs = dpg.get_value("jobs_input")
    timeout = dpg.get_value("timeout_input")

    if mode == "benchmark":
        cmd = ["racket", str(SCRIPT_DIR / "benchmark-tests.rkt"),
               "--jobs", str(jobs), "--timeout", str(timeout)]
        active_process_label = "Full Benchmark"
    else:
        cmd = ["racket", str(SCRIPT_DIR / "run-affected-tests.rkt"),
               "--all", "--jobs", str(jobs), "--timeout", str(timeout)]
        active_process_label = "Affected Tests"

    active_process = subprocess.Popen(
        cmd, cwd=str(PROJECT_ROOT),
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    active_process_start = time.time()

    dpg.configure_item("btn_benchmark", enabled=False)
    dpg.configure_item("btn_affected", enabled=False)
    dpg.configure_item("btn_cancel", show=True)
    dpg.set_value("process_status", f"Running {active_process_label}...")


def _on_run_benchmark(sender=None, app_data=None):
    _start_process("benchmark")


def _on_run_affected(sender=None, app_data=None):
    _start_process("affected")


def _on_cancel_process(sender=None, app_data=None):
    """Terminate running subprocess."""
    global active_process
    if active_process is not None:
        active_process.terminate()
        active_process = None
        _reset_process_ui("Cancelled.")


def _reset_process_ui(msg):
    """Re-enable run buttons and update status."""
    dpg.configure_item("btn_benchmark", enabled=True)
    dpg.configure_item("btn_affected", enabled=True)
    dpg.configure_item("btn_cancel", show=False)
    dpg.set_value("process_status", msg)


def _poll_active_process():
    """Check if subprocess completed; auto-reload on finish."""
    global active_process
    if active_process is None:
        return
    retcode = active_process.poll()
    if retcode is not None:
        elapsed = time.time() - active_process_start
        if retcode == 0:
            msg = f"{active_process_label} completed in {elapsed:.1f}s"
        else:
            msg = f"{active_process_label} failed (exit {retcode}) after {elapsed:.1f}s"
        active_process = None
        _reset_process_ui(msg)
        on_reload()
    else:
        elapsed = time.time() - active_process_start
        dpg.set_value("process_status",
                      f"Running {active_process_label}... ({elapsed:.0f}s)")


# ============================================================
# Main
# ============================================================

def main():
    global timings_file, reg_threshold, auto_reload, frame_counter

    parser = argparse.ArgumentParser(
        description="Prologos Benchmark Dashboard (DearPyGui)")
    parser.add_argument("--file", type=Path, default=DEFAULT_TIMINGS,
                        help="Path to timings.jsonl")
    parser.add_argument("--threshold", type=int, default=10,
                        help="Regression threshold %% (default: 10)")
    parser.add_argument("--generate-sample", action="store_true",
                        help="Write synthetic JSONL data for testing")
    args = parser.parse_args()

    timings_file = args.file
    reg_threshold = args.threshold

    if args.generate_sample:
        generate_sample_data(timings_file)
        print("Sample data generated. Run again without --generate-sample to view.")
        return

    # Load initial data
    reload_data()

    # Initialize DearPyGui
    dpg.create_context()
    dpg.create_viewport(title="Prologos Benchmark Dashboard",
                         width=1400, height=900)

    with dpg.window(tag="main_window"):
        # Header bar
        with dpg.group(horizontal=True):
            dpg.add_text("Prologos Benchmark Dashboard", color=BLUE)
            dpg.add_spacer(width=30)
            dpg.add_button(label="Reload", callback=on_reload)
            dpg.add_checkbox(label="Auto-reload",
                             callback=lambda s, a: _toggle_auto_reload(a),
                             tag="auto_reload_cb")

        # Status text
        dpg.add_text("Loading...", tag="status_text")
        dpg.add_separator()

        # Run Tests controls (collapsible)
        with dpg.collapsing_header(label="Run Tests", default_open=False):
            with dpg.group(horizontal=True):
                dpg.add_text("Jobs:")
                dpg.add_input_int(tag="jobs_input", default_value=10,
                                  width=80, min_value=1, max_value=20,
                                  min_clamped=True, max_clamped=True)
                dpg.add_spacer(width=10)
                dpg.add_text("Timeout (s):")
                dpg.add_input_int(tag="timeout_input", default_value=600,
                                  width=80, min_value=10, min_clamped=True)
            with dpg.group(horizontal=True):
                dpg.add_button(label="Run Full Benchmark",
                               callback=_on_run_benchmark,
                               tag="btn_benchmark")
                dpg.add_button(label="Run Affected Tests",
                               callback=_on_run_affected,
                               tag="btn_affected")
                dpg.add_button(label="Cancel",
                               callback=_on_cancel_process,
                               tag="btn_cancel", show=False)
            dpg.add_text("", tag="process_status")

        # Tab bar
        with dpg.tab_bar():
            with dpg.tab(label="Suite Overview", tag="tab_suite"):
                pass
            with dpg.tab(label="Per-File Trend", tag="tab_trend"):
                pass
            with dpg.tab(label="Run Breakdown", tag="tab_latest"):
                pass

    # Build chart content
    build_suite_overview()
    build_file_trend_tab()
    build_run_breakdown()
    update_status_text()

    dpg.set_primary_window("main_window", True)
    dpg.setup_dearpygui()
    dpg.show_viewport()

    # Custom render loop with auto-reload polling and subprocess management
    while dpg.is_dearpygui_running():
        frame_counter += 1
        if auto_reload and frame_counter % 60 == 0:
            try:
                current_mtime = os.path.getmtime(timings_file)
                if current_mtime != last_mtime:
                    on_reload()
            except FileNotFoundError:
                pass
        if frame_counter % 10 == 0:
            _poll_active_process()
        dpg.render_dearpygui_frame()

    dpg.destroy_context()


def _toggle_auto_reload(value):
    global auto_reload
    auto_reload = value


if __name__ == "__main__":
    main()
