#!/usr/bin/env python3
"""
Convert test files to use the shared prelude from test-support.rkt.

Instead of each test file starting fresh with (current-module-registry (hasheq))
and reloading the entire prelude (~3s per call), this script rewrites them to use
the cached prelude registries from test-support.rkt.

The conversion replaces:
  [current-module-registry (hasheq)]
    -> [current-module-registry prelude-module-registry]

  [current-trait-registry (current-trait-registry)]
    -> [current-trait-registry prelude-trait-registry]

  [current-impl-registry (current-impl-registry)]
    -> [current-impl-registry prelude-impl-registry]

  [current-param-impl-registry (current-param-impl-registry)]
    -> [current-param-impl-registry prelude-param-impl-registry]

  [current-preparse-registry (current-preparse-registry)]
    -> [current-preparse-registry prelude-preparse-registry]

  [current-lib-paths (list lib-dir)]
    -> [current-lib-paths (list prelude-lib-dir)]

And adds "test-support.rkt" to the require form, removes the here/lib-dir
definitions, and removes require lines that are now provided by test-support.rkt.

Usage:
    python3 tools/convert-test-support.py --dry-run     # preview changes
    python3 tools/convert-test-support.py --apply        # modify files in place
"""

import argparse
import os
import re
import sys
from pathlib import Path


# Files that already use the shared-module-reg pattern (hand-optimized).
# These should NOT be touched.
SKIP_SHARED_MODULE_REG = {
    "test-char-string.rkt",
    "test-dot-access.rkt",
    "test-implicit-map.rkt",
    "test-mixfix.rkt",
    "test-pipe-compose-e2e.rkt",
    "test-string-ops.rkt",
}

# test-support.rkt itself -- never modify.
SKIP_SELF = {"test-support.rkt"}

# All files to skip.
SKIP_FILES = SKIP_SHARED_MODULE_REG | SKIP_SELF


def find_test_files(tests_dir: Path) -> list[Path]:
    """Return all .rkt files in tests/ that are candidates for conversion."""
    return sorted(
        p for p in tests_dir.glob("test-*.rkt")
        if p.name not in SKIP_FILES
    )


def file_uses_module_loader(content: str) -> bool:
    """Check if the file uses install-module-loader! (namespace-aware tests)."""
    return "install-module-loader!" in content


def file_has_fresh_registry(content: str) -> bool:
    """Check if the file has (current-module-registry (hasheq)) -- the pattern we convert."""
    return "[current-module-registry (hasheq)]" in content


def file_already_uses_test_support(content: str) -> bool:
    """Check if the file already requires test-support.rkt."""
    return '"test-support.rkt"' in content


# --------------------------------------------------------------------------
# Registry replacement patterns
# --------------------------------------------------------------------------

# The core replacement: fresh hasheq -> cached prelude registry
REGISTRY_REPLACEMENTS = [
    # Module registry: fresh -> prelude
    (
        "[current-module-registry (hasheq)]",
        "[current-module-registry prelude-module-registry]",
    ),
    # Trait registry: self-ref -> prelude
    (
        "[current-trait-registry (current-trait-registry)]",
        "[current-trait-registry prelude-trait-registry]",
    ),
    # Impl registry: self-ref -> prelude
    (
        "[current-impl-registry (current-impl-registry)]",
        "[current-impl-registry prelude-impl-registry]",
    ),
    # Param-impl registry: self-ref -> prelude
    (
        "[current-param-impl-registry (current-param-impl-registry)]",
        "[current-param-impl-registry prelude-param-impl-registry]",
    ),
    # Preparse registry: self-ref -> prelude
    (
        "[current-preparse-registry (current-preparse-registry)]",
        "[current-preparse-registry prelude-preparse-registry]",
    ),
    # Lib paths: local lib-dir -> prelude-lib-dir
    (
        "[current-lib-paths (list lib-dir)]",
        "[current-lib-paths (list prelude-lib-dir)]",
    ),
]

# Additional registries that some files parameterize with self-ref.
# These are NOT covered by test-support.rkt prelude cache, so they stay
# as self-refs. We do NOT replace them. Listed here for documentation:
#   [current-bundle-registry (current-bundle-registry)]
#   [current-spec-store (hasheq)]
#   [current-ctor-registry (current-ctor-registry)]
#   [current-type-meta (current-type-meta)]
#   [current-specialization-registry (current-specialization-registry)]


def add_test_support_require(content: str) -> str:
    """Add "test-support.rkt" to the require form.

    Strategy: find the require block and add "test-support.rkt" to it.
    We look for the first (require ... ) form and insert after the opening.
    """
    if '"test-support.rkt"' in content:
        return content  # already present

    # Pattern: find `(require` at the start of a line (with optional whitespace)
    # and insert "test-support.rkt" as the first require after rackunit/racket/*
    # We'll add it right before the first "../..." require or at end of require block.
    #
    # Strategy: find the first line that starts a require block, then find the
    # first "../" require line and insert "test-support.rkt" before it.

    lines = content.split("\n")
    in_require = False
    insert_idx = None

    for i, line in enumerate(lines):
        stripped = line.strip()

        # Detect start of require block
        if stripped.startswith("(require"):
            in_require = True
            # Check if this line itself contains a "../" path
            if '"../' in stripped:
                insert_idx = i
                break
            continue

        if in_require:
            # Look for first "../" require within the block
            if '"../' in stripped:
                insert_idx = i
                break
            # If we hit a closing paren or empty line, the require block ended
            if stripped == ")" or (stripped == "" and i > 0):
                # Insert before the closing or at the end
                insert_idx = i
                break

    if insert_idx is not None:
        # Determine indentation from the line we're inserting before
        ref_line = lines[insert_idx]
        indent = len(ref_line) - len(ref_line.lstrip())
        indent_str = " " * indent
        lines.insert(insert_idx, f'{indent_str}"test-support.rkt"')
        return "\n".join(lines)

    return content  # fallback: no change


def remove_here_lib_dir_definitions(content: str) -> str:
    """Remove the (define here ...) and (define lib-dir ...) lines.

    These are always exactly:
        (define here (path->string (path-only (syntax-source #'here))))
        (define lib-dir (simplify-path (build-path here ".." "lib")))

    Also removes surrounding blank lines and comments like:
        ;; Compute the lib directory path
    """
    lines = content.split("\n")
    result = []
    skip_next_blank = False

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Remove the here definition
        if stripped.startswith("(define here") and "syntax-source" in stripped:
            skip_next_blank = True
            i += 1
            continue

        # Remove the lib-dir definition
        if stripped.startswith("(define lib-dir") and "build-path here" in stripped:
            skip_next_blank = True
            i += 1
            continue

        # Remove the prelude-lib-dir definition (some files already use this name)
        if stripped.startswith("(define prelude-lib-dir") and "build-path here" in stripped:
            skip_next_blank = True
            i += 1
            continue

        # Remove common comment headers for these definitions
        if stripped in (
            ";; Compute the lib directory path",
            ";; Compute lib-dir from this file's location",
            ";; Helper for namespace-aware execution",
        ):
            skip_next_blank = True
            i += 1
            continue

        # Skip blank lines immediately after removed lines (avoid double-blanks)
        if skip_next_blank and stripped == "":
            skip_next_blank = False
            i += 1
            continue

        skip_next_blank = False
        result.append(line)
        i += 1

    return "\n".join(result)


def remove_redundant_requires(content: str) -> str:
    """Remove require lines for modules that test-support.rkt already provides.

    test-support.rkt requires and re-exports what it needs. Individual test files
    that ONLY needed these for the run-ns helper can drop them. However, many test
    files also use these modules directly (e.g., syntax.rkt for AST constructors),
    so we must be conservative.

    We ONLY remove:
      - racket/path  (only used for path-only in here/lib-dir definitions)

    We do NOT remove "../driver.rkt", "../namespace.rkt", etc. because many tests
    use their exports directly beyond what run-ns needs.
    """
    # Only remove racket/path if no other uses remain after here/lib-dir removal.
    # Actually, let's be even more conservative and not remove any requires
    # automatically. The user can do a second pass for that.
    return content


def apply_registry_replacements(content: str) -> tuple[str, list[str]]:
    """Apply all registry text replacements. Returns (new_content, list_of_changes)."""
    changes = []
    for old, new in REGISTRY_REPLACEMENTS:
        count = content.count(old)
        if count > 0:
            content = content.replace(old, new)
            changes.append(f"  {old} -> {new} ({count}x)")
    return content, changes


def convert_file(path: Path, dry_run: bool) -> dict:
    """Convert a single test file. Returns a report dict."""
    content = path.read_text(encoding="utf-8")
    original = content
    report = {
        "file": path.name,
        "skipped": False,
        "skip_reason": None,
        "changes": [],
        "modified": False,
    }

    # Skip gate: must use install-module-loader!
    if not file_uses_module_loader(content):
        report["skipped"] = True
        report["skip_reason"] = "no install-module-loader!"
        return report

    # Skip gate: must have fresh registry pattern
    if not file_has_fresh_registry(content):
        report["skipped"] = True
        report["skip_reason"] = "no (current-module-registry (hasheq))"
        return report

    # Skip if already converted
    if file_already_uses_test_support(content):
        report["skipped"] = True
        report["skip_reason"] = "already uses test-support.rkt"
        return report

    # --- Apply transformations ---

    # 1. Registry replacements
    content, changes = apply_registry_replacements(content)
    report["changes"].extend(changes)

    # 2. Add test-support.rkt require
    new_content = add_test_support_require(content)
    if new_content != content:
        report["changes"].append("  + added require \"test-support.rkt\"")
        content = new_content

    # 3. Remove here/lib-dir definitions
    new_content = remove_here_lib_dir_definitions(content)
    if new_content != content:
        report["changes"].append("  - removed (define here ...) and (define lib-dir ...) lines")
        content = new_content

    # Check if anything actually changed
    if content != original:
        report["modified"] = True
        if not dry_run:
            path.write_text(content, encoding="utf-8")

    return report


def main():
    parser = argparse.ArgumentParser(
        description="Convert test files to use shared prelude from test-support.rkt"
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--dry-run", action="store_true", help="Preview changes without modifying files")
    group.add_argument("--apply", action="store_true", help="Apply changes to files in place")
    parser.add_argument(
        "--file", type=str, default=None,
        help="Convert only this specific file (basename, e.g. test-bundles.rkt)"
    )
    args = parser.parse_args()

    # Locate tests directory
    script_dir = Path(__file__).resolve().parent
    # Script is in racket/prologos/tools/, tests are in racket/prologos/tests/
    tests_dir = script_dir.parent / "tests"
    if not tests_dir.is_dir():
        print(f"ERROR: tests directory not found at {tests_dir}", file=sys.stderr)
        sys.exit(1)

    # Find candidate files
    if args.file:
        target = tests_dir / args.file
        if not target.exists():
            print(f"ERROR: file not found: {target}", file=sys.stderr)
            sys.exit(1)
        if target.name in SKIP_FILES:
            print(f"SKIP: {target.name} is in the skip list")
            sys.exit(0)
        test_files = [target]
    else:
        test_files = find_test_files(tests_dir)

    mode = "DRY RUN" if args.dry_run else "APPLYING"
    print(f"=== Convert test files to use test-support.rkt ({mode}) ===")
    print(f"Tests directory: {tests_dir}")
    print(f"Candidate files: {len(test_files)}")
    print(f"Skipping (shared-module-reg): {sorted(SKIP_SHARED_MODULE_REG)}")
    print()

    converted = 0
    skipped = 0
    unchanged = 0

    for path in test_files:
        report = convert_file(path, dry_run=args.dry_run)

        if report["skipped"]:
            skipped += 1
            print(f"  SKIP  {report['file']:45s} ({report['skip_reason']})")
        elif report["modified"]:
            converted += 1
            action = "WOULD" if args.dry_run else "DONE"
            print(f"  {action}  {report['file']}")
            for change in report["changes"]:
                print(f"        {change}")
        else:
            unchanged += 1
            print(f"  SAME  {report['file']:45s} (no changes needed)")

    print()
    print("=" * 60)
    print(f"  Converted: {converted}")
    print(f"  Skipped:   {skipped}")
    print(f"  Unchanged: {unchanged}")
    print(f"  Total:     {len(test_files)}")
    if args.dry_run:
        print()
        print("  (dry run -- no files were modified)")
        print("  Re-run with --apply to write changes.")
    print("=" * 60)


if __name__ == "__main__":
    main()
