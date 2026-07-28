// grounding-audit — reusable Stage-4 mini-audit workflow for Prologos sub-phases.
//
// WHAT IT IS (and why it's more than "spawn some read-only agents"):
//   Parallel HEAD-pinned read-only facets + an adversarial COMPLETENESS CRITIC,
//   returning a DISTILLED, STRUCTURED synthesis. It exists to keep the MAIN
//   thread's context lean: the facets do the file-reading in their own
//   (disposable) context and return only structured findings; the critic
//   cross-checks them against the design doc's OWN claims (the recurring
//   "the design enumeration under-counts" failure mode — cfa:261, test-posit64,
//   bench-executors, the 4A.c-ii-b NO-GO); and the result hands the main session
//   an explicit `rlens_targets` list so it R-lens-verifies SURGICALLY (targeted
//   greps) instead of re-reading everything.
//
// IT ENCODES (by construction, so agents "follow our process"):
//   - HEAD-pin + cite the SHA + verify-don't-assume line numbers
//   - read the MAIN checkout only (NOT .claude/worktrees/ — the worktree-HEAD
//     defect bit us twice: §18.18.6.10 / §18.18.6.13)
//   - cite file:line for every claim; FLAG-DON'T-GUESS; verified vs inferred
//   - read-only (this is grounding, not implementation; per "diff-back, don't
//     land-in-workflow", the main session does the implementing + gating)
//
// SCOPE: grounding/audit ONLY. It does NOT design (that's the main-session
//   co-design dialogue with the user) and does NOT implement. Its output FEEDS
//   the mini-design dialogue.
//
// ARGS (pass as a JSON object):
//   {
//     subphase:    "4A.d",                       // label
//     head:        "8211247d",                   // expected HEAD; facets verify + cite
//     context:     "one paragraph: what this sub-phase is + the design intent",
//     facets:    [ { label: "...", prompt: "the read-only audit question" }, ... ]
//                  // bare strings also accepted: [ "the question", ... ]
//                  // a missing/empty prompt ABORTS the run (was: silently sent "undefined")
//     designClaims: [ "a claim the design doc makes that the audit must confirm/refute (cite §)", ... ],
//     questions:    [ "an open design question the synthesis should inform", ... ]
//   }

export const meta = {
  name: 'grounding-audit',
  description: 'Stage-4 mini-audit: parallel HEAD-pinned read-only facets + adversarial completeness critic → distilled synthesis (verified findings, capture-gaps, R-lens targets). Encodes the Prologos audit disciplines. Read-only; feeds the main-session co-design.',
  whenToUse: 'Opening a sub-phase mini-audit — ground design decisions in current code before implementing, while keeping the main thread lean. Pass the surfaces to audit via args.',
  phases: [
    { title: 'Facets', detail: 'parallel read-only audits over the declared surfaces' },
    { title: 'Critique', detail: 'adversarial completeness critic vs the design claims' },
  ],
}

// Robust to the args-stringification footgun (codified: a JSON object can reach
// the script as a STRING — guard with JSON.parse). Accepts object | string | undefined.
const A = (typeof args === 'string' ? JSON.parse(args) : (args || {}))
const head = A.head || 'HEAD'
const subphase = A.subphase || '(unspecified sub-phase)'
const facets = A.facets || []
const designClaims = A.designClaims || []
const questions = A.questions || []

if (facets.length === 0) {
  log('grounding-audit: no facets supplied in args — nothing to audit.')
  return { error: 'no facets', subphase }
}

// Discipline preamble prepended to EVERY facet — encodes the codified rules so
// the agent process follows our process by construction.
const DISCIPLINE = `Read-only grounding audit for the Prologos compiler (repo /Users/avanti/dev/projects/prologos; source under racket/prologos/).

DISCIPLINE — follow exactly:
- FIRST run \`git rev-parse HEAD\` and CITE the result. Expected ${head}. If it DIFFERS, say so PROMINENTLY: every line number must be verified against the ACTUAL current file, never assumed.
- Read the MAIN checkout ONLY. Do NOT read any .claude/worktrees/ copy (stale / other-branch).
- Cite file:line for EVERY claim, and quote the relevant code.
- FLAG-DON'T-GUESS: if you cannot confirm something with confidence, flag it as an open item — do not guess.
- Mark each finding as VERIFIED (you read the code) or INFERRED.
- This is READ-ONLY grounding. Do not edit anything.

Sub-phase: ${subphase}
Context: ${A.context || '(none given)'}`

// Structured output schema — uniform across facets + critic, so the synthesis
// is machine-shaped and the main session gets exactly the R-lens targets.
const SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    head_verified: { type: 'string', description: 'the SHA `git rev-parse HEAD` returned (flag if != expected)' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          claim: { type: 'string' },
          evidence: { type: 'string', description: 'file:line + a short quote' },
          confidence: { type: 'string', enum: ['verified', 'inferred', 'flagged'] },
        },
        required: ['claim', 'evidence', 'confidence'],
      },
    },
    capture_gaps: {
      type: 'array',
      items: { type: 'string' },
      description: 'surfaces the design enumeration / prior framing MISSED or under-counted (file:line)',
    },
    rlens_targets: {
      type: 'array',
      items: { type: 'string' },
      description: 'the load-bearing claims the MAIN SESSION should R-lens-verify (a targeted grep/read) before trusting (file:line)',
    },
  },
  required: ['head_verified', 'findings', 'capture_gaps', 'rlens_targets'],
}

phase('Facets')
// Normalize facets: accept EITHER {label, prompt} objects OR bare strings.
// Passing bare strings used to silently send the literal text "undefined" to
// every agent (f.prompt on a string is undefined), so all facets ran the same
// unpartitioned full-surface audit while LOOKING like N independent slices —
// and "N facets agreed" became false corroboration. Observed 2026-07-27 on the
// issue-#78 audit: all 5 facets shared a blind spot the critic then caught.
// Silent-wrong-answer class; now normalized, and validated loudly below.
const normalizedFacets = facets.map((f, i) => {
  const prompt = (typeof f === 'string') ? f : (f && f.prompt)
  const label = (typeof f === 'string') ? ('facet-' + i) : ((f && f.label) || ('facet-' + i))
  return { label, prompt }
})
const badFacets = normalizedFacets
  .map((f, i) => ({ i, f }))
  .filter(({ f }) => typeof f.prompt !== 'string' || f.prompt.trim() === '')
if (badFacets.length > 0) {
  const idxs = badFacets.map(({ i }) => i).join(', ')
  log(`grounding-audit: ABORT — ${badFacets.length} facet(s) have an empty/missing prompt (indices: ${idxs}). Pass either a string or {label, prompt}.`)
  return { error: 'malformed facets', badFacetIndices: badFacets.map(({ i }) => i), subphase }
}

log(`grounding-audit ${subphase}: ${normalizedFacets.length} read-only facets @ expected HEAD ${head}`)
const facetResults = (await parallel(
  normalizedFacets.map((f) => () =>
    agent(
      `${DISCIPLINE}\n\nYOUR FACET — ${f.label}:\n${f.prompt}`,
      { label: `audit:${f.label}`, phase: 'Facets', schema: SCHEMA }
    )
  )
)).filter(Boolean)

phase('Critique')
// Adversarial completeness critic: cross-check the facets against each other AND
// against the design doc's own claims. The recurring Prologos failure mode is
// the design's OWN enumeration under-counting; this stage is built to catch it.
const critic = await agent(
  `${DISCIPLINE}

You are the COMPLETENESS CRITIC. ${facetResults.length} read-only facet(s) just audited ${subphase}. Their structured findings:

${JSON.stringify(facetResults, null, 2)}

The design doc makes these CLAIMS the sub-phase relies on. For EACH, determine against CODE whether the facets/code CONFIRM, REFUTE, or DID-NOT-COVER it (cite file:line). The recurring failure mode in this project is the design's OWN enumeration under-counting — a missed call site, a stale line number, a capture-gap. Hunt for it:
${designClaims.map((c, i) => `  C${i + 1}. ${c}`).join('\n') || '  (none supplied)'}

Open design questions the synthesis should inform (do NOT design — surface the CODE FACTS each question turns on):
${questions.map((q, i) => `  Q${i + 1}. ${q}`).join('\n') || '  (none supplied)'}

Surface, with file:line evidence: (1) any design claim REFUTED or UNCOVERED; (2) capture-gaps the facets or design missed; (3) cross-facet disagreements + which is right per ground truth; (4) the load-bearing claims the MAIN SESSION must R-lens before trusting. FLAG-DON'T-GUESS.`,
  { label: 'completeness-critic', phase: 'Critique', schema: SCHEMA }
)

// Distilled return — this is what the main session reads (NOT the raw facet dumps).
return {
  subphase,
  expectedHead: head,
  facets: facetResults,
  critic,
  mainSessionNote:
    'R-lens-verify the critic.rlens_targets (+ facet rlens_targets) with SURGICAL greps before trusting; resolve capture_gaps; THEN co-design the questions with the user. Per "diff-back, don\'t land-in-workflow": implement in the main session at the known-good HEAD, then gate.',
}
