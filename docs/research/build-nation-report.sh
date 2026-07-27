#!/usr/bin/env bash
# Build a printable PDF from the Prologos Lattice Variety Categorization report.
#
# Usage:
#   ./build-nation-report.sh
#   ./build-nation-report.sh /path/to/output.pdf
#
# Requires:
#   pandoc, xelatex (mactex), fontspec-compatible system fonts.
#
# Pre-processes mermaid blocks to verbatim ASCII representations
# (pandoc/xelatex don't render mermaid natively). The pre-processed
# markdown is written to a temp file and rendered.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT="${SCRIPT_DIR}/2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION.md"
HEADER="${SCRIPT_DIR}/nation-report-header.tex"
OUTPUT="${1:-${SCRIPT_DIR}/2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION.pdf}"

if [ ! -f "$INPUT" ]; then
  echo "ERROR: input not found: $INPUT" >&2
  exit 1
fi
if [ ! -f "$HEADER" ]; then
  echo "ERROR: LaTeX header not found: $HEADER" >&2
  exit 1
fi

# --- Pre-process mermaid blocks ---
# pandoc + xelatex don't render mermaid. Replace with verbatim ASCII
# diagrams that match the structural intent of each diagram.

TMPDIR="$(mktemp -d)"
trap "rm -rf '$TMPDIR'" EXIT
PROCESSED="${TMPDIR}/report.md"

python3 <<PYEOF > "$PROCESSED"
import re

with open("$INPUT") as f:
    content = f.read()

# --- Mermaid block 1: variety hierarchy (graph TD with classDef) ---
# Replace with a verbatim text representation of the partial order.
hier_replacement = '''\`\`\`
                Free / SD-and-W
                       │
                       ▼
              SD (semidistributive)
                       │
                       ▼
                    Modular
                       │
                       ▼
                  Distributive
                       │
                       ▼
                    Heyting
                       │
                       ▼
              Stone algebra  [empirically REFUTED across all measured domains]
                       │
                       ▼
              Boolean algebra  [empirically REFUTED]
\`\`\`
'''

# --- Mermaid block 2: ground-vs-binder flow (graph LR) ---
binder_replacement = '''\`\`\`
  Ground sublattice  ──both relations──▶  Heyting
         │
         │  + binders
         ▼
  Binder boundary
     ├── equality merge: union-aware  ──▶  SD ✓ + modular ✓; distributive ✗
     └── subtype merge:  GLB           ──▶  SD ✓; modular ✗; distributive ✗
\`\`\`
'''

# Replace in order — first hierarchy, then binder.
# Match \`\`\`mermaid through closing \`\`\`.
mermaid_pattern = re.compile(r'\`\`\`mermaid\n(.*?)\n\`\`\`', re.DOTALL)

replacements = [hier_replacement, binder_replacement]
idx = [0]

def replacer(match):
    body = match.group(1)
    if 'graph TD' in body or 'Free' in body and 'Boolean' in body:
        return hier_replacement
    elif 'graph LR' in body or 'Binder' in body or 'Ground sublattice' in body:
        return binder_replacement
    else:
        # Fallback: show source as code block
        return '\`\`\`\n[mermaid diagram source]\n' + body + '\n\`\`\`'

content = mermaid_pattern.sub(replacer, content)

# --- Unicode substitutions for chars not in available fonts ---
# These chars don't render in DejaVu Sans Mono's OT-Latin lookup or
# fail under \ensuremath inside \texttt{}. Substitute with readable
# ASCII / Unicode-broader-coverage equivalents.
content = content.replace('⋁', 'Join')   # big-vee → Join (text)
content = content.replace('⊓', '/\\\\')  # meet → /\ (4 backslashes survive heredoc)
content = content.replace('⊔', '\\\\/')  # join → \/

print(content, end='')
PYEOF

# --- Render via pandoc ---
echo "Rendering: $INPUT -> $OUTPUT"

cd "$TMPDIR"

pandoc "$PROCESSED" \
  -o "$OUTPUT" \
  --pdf-engine=xelatex \
  --from=markdown+pipe_tables+yaml_metadata_block+raw_tex+fenced_code_blocks+backtick_code_blocks \
  --toc \
  --toc-depth=2 \
  --number-sections=false \
  -V documentclass=article \
  -V papersize=letter \
  -V colorlinks=true \
  -H "$HEADER" \
  --metadata title="Prologos Lattice Variety Categorization" \
  --metadata subtitle="Empirical Findings" \
  --metadata author="The Prologos Project" \
  --metadata date="2026-05-08"

if [ -f "$OUTPUT" ]; then
  PAGES="$(pdfinfo "$OUTPUT" 2>/dev/null | awk '/^Pages:/ {print $2}')"
  echo "✓ Generated: $OUTPUT ($PAGES pages)"
else
  echo "ERROR: PDF generation failed" >&2
  exit 1
fi
