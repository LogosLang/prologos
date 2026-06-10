# alphaXiv MCP wrapper fix — 2026-05-09

Diagnostic + patch notes for the broken `alpha_search` and `alpha_ask_paper`
agent tools in this Feynman install. Keep this file: re-application instructions live here.

## Symptoms (from this and the previous session)

- `alpha_search` (any mode) → `MCP error -32602: Tool embedding_similarity_search not found` (or `full_text_papers_search` / `agentic_paper_retrieval` per mode).
- `alpha_ask_paper` → `MCP error -32602: Input validation error: Invalid arguments for tool answer_pdf_queries: queries expected array, received undefined`.
- `alpha_get_paper` works.

## Root cause — the alphaXiv MCP server changed schema, alpha-hub didn't update

Three layers and where they live:

1. **Upstream MCP server**: `https://api.alphaxiv.org/mcp/v1` (SSE / OAuth 2.0). Schema accessible via `tools/list`. Truth-of-the-world.
2. **alpha-hub (npm `@companion-ai/alpha-hub` v0.1.3)**: thin Node wrapper. Repo `getcompanion-ai/alpha-hub`, last pushed 2026-03-25 (frozen ~6 weeks).
3. **alphaXiv official docs page** (`https://www.alphaxiv.org/docs/mcp`): also stale; lists 6 tools, claims `answer_pdf_queries` takes singular `query`.

Direct probe of the live server (`tools/list`, May 9 2026) shows **4 tools**, not 6:

| Tool | Live schema |
|---|---|
| `discover_papers` (NEW) | `{ keywords: string[], question: string, difficulty: number 1-10 }` — all required |
| `get_paper_content` | `{ url: string, fullText?: boolean }` |
| `answer_pdf_queries` | `{ url: string, queries: string[] }` — singular `url`, plural `queries` |
| `read_files_from_github_repository` | `{ githubUrl: string, path: string }` |

Three changes upstream not reflected anywhere else:

- **Search consolidation**: `embedding_similarity_search` + `full_text_papers_search` + `agentic_paper_retrieval` removed; replaced by one `discover_papers` that bundles keywords + semantic question + difficulty.
- **`answer_pdf_queries` schema flip**: now takes one `url` and an *array* of `queries` (batched questions against one paper). The wrapper sent the opposite shape (`urls: [url], queries: [query]`).
- **Behaviour change**: `answer_pdf_queries` now returns *filtered raw page XML* (`<paper id="…"><page num="N">…</page></paper>`), not a prose answer. Treat it as a focused-extraction tool, not a Q&A LLM.

The official docs page is also out of sync with the live server (lists removed search tools, says `query` not `queries`).

## How the diagnostic was done

Standalone probe script (kept at `…/feynman-0.2.49-darwin-arm64/.../alpha-diagnose.mjs`):

1. Imported `getValidToken` from `@companion-ai/alpha-hub/lib/auth` to reuse the saved OAuth token.
2. Connected via `StreamableHTTPClientTransport` with `Authorization: Bearer <token>`.
3. Called `client.listTools()` to print the canonical schema for every live tool.
4. Probed each old tool name with the wrapper's old args, then probed candidate replacement shapes for `answer_pdf_queries`.

The output of `tools/list` is the source of truth and should be re-run any time alpha behaviour drifts.

## Fix applied

Patched, in place, the local install at:

```
/Users/avanti/.local/share/feynman/feynman-0.2.49-darwin-arm64/app/.feynman/npm/node_modules/@companion-ai/alpha-hub/src/lib/alphaxiv.js
```

Backup of the original at `alphaxiv.js.bak` next to it.

The patch:

- Adds `discoverPapers({ keywords, question, difficulty })` calling `discover_papers`.
- Replaces `searchByEmbedding/Keyword/Agentic` with shims that auto-extract keywords from the free-form `query` (whitespace split, drop stopwords, top 4 tokens), build a question, and route through `discoverPapers`. Mode → difficulty: `keyword=3`, `semantic=5`, `agentic=8`.
- Rewrites `answerPdfQuery(url, queriesOrQuery)` to send `{ url, queries: <array> }`. Accepts either a single string (auto-wrapped) or an array of strings (preferred — lets the agent batch multiple questions in one call).

The MCP-server bridge (`src/mcp/tools.js` / `src/mcp/server.js`) was **not** changed. The legacy `alpha_search { query, mode }` and `alpha_ask { url, question }` agent surfaces still work because they call into the patched library functions.

## Verification (CLI, 2026-05-09)

Direct CLI calls succeed:

```bash
$ alpha search "free lattice undecidability first-order"
1. [ID=2511.13149] Elementary properties of free lattices III: Undecidability of the full theory ...
$ alpha search --mode keyword "Whitman free lattice"
1. [ID=1805.02554] Symmetric embeddings of free lattices into each other ...
$ alpha search --mode agentic "polynomial functor propagator network lattice cells"
1. [ID=2502.15476] Sheaf theory: from deep geometry to deep learning ... (etc.)
$ alpha ask 2511.13149 "What undecidability source do they reduce from?"
<paper id="2511.13149v1"><page num="1">ELEMENTARY PROPERTIES OF FREE LATTICES III ...
```

Agent-side `alpha_search` / `alpha_ask_paper` MCP tools require **a fresh Feynman session** to pick up the patched library — the `alpha-mcp` subprocess started at session boot has the old code in memory. After restart they should both work.

## How to reapply if alpha-hub is reinstalled

If a `feynman packages install` or upgrade re-fetches `@companion-ai/alpha-hub@0.1.3`, the patch will be wiped. Two options:

1. **Local-only**: re-run this fix by replaying the edits in this note. The unified diff is the `.bak` vs current `alphaxiv.js`.
2. **Upstream PR** (recommended longer-term): file an issue at `https://github.com/getcompanion-ai/alpha-hub/issues` reporting the upstream alphaXiv schema migration; offer this patch (or a cleaner version) as a PR. Repo is small (5 stars, 1 active maintainer @advaitpaliwal); a focused PR with the `tools/list` evidence is likely to land.

Also worth flagging to alphaXiv directly: their docs page (`https://www.alphaxiv.org/docs/mcp`) still describes the pre-migration tool surface, which guarantees every new wrapper integrator hits the same wall.

## Behaviour change to remember in the agent

`alpha_ask_paper` / `alpha ask` no longer returns a prose answer. It returns filtered raw page XML keyed by query terms. To get a synthesized answer the agent should:

1. Call `alpha_ask_paper` to extract the relevant pages.
2. Read the XML and synthesize the answer in the agent itself.

Or equivalently: `alpha_get_paper { fullText: true }` for the whole paper, then read locally. The Q&A behaviour the old wrapper offered is gone upstream.
