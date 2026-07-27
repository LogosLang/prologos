// design-options-panel — reusable Stage-3 design-options workflow for Prologos.
//
// WHAT IT IS (and why it's more than "ask some agents for options"):
//   For each open design-question CLUSTER, a PROPOSE agent (grounded in the
//   verified code facts from a prior grounding-audit AND in our design-process
//   documentation) enumerates 2–4 options with tradeoffs, each tagged with the
//   principle(s) it serves, its mantra alignment, its P/R/M/S lens posture, and
//   its Network Reality Check; then an ADVERSARIAL CRITIQUE agent challenges each
//   option per CRITIQUE_METHODOLOGY (P/R/M/S + SRE lattice lens), the design
//   mantra ("could this be MORE aligned?"), and the red-flag-phrase catalogue —
//   returning per-option verdicts + a recommended survivor + open sub-questions.
//   A final SYNTHESIS agent cross-checks the recommended options across clusters
//   for coherence (do they COMPOSE? contradictions? implied sub-phase partition?).
//
// IT IS NOT a decision-maker. Per DESIGN_METHODOLOGY § "Delegation vs Co-Design":
//   the workflow produces MATERIAL (options + tradeoffs + adversarial critique);
//   the human + main session DECIDE + land. The Q-resolution stays in the
//   conversational co-design dialogue with the user. This is the "fan out audit +
//   pre-critique, keep Q-resolution in dialogue" pattern for high-stakes openings.
//
// DISCIPLINE ENCODED: agents READ the design-process docs (grounding in process,
//   not just inline briefing); cite which principle each option serves; apply the
//   adversarial framing actively (catalogue vs challenge two-column); FLAG-DON'T-
//   GUESS; read-only (no implementation). It CONSUMES a grounding-audit synthesis
//   (verified code facts) so the options are code-grounded, not floating.
//
// ARGS (pass as a JSON object):
//   {
//     subphase: "PPN 4C Addendum Phase 4B",
//     context:  "one paragraph: the design intent + what's already LOCKED",
//     grounding: <the grounding-audit synthesis object — verified code facts>,
//     clusters: [ { key, title, question, hints }, ... ]   // hints = relevant facts/§refs
//   }

export const meta = {
  name: 'design-options-panel',
  description: 'Stage-3 design-options workflow: per open-question cluster, a propose agent (grounded in verified code facts + our design-process docs) enumerates principled options with tradeoffs, an adversarial critique agent challenges each per P/R/M/S + the mantra + red-flag phrases, and a synthesis agent cross-checks coherence. Read-only; produces material for main-session co-design, does NOT decide.',
  whenToUse: 'A high-stakes design opening where the open questions are grounded (a grounding-audit ran) and you want principled, adversarially-critiqued options + tradeoffs to bring back to co-design. Pass the grounding synthesis + question clusters via args.',
  phases: [
    { title: 'Propose', detail: 'per cluster: principled options + tradeoffs, grounded in code + process docs' },
    { title: 'Critique', detail: 'per cluster: adversarial challenge vs P/R/M/S + mantra + red-flags' },
    { title: 'Synthesize', detail: 'cross-cluster coherence + implied sub-phase partition' },
  ],
}

const A = (typeof args === 'string' ? JSON.parse(args) : (args || {}))
const subphase = A.subphase || '(unspecified)'
const context = A.context || '(none given)'
const grounding = A.grounding || {}
const clusters = A.clusters || []

if (clusters.length === 0) {
  log('design-options-panel: no clusters supplied — nothing to do.')
  return { error: 'no clusters', subphase }
}

const repo = '/Users/avanti/dev/projects/prologos'

// The design-process briefing — encodes our lenses inline AND points at the docs
// to READ (genuine grounding in process, per the user's instruction). Prepended
// to every propose agent.
const PROCESS_PRIMER = `You are a Prologos design contributor. Prologos is a functional-logic language whose compiler runs ON A PROPAGATOR NETWORK (cells hold lattice values; propagators react; a BSP scheduler fires them). The whole project is bringing elaboration ON-NETWORK.

GROUND YOURSELF IN OUR DESIGN PROCESS — read these (repo ${repo}) before proposing:
- docs/tracking/principles/DESIGN_PRINCIPLES.org — the 10 load-bearing principles + the Hyperlattice Conjecture + Cell/Propagator/Scheduler Orthogonality + the Specialized Cell Type Framework. (Read it.)
- .claude/rules/on-network.md — the DESIGN MANTRA ("All-at-once, all in parallel, structurally emergent information flow ON-NETWORK") + the on-network mandate + red-flag patterns. (Read it.)
- .claude/rules/structural-thinking.md — the SRE lattice lens (6 questions), the Hasse-diagram optimality argument, Module Theory, retraction-as-narrowing. (Read it.)
- .claude/rules/propagator-design.md — fire-once / broadcast / set-latch / component-paths / the Network Reality Check. (Skim for the patterns relevant to your cluster.)

THE LENSES every option must be evaluated through (apply them, don't just name them):
- THE MANTRA, per word: All-at-once (are independent items sequenced?) · all in parallel (imposed ordering that should emerge from dataflow?) · structurally emergent (imperative control flow deciding what happens when?) · information flow (values through cells, or through return-values/params/for-fold accumulators?) · ON-NETWORK (a cell with a monotone merge, or off-network state?).
- THE 10 PRINCIPLES — especially Propagator-First Infrastructure, Correct-by-Construction, Data Orientation, First-Class by Default, Decomplection, the Hyperlattice Conjecture, Cell/Propagator/Scheduler Orthogonality.
- THE NETWORK REALITY CHECK (the M-lens, load-bearing here): for any component claimed "on-network", which net-add-propagator calls? which net-cell-write produces the result? can you trace cell-creation → propagator-install → cell-write → cell-read = result? If not, it's a function-call chain wearing propagator vocabulary — say so.
- THE SRE LATTICE LENS for any lattice/cell: VALUE vs STRUCTURAL; algebraic properties; bridges (Galois); primary vs derived; the Hasse diagram.

RED-FLAG PHRASES to NAME if an option leans on them: "temporary bridge", "belt-and-suspenders", "keep the old path as fallback", "pragmatic", "for safety/symmetry", "scanning/polling for readiness", "validated but not deployed", "we'll come back to it". An option may legitimately need scaffolding — but it must be NAMED as scaffolding-with-a-retirement-plan, not rationalized.

This is DESIGN, read-only. Do NOT edit code. Do NOT pick the winner unilaterally — your job is to lay out principled options + tradeoffs for the human's co-design decision. FLAG-DON'T-GUESS: if an option hinges on a code fact not in the grounding, flag it as a main-session R-lens target.`

const VERIFIED_FACTS = `VERIFIED CODE GROUNDING (from the prior grounding-audit — treat as the ground truth; do not re-audit, but flag anything load-bearing you'd want re-verified):
${JSON.stringify(grounding, null, 2)}

DESIGN INTENT / WHAT'S LOCKED:
${context}`

const PROPOSE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    cluster: { type: 'string' },
    options: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          name: { type: 'string', description: 'short option name' },
          summary: { type: 'string', description: '1-2 sentences: what the option IS' },
          mechanism: { type: 'string', description: 'concretely how it works on the network (cells/propagators/install path), grounded in the verified facts' },
          principlesServed: { type: 'array', items: { type: 'string' }, description: 'which of the 10 principles + which mantra-words this serves' },
          mantraPosture: { type: 'string', description: 'per-word mantra read: where it is aligned, where it strains' },
          networkRealityCheck: { type: 'string', description: 'does it add net-add-propagator / net-cell-write, or is it a function-call chain? Honest.' },
          sreLatticeNote: { type: 'string', description: 'if a lattice/cell is involved: VALUE vs STRUCTURAL, merge, primary/derived (else "n/a")' },
          pros: { type: 'array', items: { type: 'string' } },
          cons: { type: 'array', items: { type: 'string' } },
          scaffoldingNamed: { type: 'string', description: 'any scaffolding this needs, NAMED with a retirement plan (else "none")' },
        },
        required: ['name', 'summary', 'mechanism', 'principlesServed', 'mantraPosture', 'networkRealityCheck', 'sreLatticeNote', 'pros', 'cons', 'scaffoldingNamed'],
      },
    },
    leanIfForced: { type: 'string', description: 'IF forced to lean (the human decides) — which option + one-line why, on principle' },
    openSubQuestions: { type: 'array', items: { type: 'string' }, description: 'sub-questions the main-session co-design must resolve / R-lens targets' },
  },
  required: ['cluster', 'options', 'leanIfForced', 'openSubQuestions'],
}

const CRITIQUE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    cluster: { type: 'string' },
    perOptionVerdicts: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          option: { type: 'string' },
          challenge: { type: 'string', description: 'the adversarial challenge — "could this be MORE aligned?"; where it BREAKS; what a hostile reviewer cites' },
          prmsFindings: { type: 'string', description: 'P (principle conflict?), R (code-reality risk?), M (step-think disguised as propagator?), S (missing structural machinery / hand-rolled algebra?)' },
          redFlagsCaught: { type: 'array', items: { type: 'string' }, description: 'red-flag phrases / patterns this option leans on (empty if none)' },
          survives: { type: 'boolean', description: 'does the option survive the adversarial pass (with named caveats), or is it principle-violating?' },
        },
        required: ['option', 'challenge', 'prmsFindings', 'redFlagsCaught', 'survives'],
      },
    },
    recommendation: { type: 'string', description: 'which option(s) survive best AND WHY on principle — but framed as input to co-design, not a decision' },
    sharpestFinding: { type: 'string', description: 'the single most load-bearing thing the human must weigh' },
    openSubQuestions: { type: 'array', items: { type: 'string' } },
  },
  required: ['cluster', 'perOptionVerdicts', 'recommendation', 'sharpestFinding', 'openSubQuestions'],
}

phase('Propose')
log(`design-options-panel ${subphase}: ${clusters.length} question clusters → propose ⇒ critique (pipeline)`)

// pipeline: each cluster goes propose → critique independently (no barrier).
const critiqued = await pipeline(
  clusters,
  // Stage 1 — PROPOSE (grounded in process docs + verified code facts)
  (c) => agent(
    `${PROCESS_PRIMER}\n\n${VERIFIED_FACTS}\n\nYOUR CLUSTER — ${c.title}\n\nOPEN QUESTION:\n${c.question}\n\nRELEVANT GROUNDING / DESIGN-DOC POINTERS:\n${c.hints || '(use the verified facts above)'}\n\nEnumerate 2–4 genuinely-distinct options. For EACH: mechanism on the network, principles served, per-word mantra posture, the Network Reality Check (honest), SRE lattice note if applicable, pros/cons, and any scaffolding NAMED with a retirement plan. Then a lean-if-forced (the human decides) + open sub-questions / R-lens targets.`,
    { label: `propose:${c.key}`, phase: 'Propose', schema: PROPOSE_SCHEMA }
  ),
  // Stage 2 — CRITIQUE (adversarial, grounded in critique methodology)
  (proposal, c) => agent(
    `You are an ADVERSARIAL DESIGN CRITIC for the Prologos compiler (repo ${repo}). GROUND YOURSELF in our critique methodology before critiquing — READ:
- docs/tracking/principles/CRITIQUE_METHODOLOGY.org — the P/R/M lenses + the SRE Lattice Lens + "Cataloguing Instead of Challenging" + "Receiving External Critique: Grounded Pushback".
- docs/tracking/principles/DESIGN_METHODOLOGY.org § Stage 3 — the P/R/M/S self-critique lenses + the Design Mantra Audit + the adversarial framing (catalogue vs challenge, two columns).

Your job is to CHALLENGE, not catalogue. For each option below, force the comparison "could this be MORE aligned?" — not "does it satisfy the bar?". Apply: P (does it conflict with a load-bearing principle / could it be more propagator-first?), R (is its premise true in the verified code facts — any code-reality risk?), M (step-think disguised as propagator-think? run the Network Reality Check — net-add-propagator? net-cell-write? traceable cell→propagator→cell→result?), S (missing SRE/PUnify/Hasse/Module-theoretic machinery, or hand-rolled algebra that should consume an existing primitive?). Name any red-flag phrases it leans on. A scaffolding option can SURVIVE if its scaffolding is honestly named with a retirement plan — kill it only if it's principle-violating or rationalized.

CLUSTER — ${c.title}
OPEN QUESTION:
${c.question}

THE PROPOSED OPTIONS (from the propose agent):
${JSON.stringify(proposal, null, 2)}

VERIFIED CODE GROUNDING (the ground truth for the R + M lenses):
${JSON.stringify(grounding, null, 2)}

For EACH option: the adversarial challenge (where it breaks / what a hostile reviewer cites), the P/R/M/S findings, red-flags caught, and whether it survives (with named caveats). Then: a recommendation framed as INPUT TO CO-DESIGN (not a unilateral decision), the single sharpest thing the human must weigh, and open sub-questions. If the propose agent MISSED an option that's more principle-aligned, ADD it. FLAG-DON'T-GUESS.`,
    { label: `critique:${c.key}`, phase: 'Critique', schema: CRITIQUE_SCHEMA }
  ).then((critique) => ({ cluster: c, proposal, critique }))
)

const survivors = critiqued.filter(Boolean)

phase('Synthesize')
// Cross-cluster coherence: the 4B questions interact (factory + residuation +
// install-tier + ordering all couple). A synthesizer checks the recommended
// options COMPOSE + sketches the implied sub-phase partition.
const synthesis = await agent(
  `You are the SYNTHESIS agent for a Prologos Stage-3 design-options panel on ${subphase}. ${survivors.length} question clusters were each proposed + adversarially critiqued. The full per-cluster material:

${JSON.stringify(survivors, null, 2)}

DESIGN INTENT / WHAT'S LOCKED:
${context}

The clusters INTERACT (e.g. the factory shape, the residuation mechanism, the install-tier, and the 4B↔4C↔4D ordering couple; dep-recording-retirement + the cell-dependents API + the dep-edge KIND are one substrate). Produce a CROSS-CLUSTER synthesis for the main-session co-design — do NOT decide:
1. COHERENCE: do the surviving/recommended options across clusters COMPOSE into one architecture? Any contradictions or tensions between cluster recommendations (cite which)?
2. THE IMPLIED SUB-PHASE PARTITION (Q-4B.8): if the leans hold, what is the natural sub-phase sequence + the minimal first-green slice? Note what couples to 4C / 4D.
3. THE LOAD-BEARING DECISIONS the human must make first (ordered) — the ones that unlock the rest.
4. THE TOP R-LENS TARGETS for the main session to verify before trusting any lean.
5. ANY option a hostile reviewer would say violates the mantra / a principle that the per-cluster critique under-weighted.
Read-only, FLAG-DON'T-GUESS, frame everything as input to co-design.`,
  { label: 'cross-cluster-synthesis', phase: 'Synthesize', schema: {
    type: 'object',
    additionalProperties: false,
    properties: {
      coherence: { type: 'string' },
      tensions: { type: 'array', items: { type: 'string' } },
      impliedPartition: { type: 'string' },
      firstGreenSlice: { type: 'string' },
      loadBearingDecisionsOrdered: { type: 'array', items: { type: 'string' } },
      topRlensTargets: { type: 'array', items: { type: 'string' } },
      mantraOrPrincipleWatchouts: { type: 'array', items: { type: 'string' } },
    },
    required: ['coherence', 'tensions', 'impliedPartition', 'firstGreenSlice', 'loadBearingDecisionsOrdered', 'topRlensTargets', 'mantraOrPrincipleWatchouts'],
  } }
)

return {
  subphase,
  clusters: survivors,
  synthesis,
  mainSessionNote:
    'This is design MATERIAL for co-design, NOT a decision. Bring the options + tradeoffs + adversarial verdicts + the cross-cluster synthesis back to the main thread; R-lens-verify the topRlensTargets surgically; then resolve each open question WITH the user in conversational co-design (not an options menu). Per "Delegation vs Co-Design": the workflow proposes; the human + main session decide + land.',
}
