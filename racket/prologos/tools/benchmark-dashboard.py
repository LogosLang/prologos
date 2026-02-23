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
suite_run_indices = []
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


def parse_error_output(error_text):
    """Parse raco test error output into structured failures.

    raco test stderr uses '--------------------' separators between test failures.
    Each block starts with the test name, then FAILURE, then key: value lines.
    The final block is a summary like '1/2 test failures'.
    """
    if not error_text:
        return []
    failures = []
    blocks = error_text.split("--------------------")
    for block in blocks:
        block = block.strip()
        if not block:
            continue
        # Skip summary lines like "1/2 test failures"
        if "test failure" in block.lower():
            continue
        lines = block.split("\n")
        if not lines:
            continue
        name = lines[0].strip()
        details = "\n".join(lines[1:]).strip()
        failures.append({"name": name, "details": details})
    return failures


def get_run_errors(run):
    """Extract all error outputs from a run's results.

    Returns list of {file, tests, error_output, failures} dicts for
    failed/timed-out results that have error_output.
    """
    errors = []
    for r in run.get("results", []):
        if r.get("status") in ("fail", "timeout") and r.get("error_output"):
            failures = parse_error_output(r["error_output"])
            errors.append({
                "file": r["file"],
                "tests": r.get("tests", 0),
                "status": r["status"],
                "error_output": r["error_output"],
                "failures": failures,
            })
    return errors


# ============================================================
# Sample data generator
# ============================================================

SAMPLE_FILES = [
    "test-prelude.rkt", "test-syntax.rkt", "test-parser.rkt",
    "test-elaborator.rkt", "test-typing.rkt", "test-qtt.rkt",
    "test-reduction.rkt", "test-unify.rkt", "test-trait-impl.rkt",
    "test-stdlib-01-data.rkt", "test-stdlib-02-traits.rkt",
    "test-stdlib-03-list.rkt", "test-quote.rkt", "test-introspection.rkt",
    "test-pipe-compose.rkt", "test-numerics.rkt", "test-lang-01-sexp.rkt",
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
                # Intentional regression spike at run 12 for test-stdlib-01-data.rkt
                if run_idx == 12 and f == "test-stdlib-01-data.rkt":
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
    """Tab 1: Total wall time per full-suite run with regression annotations."""
    if not suite_run_indices:
        dpg.add_text("No full-suite benchmark data. Run benchmark-tests.rkt or --generate-sample.",
                      parent="tab_suite")
        return

    n_suite = len(suite_run_indices)
    xs = list(range(n_suite))
    ys = [runs[ri]["total_wall_ms"] / 1000.0 for ri in suite_run_indices]

    # Split by pass/fail (using sequential suite indices)
    pass_xs = [si for si, ri in enumerate(suite_run_indices)
               if runs[ri].get("all_pass", True)]
    pass_ys = [runs[suite_run_indices[si]]["total_wall_ms"] / 1000.0
               for si in pass_xs]
    fail_xs = [si for si, ri in enumerate(suite_run_indices)
               if not runs[ri].get("all_pass", True)]
    fail_ys = [runs[suite_run_indices[si]]["total_wall_ms"] / 1000.0
               for si in fail_xs]

    with dpg.group(parent="tab_suite"):
        # Slider for "show last N runs"
        dpg.add_slider_int(label="Show last N runs", min_value=3,
                           max_value=max(n_suite, 3),
                           default_value=min(50, n_suite),
                           callback=_on_suite_slider, tag="suite_slider",
                           width=300)

        with dpg.plot(label="Total Suite Wall Time (full-suite runs only)",
                      height=-1, width=-1,
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

            # Regression annotations (only for suite runs)
            suite_set = set(suite_run_indices)
            for idx, regs in regression_map.items():
                if idx in suite_set:
                    si = suite_run_indices.index(idx)
                    worst = max(regs, key=lambda r: r["delta_pct"])
                    dpg.add_plot_annotation(
                        label=f"+{worst['delta_pct']:.0f}%",
                        default_value=(float(si), runs[idx]["total_wall_ms"] / 1000.0),
                        color=RED, offset=(0, -20), parent="suite_plot")

            # X-axis tick labels with commit hashes
            _set_suite_xticks(xs)


def _format_short_datetime(iso_ts):
    """Format ISO 8601 timestamp to 'MM-DD HH:MM' for tick labels."""
    if not iso_ts:
        return ""
    try:
        dt = datetime.fromisoformat(iso_ts.replace("Z", "+00:00"))
        return dt.strftime("%m-%d %H:%M")
    except (ValueError, AttributeError):
        return ""


def _set_suite_xticks(xs):
    """Set x-axis ticks to datetime + commit hashes for full-suite runs."""
    if not suite_run_indices:
        return
    n = max(1, len(suite_run_indices) // 15)
    ticks = []
    for si in xs:
        ri = suite_run_indices[si]
        if si % n == 0 or si == len(suite_run_indices) - 1:
            commit = get_commit_label(runs[ri], ri)
            date_str = _format_short_datetime(runs[ri].get("timestamp", ""))
            fc = runs[ri].get("file_count", 0)
            if date_str:
                label = f"{date_str}\n{commit} ({fc}f)"
            else:
                label = f"{commit} ({fc}f)"
            ticks.append((label, float(si)))
    if ticks:
        dpg.set_axis_ticks("suite_xaxis", tuple(ticks))


def _on_suite_slider(sender, app_data):
    """Filter suite overview to show last N full-suite runs."""
    n = app_data
    n_suite = len(suite_run_indices)
    start = max(0, n_suite - n)
    xs = list(range(start, n_suite))
    ys = [runs[suite_run_indices[si]]["total_wall_ms"] / 1000.0 for si in xs]
    dpg.set_value("suite_line", [[float(x) for x in xs], ys])
    # Update pass/fail scatter to match visible range
    pass_xs = [si for si in xs if runs[suite_run_indices[si]].get("all_pass", True)]
    pass_ys = [runs[suite_run_indices[si]]["total_wall_ms"] / 1000.0 for si in pass_xs]
    fail_xs = [si for si in xs if not runs[suite_run_indices[si]].get("all_pass", True)]
    fail_ys = [runs[suite_run_indices[si]]["total_wall_ms"] / 1000.0 for si in fail_xs]
    if dpg.does_item_exist("suite_pass"):
        dpg.set_value("suite_pass", [[float(x) for x in pass_xs], pass_ys])
    if dpg.does_item_exist("suite_fail"):
        dpg.set_value("suite_fail", [[float(x) for x in fail_xs], fail_ys])
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
    total_tests = run.get("total_tests",
                          sum(r.get("tests", 0) for r in results))

    has_errors = any(
        r.get("error_output")
        for r in results
        if r.get("status") in ("fail", "timeout")
    )

    max_time = max(times) * 1.1 if times else 60.0
    n_files = len(results)
    plot_height = max(500, n_files * 22)

    with dpg.group(parent="tab_latest"):
        # ---- Centered navigation controls (table layout) ----
        with dpg.table(header_row=False, borders_innerH=False,
                       borders_outerH=False, borders_innerV=False,
                       borders_outerV=False):
            dpg.add_table_column(width_stretch=True, init_width_or_weight=1.0)
            dpg.add_table_column(width_fixed=True)
            dpg.add_table_column(width_stretch=True, init_width_or_weight=1.0)
            with dpg.table_row():
                dpg.add_spacer()
                with dpg.group(horizontal=True):
                    dpg.add_button(label="<", callback=_on_breakdown_prev,
                                   tag="breakdown_prev",
                                   enabled=current_breakdown_idx > 0)
                    dpg.add_text(
                        f"  Run {current_breakdown_idx + 1}/{len(runs)}  ",
                        tag="breakdown_run_label")
                    dpg.add_button(label=">", callback=_on_breakdown_next,
                                   tag="breakdown_next",
                                   enabled=current_breakdown_idx < len(runs) - 1)
                    dpg.add_spacer(width=20)
                    dpg.add_button(label="Errors", callback=_on_toggle_errors,
                                   tag="breakdown_errors_btn",
                                   enabled=has_errors)
                dpg.add_spacer()

        # Metadata line
        dpg.add_text(
            f"{commit} ({ts}) — {n_files} files, {total_tests} tests",
            tag="breakdown_label", color=LIGHT_GRAY)

        # Error log panel (hidden by default, toggled by Errors button)
        with dpg.child_window(tag="error_log_panel", height=0, show=False,
                               border=True):
            pass  # content built dynamically by _on_toggle_errors

        # ---- Fixed ruler at top (stays visible while scrolling bars) ----
        dpg.add_text("Per-File Timing", color=BLUE)
        with dpg.plot(height=45, width=-1, tag="ruler_plot",
                      no_title=True, no_mouse_pos=True):
            rx = dpg.add_plot_axis(dpg.mvXAxis, label="seconds",
                                    tag="ruler_xaxis")
            ry = dpg.add_plot_axis(dpg.mvYAxis, label="",
                                    tag="ruler_yaxis",
                                    no_tick_marks=True,
                                    no_tick_labels=True,
                                    no_gridlines=True)
            dpg.set_axis_limits("ruler_xaxis", 0, max_time)
            dpg.set_axis_limits("ruler_yaxis", 0, 1)

        # ---- Scrollable bar chart (ruler stays fixed above) ----
        with dpg.child_window(height=-1, horizontal_scrollbar=False):
            with dpg.plot(height=plot_height, width=-1,
                          tag="latest_plot", crosshairs=True,
                          no_title=True):
                dpg.add_plot_legend()
                lx = dpg.add_plot_axis(dpg.mvXAxis, label="Wall Time (s)",
                                        tag="latest_xaxis")
                ly = dpg.add_plot_axis(dpg.mvYAxis, label="",
                                        tag="latest_yaxis")

                # Glue x-axis to 0 and match ruler scale
                dpg.set_axis_limits(lx, 0, max_time)

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
    global error_log_visible
    error_log_visible = False
    children = dpg.get_item_children("tab_latest", 1)
    if children:
        for child in children:
            dpg.delete_item(child)
    build_run_breakdown()


error_log_visible = False


def _on_toggle_errors(sender=None, app_data=None):
    """Toggle the error log panel visibility and populate it."""
    global error_log_visible
    if not dpg.does_item_exist("error_log_panel"):
        return

    error_log_visible = not error_log_visible

    if error_log_visible:
        # Populate error content
        _build_error_log_content()
        dpg.configure_item("error_log_panel", show=True, height=300)
        dpg.configure_item("breakdown_errors_btn", label="Hide Errors")
    else:
        dpg.configure_item("error_log_panel", show=False, height=0)
        dpg.configure_item("breakdown_errors_btn", label="Errors")


def _build_error_log_content():
    """Build the error log tree view inside error_log_panel."""
    # Clear existing content
    children = dpg.get_item_children("error_log_panel", 1)
    if children:
        for child in children:
            dpg.delete_item(child)

    run = runs[current_breakdown_idx]
    errors = get_run_errors(run)

    if not errors:
        dpg.add_text("No error details available for this run.",
                      parent="error_log_panel", color=LIGHT_GRAY)
        return

    total_failures = sum(len(e["failures"]) for e in errors)
    dpg.add_text(
        f"{len(errors)} failed file(s), {total_failures} failure(s)",
        parent="error_log_panel", color=RED)
    dpg.add_separator(parent="error_log_panel")

    for err in errors:
        file_label = err["file"]
        n_failures = len(err["failures"])
        status_tag = "FAIL" if err["status"] == "fail" else "TIMEOUT"

        with dpg.tree_node(
            label=f"{file_label} [{status_tag}] ({n_failures} failure(s))",
            parent="error_log_panel",
            default_open=len(errors) == 1,
        ):
            if err["failures"]:
                for failure in err["failures"]:
                    with dpg.tree_node(label=failure["name"],
                                        default_open=False):
                        if failure["details"]:
                            # Show details as monospace-style text
                            for detail_line in failure["details"].split("\n"):
                                dpg.add_text(detail_line, color=LIGHT_GRAY,
                                              bullet=False)
                        else:
                            dpg.add_text("(no details)", color=LIGHT_GRAY)
            else:
                # No parsed failures — show raw error output
                dpg.add_text("Raw error output:", color=ORANGE)
                raw_lines = err["error_output"].split("\n")
                for line in raw_lines[:50]:  # cap at 50 lines
                    dpg.add_text(line, color=LIGHT_GRAY)
                if len(raw_lines) > 50:
                    dpg.add_text(f"... ({len(raw_lines) - 50} more lines)",
                                  color=LIGHT_GRAY)


# ============================================================
# Reload
# ============================================================

def reload_data():
    """Reload JSONL data and recompute derived state."""
    global runs, all_files, test_counts, regression_map, suite_run_indices
    global current_breakdown_idx, last_mtime
    runs = load_runs()
    all_files = derive_all_files(runs)
    test_counts = derive_test_counts(runs)
    regression_map = detect_regressions(runs, reg_threshold)
    # Identify full-suite runs: any run with >=50% of max file_count.
    # This captures historical full-suite runs even as the suite grows
    # (e.g. 91 files -> 137 -> 144), while excluding small affected-tests runs.
    if runs:
        max_fc = max(r.get("file_count", 0) for r in runs)
        suite_threshold = max(1, int(max_fc * 0.5))
        suite_run_indices = [i for i, r in enumerate(runs)
                            if r.get("file_count", 0) >= suite_threshold]
    else:
        suite_run_indices = []
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
        text = (f"{len(suite_run_indices)}/{len(runs)} full-suite runs | "
                f"Last: {commit} ({ts}) | "
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
            _update_crosshair_annotations()
        dpg.render_dearpygui_frame()

    dpg.destroy_context()


# Annotation tags for crosshair value display (one per plot)
_CROSSHAIR_TAGS = {
    "suite_plot": "suite_crosshair_ann",
    "trend_plot": "trend_crosshair_ann",
    "latest_plot": "latest_crosshair_ann",
}


def _update_crosshair_annotations():
    """Show value annotation at crosshair position on hovered plots."""
    for plot_tag, ann_tag in _CROSSHAIR_TAGS.items():
        try:
            # Clean up previous annotation
            if dpg.does_item_exist(ann_tag):
                dpg.delete_item(ann_tag)

            if not dpg.does_item_exist(plot_tag):
                continue
            if not dpg.is_item_hovered(plot_tag):
                continue

            mx, my = dpg.get_plot_mouse_pos()

            # Run Breakdown: horizontal bars, x = time
            # Suite Overview / Per-File Trend: y = time
            if plot_tag == "latest_plot":
                label = f"{mx:.1f}s"
            else:
                label = f"{my:.1f}s"

            dpg.add_plot_annotation(
                label=label,
                default_value=(mx, my),
                color=LIGHT_GRAY,
                offset=(10, -15),
                parent=plot_tag,
                tag=ann_tag,
            )
        except Exception:
            pass


def _toggle_auto_reload(value):
    global auto_reload
    auto_reload = value


if __name__ == "__main__":
    main()
