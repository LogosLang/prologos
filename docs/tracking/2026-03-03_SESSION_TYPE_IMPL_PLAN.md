# Session Types: Phased Implementation Plan

**Date**: 2026-03-03
**Status**: Planning complete, ready for implementation
**Design Document**: `docs/tracking/2026-03-03_SESSION_TYPE_DESIGN.md` (Phase II)
**Predecessor**: `docs/research/2026-03-03_SESSION_TYPE_DESIGN_RESEARCH.md` (Phase I)

---

## Progress Tracker

| Phase | Sub-phase | Status | Commit | Notes |
|-------|-----------|--------|--------|-------|
| S1 | S1a: Surface syntax structs | ✅ | `4a42b38` | Combined with S2a |
| S1 | S1b: Reserved words | ✅ | `4f3c789` | 15 keywords |
| S1 | S1c: Sexp-mode parser | ✅ | `8cba95e` | 18 tests |
| S1 | S1d: WS-mode preparse | ✅ | `bc6a961` | 16 tests |
| S1 | S1e: Macro pass-through + grammar | ✅ | `56fe397` | Pass-through + dep-graph |
| S2 | S2a: Process surface structs | ✅ | `4a42b38` | Combined with S1a |
| S2 | S2b: Sexp-mode process parser | ✅ | `8c750b2` | 17 tests |
| S2 | S2c: WS-mode process preparse | ⏳ | `bc6a961` | Stub pass-through; full disambiguation deferred |
| S2 | S2d: Process macro pass-through | ✅ | `56fe397` | Combined with S1e |
| S3 | S3a: Session elaboration | ✅ | `79ced0d` | Session registry + elaborate-session-body |
| S3 | S3b: Process elaboration | ✅ | `79ced0d` | elaborate-proc-body + proc branches |
| S3 | S3c: `throws` desugaring | ⏳ | | Deferred: needs capability integration (S5) |
| S3 | S3d: Driver + pretty-printing | ✅ | `a15cb7f` `7a2d6e5` | 19 tests, pp-process, unannotated recv fix |
| S4 | S4a: Session lattice | ✅ | `c01182b` | sess-bot/top, session-lattice-merge, 26 tests |
| S4 | S4b: Session inference propagators | ✅ | `54c7c90` | send/recv/select/offer/stop propagators, 20 tests |
| S4 | S4c: Duality bidirectional prop | ✅ | `54c7c90` | add-duality-prop, proc-new compilation |
| S4 | S4d: ATMS integration | ✅ | `6383f1b` | session-op trace, session-protocol-error, 10 tests |
| S4 | S4e: Cross-domain bridges | ⏳ | | Deferred: needs deeper type↔session cell integration |
| S4 | S4f: Deadlock detection | ✅ | `2e244b1` | check-session-completeness, 9 tests |
| S5 | S5a: Capability binders | ☐ | | |
| S5 | S5b: Boundary operations | ☐ | | |
| S5 | S5c: Delegation + warnings | ☐ | | |
| S6 | S6a: Strategy parsing + registration | ☐ | | |
| S7 | S7a: Channel cells | ☐ | | |
| S7 | S7b: Process-to-propagator compilation | ☐ | | |
| S7 | S7c: End-to-end execution | ☐ | | |
| S7 | S7d: Strategy application | ☐ | | |
| S8 | S8a: `!!`/`??` operators | ☐ | | |
| S8 | S8b: Promise cells + `@` | ☐ | | |
| S8 | S8c: Integration tests | ☐ | | |

---

## Existing Infrastructure

**Production-ready — no changes needed (targets for elaboration):**

| Component | File | Lines | Content |
|-----------|------|-------|---------|
| Session AST | `sessions.rkt` | 117 | 9 constructors: sess-send/recv/dsend/drecv/choice/offer/mu/svar/end + sess-meta |
| Process AST | `processes.rkt` | 83 | 8 constructors: proc-stop/send/recv/sel/case/new/par/link + chan-ctx ops |
| Process typing | `typing-sessions.rkt` | 258 | 9 typing rules, Sprint 8 session meta inference, context splitting |
| Session metas | `metavar-store.rkt` | ~480 | fresh-sess-meta, solve-sess-meta!, zonk-session, zonk-session-default |
| Propagator net | `propagator.rkt` | 763 | Persistent/immutable network, cells, Gauss-Seidel + BSP schedulers |
| Type lattice | `type-lattice.rkt` | 404 | Pure structural unification, type-bot/type-top, try-unify-pure |
| ATMS | `atms.rkt` | 280 | Assumptions, nogoods, worldviews, amb, solve-all |
| Lattice traits | `lib/prologos/core/lattice.prologos` | 343 | Lattice/HasTop/BoundedLattice/Widenable/GaloisConnection traits |
| Redex models | `redex/sessions.rkt` + 2 | ~330 | Formal s-expression reference implementations |
| Tests | 3 files | 534 | 52 tests: duality, substitution, typing rules, meta inference |
| Grammar | `grammar.ebnf` | ~30 | S-expression session/process syntax (lines 1090-1120) |

**Pipeline pattern for new keywords** (traced from `schema`, `defr`, `subtype`):
1. `surface-syntax.rkt` → struct definition + struct-out in provides
2. `parser.rkt` → case in `parse-list` (~line 2589) + parse function
3. `macros.rkt` → `preparse-expand-all-impl` handler (~line 1503) + `expand-top-level` pass-through (~line 6987)
4. `elaborator.rkt` → `elaborate-top-level` match clause (~line 3217)
5. `driver.rkt` → `process-command` match clause (~line 391)

---

## Dependency Graph

```
S1 (Session Parsing) ──┐
                        ├──► S3 (Elaboration) ──► S4 (Type Checking) ──► S5 (Capabilities)
S2 (Process Parsing) ──┘          │                      │                      │
                                  │                      │                      │
                              S3c (throws)          S6 (Strategy) ─────────────┤
                                                         │                      │
                                                         └───► S7 (Runtime) ◄──┘
                                                                    │
                                                               S8 (Async)
```

- **S1 ∥ S2**: No dependency — can be developed in parallel
- **S3**: Depends on S1 + S2
- **S4**: Depends on S3
- **S5, S6**: Relatively independent after S4
- **S7**: Depends on S4 + S6
- **S8**: Depends on S7

---

## Phase S1: Session Type Parsing

**Goal**: Parse `session` declarations in WS mode and sexp mode → `surf-session` AST.
**Complexity**: Large — reader tokens already work, but preparse desugaring is non-trivial.

### S1a: Surface Syntax Structs

**File**: `racket/prologos/surface-syntax.rkt`

Add to provides (after line ~308) and define (after line ~1015):

```racket
;; Session declaration
(struct surf-session (name metadata body srcloc) #:transparent)

;; Session body nodes
(struct surf-sess-send   (type cont srcloc) #:transparent)       ; ! Type
(struct surf-sess-recv   (type cont srcloc) #:transparent)       ; ? Type
(struct surf-sess-dsend  (name type cont srcloc) #:transparent)  ; !: name Type
(struct surf-sess-drecv  (name type cont srcloc) #:transparent)  ; ?: name Type
(struct surf-sess-choice (branches srcloc) #:transparent)        ; +>
(struct surf-sess-offer  (branches srcloc) #:transparent)        ; &>
(struct surf-sess-branch (label cont srcloc) #:transparent)      ; | :label -> ...
(struct surf-sess-rec    (label body srcloc) #:transparent)      ; rec / rec Label
(struct surf-sess-var    (name srcloc) #:transparent)            ; recursion variable ref
(struct surf-sess-end    (srcloc) #:transparent)                 ; end
(struct surf-sess-shared (body srcloc) #:transparent)            ; shared
(struct surf-sess-ref    (name srcloc) #:transparent)            ; named session reference
```

**Commit**: After structs defined, compiles cleanly.

### S1b: Reserved Words

**File**: `racket/prologos/parser.rkt` (keywords list, line ~68)

Add to reserved keywords: `session`, `defproc`, `proc`, `stop`, `new`, `par`, `link`,
`select`, `offer`, `end`, `rec`, `shared`, `dual`, `strategy`, `spawn`.
Reserve but don't parse yet: `!!`, `??`, `!!:`, `??:`.

**Commit**: After reserved words added.

### S1c: Sexp-Mode Parser

**File**: `racket/prologos/parser.rkt`

1. Add dispatch in `parse-list` (after `defr` case, ~line 2589):
   ```racket
   [(session) (parse-session args loc)]
   ```

2. Implement `parse-session` + `parse-session-body` (recursive descent):
   - `(session Name (Send Type S))` → surf-sess-send
   - `(session Name (Recv Type S))` → surf-sess-recv
   - `(session Name (DSend (n : T) S))` → surf-sess-dsend
   - `(session Name (DRecv (n : T) S))` → surf-sess-drecv
   - `(session Name (Choice ((:l1 S1) ...)))` → surf-sess-choice
   - `(session Name (Offer ((:l1 S1) ...)))` → surf-sess-offer
   - `(session Name (Mu S))` → surf-sess-rec (anonymous)
   - `(session Name (Mu Label S))` → surf-sess-rec (named)
   - `(session Name End)` → surf-sess-end
   - `(session Name (SVar N))` → surf-sess-var

**Tests**: `tests/test-session-parse-01.rkt` (~15 tests) — sexp-mode parsing.
**Commit**: After sexp-mode parsing works.

### S1d: WS-Mode Preparse Desugaring

**File**: `racket/prologos/macros.rkt`

1. Add handler in `preparse-expand-all-impl` (after `defr` pattern, ~line 1503):
   ```racket
   [(and (pair? datum) (eq? head 'session))
    (auto-export-name! (cadr datum))
    (define desugared (desugar-session-ws datum))
    (cons (datum->syntax #f desugared stx) acc)]
   ```

2. Implement `desugar-session-ws` — the core WS→sexp transform:
   - WS reader produces: `(session Greeting (! String) (? String) end)`
   - Desugar to: `(session Greeting (Send String (Recv String End)))`
   - Handle `.` as explicit continuation splice
   - Handle `$pipe` children as branch syntax
   - Handle `->` chains in inline branches
   - Handle metadata keywords (`:doc`, `:deprecated`) — strip and pass through

   **Algorithm**: Process body items left-to-right, accumulating into right-nested
   continuation. Each operator (`!`, `?`, `!:`, `?:`, `+>`, `&>`, `rec`, `end`,
   `shared`, `.`) is recognized by its symbol head.

3. Handle inline vs indentation branch forms:
   - Indentation: `(+> ($pipe (:inc) (! Nat) rec) ($pipe (:done) end))`
   - Inline: `(+> ($pipe (:inc) (-> (! Nat) (-> rec))) ($pipe (:done) (-> end)))`

**Tests**: `tests/test-session-parse-02.rkt` (~25 tests) — WS-mode via `process-string`.
Cover: basic send/recv/end, choice/offer branches (indentation + inline), recursion
(anonymous + named), dependent ops (`!:`/`?:`), dot separator, metadata, shared, session refs.

**Commit**: After WS-mode desugaring works.

### S1e: Macro Pass-Through + Grammar Update

**Files**:
- `macros.rkt` — `expand-top-level` (~line 6987): add `[(surf-session? surf) surf]`
- `docs/spec/grammar.ebnf` — add WS-mode session rules alongside existing sexp rules
- `docs/spec/grammar.org` — update prose companion

**Commit**: After pass-through + grammar.

---

## Phase S2: Process Parsing

**Goal**: Parse `defproc`/`proc` declarations → `surf-defproc`/`surf-proc` AST.
**Complexity**: Large — `defproc` body has context-sensitive operator disambiguation.
**Parallel with**: S1 (no dependency between S1 and S2).

### S2a: Surface Syntax Structs for Processes

**File**: `racket/prologos/surface-syntax.rkt`

```racket
;; Process declarations
(struct surf-defproc (name session-type channels caps body srcloc) #:transparent)
(struct surf-proc    (session-type channels caps body srcloc) #:transparent)
(struct surf-dual    (session-ref srcloc) #:transparent)

;; Process body nodes
(struct surf-proc-send    (chan expr cont srcloc) #:transparent)   ; chan ! expr
(struct surf-proc-recv    (var chan cont srcloc) #:transparent)    ; var := chan ?
(struct surf-proc-select  (chan label cont srcloc) #:transparent)  ; select chan :label
(struct surf-proc-offer   (chan branches srcloc) #:transparent)    ; offer chan | ...
(struct surf-proc-offer-branch (label body srcloc) #:transparent) ; | :label -> body
(struct surf-proc-stop    (srcloc) #:transparent)                 ; stop
(struct surf-proc-new     (channels session-type body srcloc) #:transparent)
(struct surf-proc-par     (left right srcloc) #:transparent)      ; par P1 P2
(struct surf-proc-link    (chan1 chan2 srcloc) #:transparent)      ; link c1 c2
(struct surf-proc-rec     (label srcloc) #:transparent)           ; rec (tail recursion)
```

**Commit**: After structs compile.

### S2b: Sexp-Mode Parser for Processes

**File**: `racket/prologos/parser.rkt`

1. Dispatch: `[(defproc) (parse-defproc args loc)]`, `[(proc) (parse-proc args loc)]`,
   `[(dual) (parse-dual args loc)]`
2. `parse-defproc`: name, session type (after `:`), optional multi-channel `[...]`,
   optional caps `{...}`, body via `parse-proc-body`
3. `parse-proc-body` (recursive descent on sexp forms):
   - `(proc-send chan expr P)` → surf-proc-send
   - `(proc-recv chan Type P)` → surf-proc-recv
   - `(proc-sel chan :label P)` → surf-proc-select
   - `(proc-case chan ((:l1 P1) ...))` → surf-proc-offer
   - `(proc-stop)` → surf-proc-stop
   - `(proc-new Session (proc-par P1 P2))` → surf-proc-new + surf-proc-par
   - `(proc-par P1 P2)` → surf-proc-par
   - `(proc-link c1 c2)` → surf-proc-link

**Tests**: `tests/test-process-parse-01.rkt` (~15 tests).
**Commit**: After sexp-mode process parsing.

### S2c: WS-Mode Preparse for Processes

**File**: `racket/prologos/macros.rkt`

1. Handler in `preparse-expand-all-impl`:
   ```racket
   [(and (pair? datum) (eq? head 'defproc))
    (auto-export-name! (cadr datum))
    (define desugared (desugar-defproc-ws datum))
    (cons (datum->syntax #f desugared stx) acc)]
   ```

2. `desugar-defproc-ws`:
   - Parse header: `defproc name : SessionType` or `defproc name [ch : S, ...]`
   - Parse optional `{cap :0 CapType, ...}` capability binders
   - Process body items sequentially → right-nested proc-* sexp:
     - `(self ! expr)` or `(chan ! expr)` → `(proc-send chan expr ...cont...)`
     - `(var := chan ?)` → `(proc-recv chan Type ...cont...)` — `:=` combined with `?`
     - `(select chan :label)` → `(proc-sel chan :label ...cont...)`
     - `(offer chan ...)` → `(proc-case chan ((...) ...))`
     - `stop` → `(proc-stop)`
     - `(new [c1 c2] : S ...)` → `(proc-new S (proc-par ...))`
     - `(par P1 P2)` → `(proc-par ...)`
     - `(link c1 c2)` → `(proc-link c1 c2)`
     - `rec` → tail recursion marker

   **Key disambiguation**: Inside `defproc` body, `!`/`?` after a channel name are session
   operators. The preparse detects `defproc` head and enters process-body desugaring mode
   (analogous to `current-parsing-relational-goal?` for `defr` at parser.rkt line 27).

3. Handle implicit `self`: When single session type (not bracket list), all bare `! expr`
   and `var := ?` are desugared with `self` as channel.

**Tests**: `tests/test-process-parse-02.rkt` (~25 tests) — WS-mode `process-string`.
**Commit**: After WS-mode process parsing.

### S2d: Macro Pass-Through + Grammar

- `expand-top-level`: `[(surf-defproc? surf) surf]`, `[(surf-proc? surf) surf]`
- Grammar files: add process rules.

**Commit**: After pass-through + grammar.

---

## Phase S3: Elaboration

**Goal**: surf-session → sess-\*, surf-defproc/surf-proc → proc-\*. Driver integration.
**Complexity**: Medium-Large.
**Dependencies**: S1 + S2 complete.

### S3a: Session Declaration Elaboration

**Files**:
- `racket/prologos/elaborator.rkt` — `elaborate-top-level` (~line 3217)
- `racket/prologos/macros.rkt` — session registry (new, modeled on `current-schema-registry`)

1. Session registry in macros.rkt:
   ```racket
   (define current-session-registry (make-parameter (hasheq)))
   (struct session-entry (name session-type srcloc) #:transparent)
   ```
2. `elaborate-top-level` clause for `surf-session`:
   - Extract name, metadata
   - `elaborate-session-body` → sess-\* tree
   - Register in session registry
   - Return `(list 'session name sess-tree)`
3. `elaborate-session-body` (recursive):
   - surf-sess-send → `(sess-send (elaborate type) (elab-session-body cont))`
   - surf-sess-recv → `(sess-recv (elaborate type) (elab-session-body cont))`
   - surf-sess-dsend → `(sess-dsend (elaborate type) (elab-session-body cont))`
     with de Bruijn binding for name (push onto binding stack)
   - surf-sess-drecv → `(sess-drecv (elaborate type) (elab-session-body cont))`
   - surf-sess-choice → `(sess-choice (map elab-branch branches))`
   - surf-sess-offer → `(sess-offer (map elab-branch branches))`
   - surf-sess-rec (anon) → `(sess-mu (elab-session-body body))` (push rec onto stack)
   - surf-sess-rec (named) → same, register label→depth mapping
   - surf-sess-var → `(sess-svar depth)` (de Bruijn from label stack)
   - surf-sess-end → `(sess-end)`
   - surf-sess-shared → annotate `:w` multiplicity
   - surf-sess-ref → lookup in session registry, return

   **Named recursion**: Maintain label stack. `rec Loop` pushes `Loop` at depth 0.
   Reference to `Loop` in a branch resolves to `(sess-svar (current-depth - loop-depth))`.

**Tests**: `tests/test-session-elaborate-01.rkt` (~15 tests).
**Commit**: After session elaboration works.

### S3b: Process Elaboration

**File**: `racket/prologos/elaborator.rkt`

1. `elaborate-top-level` clause for `surf-defproc`:
   - Elaborate session type annotation (or look up from session registry)
   - Elaborate capability binders (structure only; checking in S5)
   - `elaborate-proc-body` → proc-\* tree
   - Return `(list 'defproc name sess-type channels caps proc-tree)`
2. `elaborate-proc-body` (recursive):
   - surf-proc-send → `(proc-send (elaborate expr) chan (elab-proc-body cont))`
   - surf-proc-recv → `(proc-recv chan (elaborate type) (elab-proc-body cont))`
   - surf-proc-select → `(proc-sel chan label (elab-proc-body cont))`
   - surf-proc-offer → `(proc-case chan (map elab-proc-branch branches))`
   - surf-proc-stop → `(proc-stop)`
   - surf-proc-new → `(proc-new sess-type (proc-par (elab p1) (elab p2)))`
   - surf-proc-par → `(proc-par (elab left) (elab right))`
   - surf-proc-link → `(proc-link c1 c2)`
3. Handle `surf-dual`: lookup session, apply `dual` from `sessions.rkt`.
4. Handle implicit `self`: single-channel → channel name is `'self`.

**Tests**: `tests/test-process-elaborate-01.rkt` (~15 tests).
**Commit**: After process elaboration works.

### S3c: `throws` Desugaring

**File**: `racket/prologos/elaborator.rkt` (in `elaborate-session-body`)

Detect `throws ErrorType` in session metadata. During elaboration, at each protocol step,
wrap in `sess-offer` with error branch:
- Original step `S` becomes `(sess-offer ((:ok S) (:error (sess-send ErrorType (sess-end)))))`

**Tests**: ~5 tests added to `test-session-elaborate-01.rkt`.
**Commit**: After throws desugaring.

### S3d: Driver Integration + Pretty-Printing

**Files**:
- `racket/prologos/driver.rkt` — `process-command` (~line 391)
- `racket/prologos/pretty-print.rkt` — session/process rendering

1. Driver match clause for `(list 'session name sess-type)`:
   - Register session name in `global-env` as a type-level binding
   - Qualify with namespace if applicable
   - Print `"session Name defined."`

2. Driver match clause for `(list 'defproc name sess-type channels caps proc-tree)`:
   - Build channel context: `chan-ctx-add` for each channel with its session type
   - Build unrestricted context: `gamma` with function-level bindings
   - Call `type-proc gamma delta proc-tree` from `typing-sessions.rkt`
   - Report success/failure with source locations
   - Register in global-env

3. Pretty-printing:
   - `pp-session`: Render sess-\* tree as `! String . ? String . end`
   - `pp-process`: Render proc-\* tree as readable process body
   - Add cases in existing `pp-expr` for session/process references

**Tests**: `tests/test-session-e2e-01.rkt` (~20 tests) — full `process-string` pipeline.
**Commit**: After end-to-end pipeline works.

---

## Phase S4: Session Type Checking on Propagator Network

**Goal**: Upgrade from simple `type-proc` judgment to propagator-based inference with
SessionLattice, duality propagators, ATMS derivations, and cross-domain bridges.
**Complexity**: Very Large — the deepest phase.
**Dependencies**: S3 complete.

### S4a: Session Lattice

**New file**: `racket/prologos/session-lattice.rkt` (~200 lines)
Modeled after `type-lattice.rkt`.

1. Sentinels: `session-bot` (⊥, no info), `session-top` (⊤, contradiction)
2. `session-lattice-merge(s1, s2)`:
   - bot handling, identity
   - Structural: Send+Send → merge types + merge continuations
   - Send+Recv → contradiction (session-top)
   - Choice+Choice → intersect labels (covariant)
   - Offer+Offer → union labels (contravariant)
   - Mu+Mu → merge bodies
   - End+End → End
   - Incompatible shapes → session-top
3. `session-lattice-contradicts?`: check for session-top
4. `try-unify-session-pure(s1, s2)`: Pure structural session unification (no side effects)
5. Subtyping (Gay & Hole): covariant output, contravariant input, label rules

**Tests**: `tests/test-session-lattice-01.rkt` (~20 tests).
**Commit**: After session lattice.

### S4b: Session Inference Propagators

**New file**: `racket/prologos/session-propagators.rkt` (~300 lines)

1. `make-session-cell(net, initial-session)`: Cell with `session-lattice-merge`
2. Process operation propagators (pure functions, return augmented network):
   - `add-send-prop(net, sess-cell, type-cell)`: Constrain to Send(T, S), bridge T to type-cell
   - `add-recv-prop(net, sess-cell, type-cell)`: Constrain to Recv(T, S)
   - `add-select-prop(net, sess-cell, label)`: Constrain to Choice with label
   - `add-offer-prop(net, sess-cell, labels)`: Constrain to Offer, return branch cells
   - `add-stop-prop(net, sess-cell)`: Constrain to End
3. `compile-proc-to-network(net, proc-tree, channel-cells)`:
   Walk proc-\* tree, add propagators for each operation
4. `check-session-via-propagators(proc-tree, session-type)`:
   - Create network, create session cell initialized with declared type
   - Compile process, `run-to-quiescence`
   - Check contradictions → error or success

**Tests**: `tests/test-session-propagators-01.rkt` (~25 tests).
Port existing tests from `test-typing-sessions.rkt` to verify equivalence.
**Commit**: After propagator-based session checking.

### S4c: Duality Bidirectional Propagator

**File**: `racket/prologos/session-propagators.rkt`

1. `add-duality-prop(net, cell1, cell2)`:
   - Watches cell1 → writes `dual(value)` to cell2
   - Watches cell2 → writes `dual(value)` to cell1
2. Wire into `proc-new` compilation: `new [c1 c2] : S` creates cells, adds duality prop

**Tests**: ~10 tests added to `test-session-propagators-01.rkt`.
**Commit**: After duality propagator.

### S4d: ATMS Integration for Error Derivations

**Files**: `session-propagators.rkt`, `driver.rkt`

1. Each process operation creates an ATMS assumption with source location
2. Session lattice contradictions → ATMS derivation chain (minimal conflict set)
3. Format error messages:
   ```
   Protocol violation at line 42:
     Channel self was inferred as (Send String . End) because:
       - self ! "hello"    [line 10, assumption A1]
       - self ! "world"    [line 11, assumption A2]  ← second send past End
     Minimal conflict: {A1, A2}
   ```

**Tests**: `tests/test-session-errors-01.rkt` (~10 tests).
**Commit**: After ATMS-traced session errors.

### S4e: Cross-Domain Bridges

**File**: `racket/prologos/session-propagators.rkt`

1. **Session ↔ Type**: Message types create type-lattice cells, bridged to session cells.
   When sess-cell refines to Send(T, S), T propagates to the expression type cell
2. **Session ↔ QTT**: Channel multiplicity (:1 default, :w shared) constrains QTT.
   Linear channels used once per step → QTT verifies at compile time
3. **Dependent session bridge** (design doc §15.7): `!:`/`?:` create bidirectional
   type↔session constraints. When `?: n Nat` fires, creates type cell `cell(n) : Nat`;
   continuation `? Vec String n` uses cell(n) for instantiation

**Tests**: `tests/test-session-bridges-01.rkt` (~15 tests).
**Commit**: After cross-domain bridges.

### S4f: Deadlock Detection

**File**: `racket/prologos/session-propagators.rkt`

1. After quiescence: check for session cells NOT at End with no pending propagators
2. Unresolved choice cells (⊥) = potential deadlock (§10.6 choice-as-cell-write)
3. Report with source locations

**Tests**: `tests/test-session-deadlock-01.rkt` (~8 tests).
**Commit**: After deadlock detection.

---

## Phase S5: Capability Integration

**Goal**: `{cap :0 CapType}` on process headers, boundary operations, delegation.
**Complexity**: Medium.
**Dependencies**: S4 complete.

### S5a: Capability Binders on Process Headers

**Files**: `elaborator.rkt`, `session-propagators.rkt`

1. Elaborate `{cap :0 CapType}` to erased binders in typing context (gamma)
2. Verify capability usage during session checking — capabilities gate `open`/`connect`/`listen`
3. Integrate with existing capability model from `CAPABILITY_SECURITY.md`

**Tests**: `tests/test-session-caps-01.rkt` (~10 tests).
**Commit**: After capability binders.

### S5b: Boundary Operations

**Files**: surface-syntax.rkt, parser.rkt, elaborator.rkt

1. Parse `open path : Session {cap}`, `connect addr : Session {cap}`, `listen port : Session {cap}`
2. Elaborate with capability check
3. Return channel endpoints (same as `new` but with capability gate)

**Note**: Actual I/O deferred to S7. This phase establishes the type-level plumbing.

**Tests**: ~10 tests.
**Commit**: After boundary operation types.

### S5c: Delegation and Warnings

1. Linear capability transfer: `!: cap CapType :1` — QTT consumes sent capability
2. Compiler warnings: dead authority, ambient authority, unattenuated pass-through

**Tests**: ~15 tests.
**Commit**: After delegation + warnings.

---

## Phase S6: Strategy Declaration

**Goal**: Parse `strategy`, register, apply at spawn time.
**Complexity**: Small-Medium.
**Dependencies**: Can proceed after S4.

### S6a: Strategy Parsing and Registration

**Files**: surface-syntax.rkt, parser.rkt, macros.rkt, elaborator.rkt, driver.rkt

1. `(struct surf-strategy (name properties srcloc) #:transparent)`
2. Parse: `(strategy name :fairness :round-robin :fuel 50000 :io :nonblocking)`
3. WS preparse: keyword-block desugaring (reuses implicit map syntax pattern)
4. Registry (modeled on solver registry, macros.rkt line 1511):
   ```racket
   (define current-strategy-registry (make-parameter (hasheq)))
   ```
5. Default strategy auto-registered
6. Parse `spawn proc :strategy name` (modifier on spawn)

> **Note**: Strategy vocabulary (`:fairness`, `:fuel`, `:io`, `:parallelism`) is
> provisional (design doc §11 note). Property names may be refined during implementation.

**Tests**: `tests/test-strategy-01.rkt` (~10 tests).
**Commit**: After strategy parsing + registration.

---

## Phase S7: Runtime Execution (Propagator-as-Scheduler)

**Goal**: Compile processes to live propagator networks. Channel cells for message passing.
Execute via `run-to-quiescence`.
**Complexity**: Very Large.
**Dependencies**: S4 + S6.

### S7a: Channel Cells

**New file**: `racket/prologos/session-runtime.rkt` (~400+ lines)

1. Channel cell structure:
   - `channel-out` (outgoing message cell)
   - `channel-in` (incoming message cell)
   - `channel-session` (current session state cell)
   - `channel-choice` (for choice resolution — monotonic flat lattice, §10.6)
2. Channel pair creation: cross-wired propagators (A's out → B's in, B's out → A's in)
3. Message lattice: flat (⊥ → value, written once per step)

**Tests**: `tests/test-session-runtime-01.rkt` (~10 tests).
**Commit**: After channel cells.

### S7b: Process-to-Propagator Compilation

**File**: `racket/prologos/session-runtime.rkt`

1. `compile-live-process(net, proc-tree, channel-cells)`:
   - proc-send: Write value to channel-out, advance session
   - proc-recv: Watch channel-in, bind value, advance session
   - proc-sel: Write label to choice cell (§10.6 choice-as-cell-write)
   - proc-case: Guarded propagator watching choice cell
   - proc-stop: Assert End
   - proc-new: Create channel pair, compile sub-processes
   - proc-par: Compile both sides
   - proc-link: Forward propagator

**Tests**: `tests/test-session-runtime-02.rkt` (~25 tests).
**Commit**: After process compilation.

### S7c: End-to-End Execution

1. `run-session`: Create network, compile processes, apply strategy, `run-to-quiescence`
2. Wire into driver for `spawn` / direct process execution
3. Handle `stop` properly (verify all channels at End)

**Tests**: `tests/test-session-runtime-03.rkt` (~20 tests).
**Commit**: After end-to-end execution.

### S7d: Strategy Application

1. Apply `:fuel` to `run-to-quiescence` fuel parameter
2. Apply `:fairness` to propagator scheduling order
3. Apply `:io` to IO-bridge propagator behavior
4. `spawn proc :strategy name` at use site

**Tests**: ~8 tests added to runtime tests.
**Commit**: After strategy application.

---

## Phase S8: Async Extension (Future)

**Goal**: `!!`/`??`, promise cells, `@` deref, `@>` pipeline.
**Dependencies**: S7.

### S8a: `!!`/`??` Operators

Parse, elaborate, runtime: non-blocking send/recv. Send writes to cell and continues
immediately. Recv returns a promise cell.

### S8b: Promise Cells and `@`

1. `@` prefix reader operator (new reader token)
2. Promise cell type: cell that blocks until value arrives
3. `@p` → propagator that watches promise cell, blocks until resolved
4. `@@p` → recursive deref
5. `@>` → pipeline resolution

### S8c: Integration Tests

~20 tests for async behavior.

---

## Cross-Cutting Concerns

### Dep-Graph Updates

After each phase, update `tools/dep-graph.rkt`:
- Existing entries (lines 68, 98-100, 149-187) cover sessions.rkt, processes.rkt,
  typing-sessions.rkt and their tests
- New entries needed for: session-lattice.rkt, session-propagators.rkt, session-runtime.rkt
  and all new test files

### Grammar Files

After S1 and S2, update:
- `docs/spec/grammar.ebnf` — WS-mode session/process rules
- `docs/spec/grammar.org` — prose companion with examples

### Test Count Projection

| Phase | New Tests | Cumulative (from 4632) |
|-------|-----------|------------------------|
| S1    | ~40       | ~4672                  |
| S2    | ~40       | ~4712                  |
| S3    | ~55       | ~4767                  |
| S4    | ~88       | ~4855                  |
| S5    | ~35       | ~4890                  |
| S6    | ~10       | ~4900                  |
| S7    | ~63       | ~4963                  |
| S8    | ~20       | ~4983                  |

### Whale File Check

After each test-heavy phase, run `racket tools/benchmark-tests.rkt --slowest 10`.
Split any test file >30s wall time.

---

## Verification Strategy

After each sub-phase commit:
1. `raco make racket/prologos/driver.rkt` — compilation check
2. `racket tools/run-affected-tests.rkt` — targeted tests for changed files
3. After each phase (S1, S2, etc.): `racket tools/run-affected-tests.rkt --all` — full suite

After S3d (end-to-end pipeline): test with real `.prologos` programs:
```prologos
ns test-session

session Greeting
  ! String
  ? String
  end

defproc greeter : Greeting
  self ! "hello"
  name := self ?
  stop
```

After S7c (runtime): test process execution:
```prologos
ns test-session-run

session Counter
  rec
    +>
      | :inc -> ! Nat -> rec
      | :done -> end
```

---

## Critical Files Reference

| File | Role | Phases |
|------|------|--------|
| `racket/prologos/surface-syntax.rkt` | ~30 new surf-\* structs | S1a, S2a |
| `racket/prologos/parser.rkt` | Keyword dispatch, parse functions | S1b-c, S2b |
| `racket/prologos/macros.rkt` | WS preparse, expand-top-level, registries | S1d-e, S2c-d, S3a, S6a |
| `racket/prologos/elaborator.rkt` | surf→sess/proc elaboration | S3a-d |
| `racket/prologos/driver.rkt` | Command processing, type checking calls | S3d, S4d, S7c |
| `racket/prologos/sessions.rkt` | Existing sess-\* constructors (elaboration target) | read-only in S3 |
| `racket/prologos/processes.rkt` | Existing proc-\* constructors (elaboration target) | read-only in S3 |
| `racket/prologos/typing-sessions.rkt` | Existing type-proc judgment | S3d (call), S4b (upgrade) |
| `racket/prologos/session-lattice.rkt` | **NEW**: Session type lattice | S4a |
| `racket/prologos/session-propagators.rkt` | **NEW**: Session inference propagators | S4b-f |
| `racket/prologos/session-runtime.rkt` | **NEW**: Runtime execution propagators | S7a-d |
| `racket/prologos/propagator.rkt` | Existing propagator network | read in S4, S7 |
| `racket/prologos/type-lattice.rkt` | Existing type lattice | read in S4e |
| `racket/prologos/atms.rkt` | Existing ATMS | read in S4d |
| `racket/prologos/pretty-print.rkt` | Session/process rendering | S3d |
| `tools/dep-graph.rkt` | Test dependency graph | all phases |
| `docs/spec/grammar.ebnf` | Formal grammar | S1e, S2d |
| `docs/spec/grammar.org` | Grammar prose | S1e, S2d |
