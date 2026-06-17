# PReduce Autonomy — Handoff

**Rewritten at the end of every iteration. Read this SECOND (after CHARTER.md) at
the start of every iteration.**

---

## Current state (as of 2026-06-12, iteration 52 — PTF Track V CLOSED; **the loop is PAUSED awaiting owner review**)

**The viz arc is COMPLETE.** The owner's re-arm goal — a browser visualization
of the propagator network with execution playback for arbitrary prologos
programs — is DELIVERED pending the owner's browser acceptance:

- `racket tools/viz-export.rkt FILE.prologos -o out.json` → vizTrace/1 JSON
- `tools/viz/index.html` → open in any browser, drop the JSON, explore +
  play (epochs = per-command networks incl. SOLVER epochs; rounds = fired
  propagators + attributed cell diffs)
- Verified headlessly (`tools/viz/check.js` ALL PASS on the 3-file corpus);
  artifacts sent to the owner (iteration 51).

**Close artifacts**: PIR `docs/tracking/2026-06-12_PTF_TRACK2_PIR.md`
(16 questions + charter §9 autonomy retro); design doc tracker 10/10 ✅;
Master PTF section row **Track V** (naming collision with planned "Track 2:
Pipeline Detection" — disambiguated there); DEFERRED.md carries the 2
surviving riders; suite GREEN 8666/439 at close.

**Why paused (ledger iteration 52)**: the re-arm direction is satisfied;
the candidate next arcs are owner-sequencing calls — the same situation as
the original §8 halt. No hard stop fired; this is a deliberate pause.

## To re-arm the loop

Run the charter §7 kickoff one-liner (unchanged), optionally with a new goal
appended — exactly how this arc started. First iteration after re-arm:
re-read CHARTER → this file → the ledger tail, then take the owner's
sequencing ruling as the queue.

## The owner's review queue (in suggested order)

1. **Browser acceptance**: open the delivered index.html + envelopes (or
   regenerate: the two tools above). The relational-demo trace's relation
   epochs are the showcase.
2. LEDGER.md iterations 44–52 (decisions, incl. OWNER-PROVISIONAL push
   posture + the pause adjudication), then the PIR (esp. the autonomy retro
   + §16 longitudinal note).
3. **Flags needing owner rulings**: (a) 3 doc-vs-implementation drifts
   (syntax-doc map partials; bench-ab `--ref`; colon-form spec); (b) LSP
   prop-trace capture structurally dead (F7); (c) the PTF naming collision;
   (d) whether the deferred riders (component diffs; D7 depth) get
   scheduled; (e) the standing retro queue (a)-(e) from RETRO.md.

## Environment (for any future session in a fresh container)

`/home/user/prologos`, branch `claude/charming-archimedes-98yb48` (the
autonomy state; push = persistence). Setup recipe: install Racket 9.0
(`curl -sL -o /tmp/r.sh https://download.racket-lang.org/installers/9.0/racket-9.0-x86_64-linux-cs.sh
&& sudo sh /tmp/r.sh --unix-style --dest /usr/local --create-dir`), then
`raco pkg install --auto --skip-installed rackcheck`, `raco pkg install
--link --auto racket/prologos`, `raco make -j 4 driver.rkt` (in
racket/prologos). Full suite ~400s/4 cores; bench A/A noise floor 15.3%
(ledger iter 49); no Workflow runtime (use parallel Explore agents); no
PushNotification tool (final summaries are the doorbell); no GUI browser
(node headless checks + owner acceptance).

## Gate status at close

Suite 8666/439 ALL PASS (iter 49, post-production-edit; no production edits
since). Targeted: test-viz-export 7/7, test-propagator-bsp 21/21. Acceptance
file Level-3 clean. Corpus envelopes validate (monotone, captures==commands,
solver epochs present). check.js ALL PASS.
