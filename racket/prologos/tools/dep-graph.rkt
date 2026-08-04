#lang racket/base

;; dep-graph.rkt — Three-layer dependency DAG for targeted test running
;;
;; Layer 1: Source .rkt module forward-deps (module → modules it requires)
;; Layer 2: Test → source module deps (test → source modules it requires)
;; Layer 3: .prologos library forward-deps (lib → libs it requires)
;;
;; Plus: reverse-dep computation and affected-test-set algorithm.

(require racket/file racket/hash racket/list racket/path
         racket/port racket/set racket/string)

(provide compute-affected-tests
         all-test-files
         ;; Data exports for update-deps validation
         source-deps
         test-deps
         prologos-lib-deps
         test-prologos-deps
         example-test-map
         ;; Struct exports
         (struct-out test-dep)
         ;; Change classification
         (struct-out changed-source)
         (struct-out changed-test)
         (struct-out changed-prologos)
         (struct-out changed-example)
         ;; Scanning functions (shared with update-deps.rkt)
         scan-rkt-requires
         scan-test-source-deps
         scan-test-prologos-deps
         scan-prologos-requires
         test-uses-driver?)

;; ============================================================
;; Change classification structs
;; ============================================================

(struct changed-source  (name) #:transparent)   ; symbol like 'syntax.rkt
(struct changed-test    (name) #:transparent)   ; symbol like 'test-parser.rkt
(struct changed-prologos (name) #:transparent)  ; symbol like 'prologos::data::nat
(struct changed-example (name) #:transparent)   ; symbol like 'hello.rkt

;; ============================================================
;; Layer 1: Source module forward-deps
;; Keys: bare filename symbols (e.g., 'syntax.rkt)
;; Values: list of filename symbols this module requires
;; ============================================================

(define source-deps
  (hasheq
   'atms.rkt                      '(decision-cell.rkt propagator.rkt)
   'bb-optimization.rkt           '(interval-domain.rkt syntax.rkt)
   'bilattice.rkt                 '(propagator.rkt)
   'cap-type-bridge.rkt           '(capability-inference.rkt global-env.rkt macros.rkt propagator.rkt syntax.rkt type-lattice.rkt)
   'capability-inference.rkt      '(atms.rkt champ.rkt global-env.rkt macros.rkt pretty-print.rkt prop-observatory.rkt propagator.rkt syntax.rkt)
   'cell-ops.rkt                  '(champ.rkt elab-network-types.rkt infra-cell.rkt propagator.rkt)
   'cfa-analysis.rkt              '(definitional-tree.rkt global-env.rkt macros.rkt syntax.rkt)
   'champ.rkt                     '()
   'classify-inhabit.rkt          '(merge-fn-registry.rkt sre-core.rkt type-lattice.rkt)
   'clock.rkt                     '(decision-cell.rkt merge-fn-registry.rkt propagator.rkt sre-core.rkt)
   'confluence-analysis.rkt       '(definitional-tree.rkt syntax.rkt)
   'constraint-cell.rkt           '()
   'constraint-propagators.rkt    '(constraint-cell.rkt global-env.rkt macros.rkt merge-fn-registry.rkt propagator.rkt sre-core.rkt syntax.rkt)
   'crypto-ffi.rkt                '()
   'ctor-registry.rkt             '(mult-lattice.rkt sessions.rkt syntax.rkt term-lattice.rkt)
   'decision-cell.rkt             '()
   'definition-entry.rkt          '()
   'definitional-tree.rkt         '(macros.rkt syntax.rkt)
   'derivation-chain-types.rkt    '()
   'driver.rkt                    '(atms.rkt cap-type-bridge.rkt capability-inference.rkt champ.rkt ctor-registry.rkt definition-entry.rkt effect-executor.rkt elab-speculation-bridge.rkt elaborator-network.rkt elaborator.rkt errors.rkt foreign.rkt form-cells.rkt global-constraints.rkt global-env.rkt infra-cell-sre-registrations.rkt macros.rkt meta-universe.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt narrowing.rkt parse-reader.rkt parser.rkt performance-counters.rkt phase1d-registrations.rkt pnet-serialize.rkt prelude.rkt pretty-print.rkt processes.rkt prop-observatory.rkt propagator.rkt qtt.rkt reduction.rkt relations.rkt resolution.rkt rrb.rkt session-runtime.rkt sessions.rkt sexp-readtable.rkt source-location.rkt sre-core.rkt stratified-eval.rkt surface-rewrite.rkt surface-syntax.rkt syntax.rkt term-lattice.rkt trait-resolution.rkt tree-parser.rkt type-lattice.rkt typing-core.rkt typing-errors.rkt typing-propagators.rkt typing-sessions.rkt unify.rkt warnings.rkt zonk.rkt)
   'effect-bridge.rkt             '(effect-position.rkt propagator.rkt session-lattice.rkt sessions.rkt)
   'effect-executor.rkt           '(effect-ordering.rkt effect-position.rkt io-bridge.rkt pretty-print.rkt processes.rkt propagator.rkt session-lattice.rkt session-runtime.rkt sessions.rkt syntax.rkt)
   'effect-ordering.rkt           '(effect-position.rkt processes.rkt propagator.rkt sessions.rkt syntax.rkt)
   'effect-position.rkt           '(sessions.rkt)
   'elab-network-types.rkt        '(champ.rkt propagator.rkt)
   'elab-speculation-bridge.rkt   '(atms.rkt elaborator-network.rkt metavar-store.rkt performance-counters.rkt propagator.rkt)
   'elaborator-network.rkt        '(champ.rkt ctor-registry.rkt decision-cell.rkt elab-network-types.rkt merge-fn-registry.rkt meta-universe.rkt mult-lattice.rkt prelude.rkt propagator.rkt sre-core.rkt syntax.rkt type-lattice.rkt)
   'elaborator.rkt                '(champ.rkt errors.rkt foreign.rkt global-constraints.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt performance-counters.rkt posit-impl.rkt prelude.rkt pretty-print.rkt processes.rkt sessions.rkt sign-refinement.rkt solver.rkt source-location.rkt substitution.rkt surface-syntax.rkt syntax.rkt typing-core.rkt warnings.rkt)
   'error-explanation.rkt         '(atms.rkt champ.rkt decision-cell.rkt derivation-chain-types.rkt elab-speculation-bridge.rkt propagator.rkt)
   'errors.rkt                    '(derivation-chain-types.rkt source-location.rkt)
   'field-witness.rkt             '(champ.rkt macros.rkt rrb.rkt syntax.rkt)
   'float-impl.rkt                '()
   'foreign.rkt                   '(posit-impl.rkt syntax.rkt)
   'form-cells.rkt                '(ctor-registry.rkt elab-network-types.rkt elaborator-network.rkt errors.rkt infra-cell.rkt macros.rkt parse-reader.rkt parser.rkt rrb.rkt source-location.rkt sre-core.rkt surface-rewrite.rkt surface-syntax.rkt tree-parser.rkt)
   'global-constraints.rkt        '(infra-cell.rkt interval-domain.rkt metavar-store.rkt propagator.rkt syntax.rkt)
   'global-env.rkt                '(definition-entry.rkt infra-cell.rkt namespace.rkt)
   'hasse-registry.rkt            '(merge-fn-registry.rkt propagator.rkt sre-core.rkt)
   'inductive.rkt                 '(syntax.rkt typing-core.rkt)
   'infra-cell-sre-registrations.rkt '(infra-cell.rkt merge-fn-registry.rkt propagator.rkt sre-core.rkt)
   'infra-cell.rkt                '(atms.rkt champ.rkt propagator.rkt)
   'interval-domain.rkt           '()
   'io-bridge.rkt                 '(propagator.rkt sessions.rkt syntax.rkt)
   'io-ffi.rkt                    '()
   'keyword-ops.rkt               '(syntax.rkt)
   'lang-error.rkt                '(errors.rkt source-location.rkt)
   'loose-bvar.rkt                '(syntax.rkt)
   'macros.rkt                    '(errors.rkt global-env.rkt infra-cell.rkt metavar-store.rkt namespace.rkt propagator.rkt reader-forms.rkt source-location.rkt surface-syntax.rkt syntax.rkt warnings.rkt)
   'merge-fn-registry.rkt         '()
   'meta-universe.rkt             '(decision-cell.rkt elab-network-types.rkt hasse-registry.rkt propagator.rkt)
   'metavar-store.rkt             '(cell-ops.rkt champ.rkt decision-cell.rkt global-env.rkt infra-cell.rkt meta-universe.rkt namespace.rkt performance-counters.rkt prelude.rkt propagator.rkt sessions.rkt source-location.rkt syntax.rkt)
   'mult-lattice.rkt              '()
   'multi-dispatch.rkt            '()
   'namespace.rkt                 '(definition-entry.rkt infra-cell.rkt propagator.rkt)
   'narrowing-abstract.rkt        '(definitional-tree.rkt interval-domain.rkt syntax.rkt)
   'narrowing.rkt                 '(bb-optimization.rkt cfa-analysis.rkt champ.rkt confluence-analysis.rkt definitional-tree.rkt global-constraints.rkt global-env.rkt interval-domain.rkt macros.rkt narrowing-abstract.rkt propagator.rkt rrb.rkt search-heuristics.rkt syntax.rkt term-lattice.rkt termination-analysis.rkt)
   'observatory-serialize.rkt     '(champ.rkt prop-observatory.rkt propagator.rkt trace-serialize.rkt)
   'ocapn-conn-ffi.rkt            '()
   'ocapn-dial-ffi.rkt            '()
   'ocapn-enliven-ffi.rkt         '()
   'ocapn-frame-ffi.rkt           '()
   'ocapn-gift-ffi.rkt            '()
   'ocapn-give-ffi.rkt            '()
   'ocapn-handoff-ffi.rkt         '()
   'ocapn-identity-ffi.rkt        '()
   'ocapn-peer-ffi.rkt            '()
   'parse-bridges.rkt             '(parse-lattice.rkt)
   'parse-lattice.rkt             '()
   'parse-reader.rkt              '(parse-lattice.rkt propagator.rkt reader-forms.rkt rrb.rkt)
   'parser.rkt                    '(errors.rkt global-env.rkt macros.rkt pretty-print.rkt reader-forms.rkt sexp-readtable.rkt source-location.rkt surface-syntax.rkt syntax.rkt)
   'path-ops.rkt                  '(syntax.rkt)
   'performance-counters.rkt      '()
   'phase1d-registrations.rkt     '(atms.rkt capability-inference.rkt decision-cell.rkt definition-entry.rkt effect-position.rkt io-bridge.rkt merge-fn-registry.rkt mult-lattice.rkt parse-lattice.rkt parse-reader.rkt relations.rkt session-lattice.rkt session-runtime.rkt sre-core.rkt tabling.rkt term-lattice.rkt type-lattice.rkt typing-propagators.rkt)
   'pnet-serialize.rkt            '(champ.rkt elab-network-types.rkt foreign.rkt global-env.rkt macros.rkt multi-dispatch.rkt namespace.rkt prelude.rkt propagator.rkt rrb.rkt source-location.rkt syntax.rkt)
   'posit-impl.rkt                '()
   'prelude.rkt                   '()
   'pretty-print.rkt              '(atms.rkt champ.rkt metavar-store.rkt posit-impl.rkt prelude.rkt processes.rkt propagator.rkt rrb.rkt sessions.rkt syntax.rkt tabling.rkt union-find.rkt)
   'processes.rkt                 '(sessions.rkt)
   'prop-observatory.rkt          '(champ.rkt propagator.rkt)
   'propagator.rkt                '(champ.rkt decision-cell.rkt merge-fn-registry.rkt performance-counters.rkt source-location.rkt tropical-fuel-primitives.rkt)
   'provenance.rkt                '()
   'qtt.rkt                       '(elab-speculation-bridge.rkt global-env.rkt merge-fn-registry.rkt metavar-store.rkt prelude.rkt reduction.rkt sign-refinement.rkt sre-core.rkt substitution.rkt syntax.rkt typing-core.rkt unify.rkt)
   'reader-forms.rkt              '()
   'reduction.rkt                 '(atms.rkt champ.rkt constraint-propagators.rkt definitional-tree.rkt field-witness.rkt float-impl.rkt foreign.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt narrowing.rkt performance-counters.rkt posit-impl.rkt prelude.rkt prop-observatory.rkt propagator.rkt provenance.rkt relations.rkt rrb.rkt solver.rkt stratified-eval.rkt substitution.rkt syntax.rkt tabling.rkt union-find.rkt)
   'relations.rkt                 '(atms.rkt ctor-registry.rkt decision-cell.rkt global-env.rkt infra-cell.rkt performance-counters.rkt propagator.rkt provenance.rkt solver.rkt syntax.rkt tabling.rkt union-find.rkt)
   'repl.rkt                      '(driver.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt parse-reader.rkt parser.rkt pretty-print.rkt sexp-readtable.rkt source-location.rkt trait-resolution.rkt)
   'resolution.rkt                '(elab-network-types.rkt infra-cell.rkt macros.rkt meta-universe.rkt metavar-store.rkt performance-counters.rkt propagator.rkt syntax.rkt trait-resolution.rkt unify.rkt zonk.rkt)
   'rrb.rkt                       '()
   'search-heuristics.rkt         '()
   'session-lattice.rkt           '(sessions.rkt type-lattice.rkt)
   'session-propagators.rkt       '(champ.rkt ctor-registry.rkt errors.rkt pretty-print.rkt processes.rkt prop-observatory.rkt propagator.rkt session-lattice.rkt sessions.rkt source-location.rkt sre-core.rkt)
   'session-runtime.rkt           '(effect-bridge.rkt effect-position.rkt io-bridge.rkt pretty-print.rkt processes.rkt propagator.rkt session-lattice.rkt sessions.rkt syntax.rkt)
   'session-type-bridge.rkt       '(errors.rkt pretty-print.rkt processes.rkt propagator.rkt session-lattice.rkt session-propagators.rkt sessions.rkt source-location.rkt type-lattice.rkt)
   'sessions.rkt                  '(prelude.rkt substitution.rkt syntax.rkt)
   'sexp-readtable.rkt            '()
   'sign-refinement.rkt           '()
   'solver.rkt                    '()
   'source-location.rkt           '()
   'specialized-cells.rkt         '(propagator.rkt)
   'sre-core.rkt                  '(ctor-registry.rkt propagator.rkt syntax.rkt)
   'sre-property-sweep.rkt        '(sre-core.rkt sre-sample-generator.rkt)
   'sre-rewrite.rkt               '(ctor-registry.rkt parse-reader.rkt rrb.rkt sre-core.rkt syntax.rkt)
   'sre-sample-generator.rkt      '(ctor-registry.rkt sre-core.rkt)
   'stratified-eval.rkt           '(propagator.rkt provenance.rkt relations.rkt solver.rkt stratify.rkt syntax.rkt tabling.rkt wf-engine.rkt)
   'stratify.rkt                  '()
   'substitution.rkt              '(loose-bvar.rkt namespace.rkt prelude.rkt syntax.rkt)
   'subtype-predicate.rkt         '(ctor-registry.rkt macros.rkt prelude.rkt propagator.rkt sre-core.rkt substitution.rkt syntax.rkt type-lattice.rkt union-types.rkt)
   'surface-rewrite.rkt           '(ctor-registry.rkt macros.rkt parse-reader.rkt reader-forms.rkt rrb.rkt sre-rewrite.rkt)
   'surface-syntax.rkt            '(source-location.rkt)
   'syntax.rkt                    '(prelude.rkt)
   'tabling.rkt                   '(propagator.rkt)
   'tcp-ffi.rkt                   '()
   'term-lattice.rkt              '()
   'termination-analysis.rkt      '(definitional-tree.rkt macros.rkt syntax.rkt)
   'trace-serialize.rkt           '(champ.rkt elaborator-network.rkt mult-lattice.rkt pretty-print.rkt propagator.rkt type-lattice.rkt)
   'trait-resolution.rkt          '(errors.rkt macros.rkt metavar-store.rkt performance-counters.rkt prelude.rkt pretty-print.rkt source-location.rkt syntax.rkt unify.rkt zonk.rkt)
   'tree-parser.rkt               '(errors.rkt macros.rkt parse-reader.rkt parser.rkt rrb.rkt surface-rewrite.rkt surface-syntax.rkt)
   'tropical-fuel-primitives.rkt  '()
   'tropical-fuel.rkt             '(merge-fn-registry.rkt sre-core.rkt tropical-fuel-primitives.rkt)
   'type-lattice.rkt              '(ctor-registry.rkt prelude.rkt reduction.rkt substitution.rkt syntax.rkt union-types.rkt zonk.rkt)
   'typing-core.rkt               '(champ.rkt elab-speculation-bridge.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt performance-counters.rkt prelude.rkt pretty-print.rkt reduction.rkt relations.rkt rrb.rkt sign-refinement.rkt substitution.rkt subtype-predicate.rkt syntax.rkt unify.rkt warnings.rkt)
   'typing-errors.rkt             '(atms.rkt elab-network-types.rkt elab-speculation-bridge.rkt error-explanation.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt performance-counters.rkt prelude.rkt pretty-print.rkt propagator.rkt qtt.rkt reduction.rkt source-location.rkt syntax.rkt typing-core.rkt)
   'typing-propagators.rkt        '(atms.rkt classify-inhabit.rkt constraint-cell.rkt constraint-propagators.rkt decision-cell.rkt elab-network-types.rkt elab-speculation-bridge.rkt error-explanation.rkt errors.rkt global-env.rkt infra-cell.rkt merge-fn-registry.rkt metavar-store.rkt prelude.rkt pretty-print.rkt propagator.rkt qtt.rkt sign-refinement.rkt source-location.rkt sre-core.rkt substitution.rkt subtype-predicate.rkt surface-rewrite.rkt syntax.rkt trait-resolution.rkt type-lattice.rkt typing-core.rkt union-types.rkt warnings.rkt)
   'typing-sessions.rkt           '(metavar-store.rkt prelude.rkt processes.rkt reduction.rkt sessions.rkt substitution.rkt syntax.rkt typing-core.rkt)
   'unify.rkt                     '(ctor-registry.rkt elaborator-network.rkt metavar-store.rkt performance-counters.rkt prelude.rkt propagator.rkt reduction.rkt source-location.rkt sre-core.rkt substitution.rkt subtype-predicate.rkt syntax.rkt type-lattice.rkt union-types.rkt zonk.rkt)
   'union-find.rkt                '()
   'union-types.rkt               '(syntax.rkt)
   'warnings.rkt                  '(infra-cell.rkt merge-fn-registry.rkt metavar-store.rkt propagator.rkt sre-core.rkt)
   'wf-engine.rkt                 '(bilattice.rkt propagator.rkt provenance.rkt relations.rkt solver.rkt stratify.rkt syntax.rkt tabling.rkt)
   'wf-propagators.rkt            '(bilattice.rkt propagator.rkt)
   'zonk.rkt                      '(metavar-store.rkt namespace.rkt performance-counters.rkt posit-impl.rkt prelude.rkt solver.rkt substitution.rkt syntax.rkt)))

;; ============================================================
;; Layer 2: Test → source module dependencies
;; ============================================================

(struct test-dep (source-modules uses-driver?) #:transparent)

(define test-deps
  (hasheq
   'test-abstract-domains.rkt
   (test-dep '() #t)
   'test-abstract-interpretation-e2e.rkt
   (test-dep '(champ.rkt propagator.rkt) #t)
   'test-architecture-d-02.rkt
   (test-dep '(effect-executor.rkt effect-ordering.rkt effect-position.rkt io-bridge.rkt processes.rkt propagator.rkt session-lattice.rkt session-runtime.rkt sessions.rkt syntax.rkt) #f)
   'test-architecture-selection-01.rkt
   (test-dep '(effect-executor.rkt effect-ordering.rkt effect-position.rkt processes.rkt propagator.rkt session-lattice.rkt session-runtime.rkt sessions.rkt syntax.rkt) #f)
   'test-arity-checking.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-attribute-record.rkt
   (test-dep '(constraint-cell.rkt prelude.rkt propagator.rkt syntax.rkt type-lattice.rkt typing-propagators.rkt) #f)
   'test-auto-implicits.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt) #t)
   'test-bare-methods.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-batch-isolation.rkt
   (test-dep '(errors.rkt) #t)
   'test-bilattice-01.rkt
   (test-dep '(bilattice.rkt propagator.rkt) #f)
   'test-bound-args-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt relations.rkt trait-resolution.rkt) #t)
   'test-branch-numlit-wellformed.rkt
   (test-dep '(driver.rkt namespace.rkt) #f)
   'test-branch-pu.rkt
   (test-dep '(atms.rkt decision-cell.rkt performance-counters.rkt propagator.rkt) #f)
   'test-bridge-perf.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-bundles.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-call-site-specialization.rkt
   (test-dep '(driver.rkt errors.rkt macros.rkt syntax.rkt) #t)
   'test-capability-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-capability-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt warnings.rkt) #t)
   'test-capability-03.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-capability-04.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-capability-05.rkt
   (test-dep '(capability-inference.rkt driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-capability-05b.rkt
   (test-dep '(atms.rkt capability-inference.rkt driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-capability-06.rkt
   (test-dep '(capability-inference.rkt driver.rkt elaborator.rkt errors.rkt foreign.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-capability-07.rkt
   (test-dep '(capability-inference.rkt driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt type-lattice.rkt) #t)
   'test-capability-08.rkt
   (test-dep '(cap-type-bridge.rkt capability-inference.rkt driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt propagator.rkt source-location.rkt surface-syntax.rkt syntax.rkt type-lattice.rkt) #t)
   'test-capability-spec-forms.rkt
   (test-dep '(driver.rkt macros.rkt namespace.rkt) #f)
   'test-cell-domain-inheritance.rkt
   (test-dep '(merge-fn-registry.rkt propagator.rkt) #f)
   'test-cfa-analysis-01.rkt
   (test-dep '(bb-optimization.rkt cfa-analysis.rkt definitional-tree.rkt driver.rkt errors.rkt global-constraints.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt narrowing.rkt prelude.rkt search-heuristics.rkt solver.rkt syntax.rkt trait-resolution.rkt) #f)
   'test-cfa-analysis-02.rkt
   (test-dep '(bb-optimization.rkt cfa-analysis.rkt definitional-tree.rkt driver.rkt errors.rkt global-constraints.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt narrowing.rkt prelude.rkt search-heuristics.rkt solver.rkt syntax.rkt trait-resolution.rkt) #f)
   'test-champ-diff.rkt
   (test-dep '(champ.rkt) #f)
   'test-champ-owner-id.rkt
   (test-dep '(champ.rkt) #f)
   'test-char-string-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-char-string-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-classify-inhabit.rkt
   (test-dep '(classify-inhabit.rkt syntax.rkt type-lattice.rkt) #f)
   'test-clock.rkt
   (test-dep '(clock.rkt propagator.rkt) #f)
   'test-coercion-warnings.rkt
   (test-dep '(driver.rkt global-env.rkt posit-impl.rkt prelude.rkt syntax.rkt) #f)
   'test-coherence.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-collection-conversions.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-collection-fns-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt syntax.rkt) #t)
   'test-collection-fns-02.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt syntax.rkt) #t)
   'test-collection-runners.rkt
   (test-dep '(errors.rkt) #t)
   'test-collection-traits-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-collection-traits-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-compile-match-tree-recursive.rkt
   (test-dep '() #t)
   'test-component-paths-enforcement.rkt
   (test-dep '(infra-cell-sre-registrations.rkt merge-fn-registry.rkt propagator.rkt sre-core.rkt) #f)
   'test-cond-01.rkt
   (test-dep '() #t)
   'test-config-audit.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt warnings.rkt) #f)
   'test-confluence-01.rkt
   (test-dep '(confluence-analysis.rkt definitional-tree.rkt driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt narrowing.rkt prelude.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-constraint-amb-01.rkt
   (test-dep '(constraint-cell.rkt constraint-propagators.rkt driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt prelude.rkt syntax.rkt) #t)
   'test-constraint-cell-01.rkt
   (test-dep '(constraint-cell.rkt) #f)
   'test-constraint-chain-01.rkt
   (test-dep '(driver.rkt errors.rkt global-constraints.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt syntax.rkt) #t)
   'test-constraint-inference.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-constraint-postponement.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt prelude.rkt syntax.rkt unify.rkt zonk.rkt) #t)
   'test-constraint-propagators-01.rkt
   (test-dep '(constraint-cell.rkt constraint-propagators.rkt driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt narrowing.rkt prelude.rkt propagator.rkt reduction.rkt syntax.rkt) #t)
   'test-constraint-readiness.rkt
   (test-dep '(champ.rkt driver.rkt elaborator-network.rkt global-env.rkt metavar-store.rkt prelude.rkt propagator.rkt syntax.rkt type-lattice.rkt unify.rkt) #f)
   'test-core-prelude.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-cross-domain-propagator.rkt
   (test-dep '(champ.rkt propagator.rkt) #f)
   'test-cross-family-conversions-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt posit-impl.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-cross-family-conversions-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt posit-impl.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-cross-family-conversions-03.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt posit-impl.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-ctor-registry.rkt
   (test-dep '(ctor-registry.rkt mult-lattice.rkt syntax.rkt term-lattice.rkt) #f)
   'test-data-adt-forms.rkt
   (test-dep '(driver.rkt errors.rkt macros.rkt metavar-store.rkt namespace.rkt relations.rkt trait-resolution.rkt) #t)
   'test-decimal-literal.rkt
   (test-dep '(driver.rkt global-env.rkt parse-reader.rkt parser.rkt posit-impl.rkt prelude.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-decision-cell.rkt
   (test-dep '(atms.rkt decision-cell.rkt propagator.rkt) #f)
   'test-def-multiline-ws.rkt
   (test-dep '(parse-reader.rkt) #t)
   'test-definition-entry-01.rkt
   (test-dep '(definition-entry.rkt) #f)
   'test-definitional-tree-01.rkt
   (test-dep '(definitional-tree.rkt driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-defmacro.rkt
   (test-dep '(macros.rkt pretty-print.rkt) #f)
   'test-defn-multiarg-patterns.rkt
   (test-dep '(errors.rkt) #t)
   'test-defr-schema.rkt
   (test-dep '(driver.rkt errors.rkt macros.rkt metavar-store.rkt namespace.rkt relations.rkt trait-resolution.rkt) #f)
   'test-dot-access-01.rkt
   (test-dep '(macros.rkt parse-reader.rkt) #f)
   'test-dot-access-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-dyn-rows.rkt
   (test-dep '(driver.rkt global-env.rkt metavar-store.rkt prelude.rkt reduction.rkt subtype-predicate.rkt syntax.rkt typing-core.rkt unify.rkt union-types.rkt) #f)
   'test-effect-bridge-01.rkt
   (test-dep '(effect-bridge.rkt effect-position.rkt propagator.rkt session-lattice.rkt sessions.rkt syntax.rkt) #f)
   'test-effect-collection-01.rkt
   (test-dep '(effect-bridge.rkt effect-position.rkt io-bridge.rkt processes.rkt propagator.rkt session-lattice.rkt session-runtime.rkt sessions.rkt syntax.rkt) #f)
   'test-effect-executor-01.rkt
   (test-dep '(effect-executor.rkt effect-ordering.rkt effect-position.rkt io-bridge.rkt processes.rkt propagator.rkt session-lattice.rkt session-runtime.rkt sessions.rkt syntax.rkt) #f)
   'test-effect-ordering-01.rkt
   (test-dep '(effect-bridge.rkt effect-ordering.rkt effect-position.rkt io-bridge.rkt processes.rkt propagator.rkt session-lattice.rkt session-runtime.rkt sessions.rkt syntax.rkt) #f)
   'test-effect-position-01.rkt
   (test-dep '(effect-position.rkt sessions.rkt syntax.rkt) #f)
   'test-elaboration-parity.rkt
   (test-dep '() #t)
   'test-elaborator-network.rkt
   (test-dep '(elaborator-network.rkt propagator.rkt syntax.rkt type-lattice.rkt) #f)
   'test-elaborator.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-eliminator-typing.rkt
   (test-dep '(prelude.rkt qtt.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-empty-group-toplevel.rkt
   (test-dep '(driver.rkt errors.rkt parse-reader.rkt) #f)
   'test-eq-let-surface-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-eq-ord-extended-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-eq-ord-extended-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-error-explanation.rkt
   (test-dep '(atms.rkt decision-cell.rkt elab-speculation-bridge.rkt error-explanation.rkt propagator.rkt source-location.rkt) #f)
   'test-error-messages.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt unify.rkt) #t)
   'test-error-surfacing.rkt
   (test-dep '(driver.rkt errors.rkt namespace.rkt source-location.rkt) #t)
   'test-errors.rkt
   (test-dep '(errors.rkt source-location.rkt) #f)
   'test-exp-literal.rkt
   (test-dep '(driver.rkt parse-reader.rkt parser.rkt posit-impl.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-expand-error-propagation.rkt
   (test-dep '(errors.rkt source-location.rkt) #t)
   'test-explain-provenance-01.rkt
   (test-dep '(bilattice.rkt propagator.rkt provenance.rkt relations.rkt solver.rkt stratified-eval.rkt syntax.rkt tabling.rkt wf-engine.rkt) #f)
   'test-extended-spec.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt parse-reader.rkt parser.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt warnings.rkt) #f)
   'test-f1-records-acceptance.rkt
   (test-dep '(driver.rkt errors.rkt) #f)
   'test-f1b3-width-acceptance.rkt
   (test-dep '(driver.rkt errors.rkt) #f)
   'test-f1b4-seal-acceptance.rkt
   (test-dep '(driver.rkt errors.rkt) #f)
   'test-f1b5-validate-acceptance.rkt
   (test-dep '(driver.rkt errors.rkt) #f)
   'test-facet-sre-registration.rkt
   (test-dep '(constraint-cell.rkt driver.rkt merge-fn-registry.rkt propagator.rkt qtt.rkt sre-core.rkt typing-propagators.rkt warnings.rkt) #f)
   'test-facet-tag-dispatch.rkt
   (test-dep '(classify-inhabit.rkt propagator.rkt syntax.rkt type-lattice.rkt typing-propagators.rkt) #f)
   'test-fact-corpus-gen.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt relations.rkt trait-resolution.rkt) #f)
   'test-field-witness.rkt
   (test-dep '(champ.rkt field-witness.rkt macros.rkt rrb.rkt syntax.rkt typing-core.rkt) #f)
   'test-first-class-paths.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-first-rest-01.rkt
   (test-dep '() #t)
   'test-firstclass-ops.rkt
   (test-dep '() #t)
   'test-float-conversions.rkt
   (test-dep '(driver.rkt reduction.rkt syntax.rkt) #t)
   'test-float-core.rkt
   (test-dep '(driver.rkt global-env.rkt prelude.rkt pretty-print.rkt substitution.rkt syntax.rkt typing-core.rkt) #t)
   'test-float-lib.rkt
   (test-dep '(driver.rkt macros.rkt namespace.rkt) #f)
   'test-float-literal.rkt
   (test-dep '(driver.rkt) #t)
   'test-float-ops.rkt
   (test-dep '(driver.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #t)
   'test-float-tower.rkt
   (test-dep '(driver.rkt reduction.rkt subtype-predicate.rkt syntax.rkt typing-core.rkt) #t)
   'test-float-traits.rkt
   (test-dep '() #t)
   'test-foreign-block.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt foreign.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-foreign-fn-arity.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt prelude.rkt qtt.rkt syntax.rkt typing-core.rkt) #f)
   'test-foreign-fn-walkers.rkt
   (test-dep '(pretty-print.rkt substitution.rkt syntax.rkt zonk.rkt) #f)
   'test-foreign-marshal-ext.rkt
   (test-dep '(foreign.rkt posit-impl.rkt syntax.rkt) #f)
   'test-foreign.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt foreign.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt pnet-serialize.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-forward-ref-01.rkt
   (test-dep '(driver.rkt errors.rkt namespace.rkt) #f)
   'test-free-ordering.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt) #t)
   'test-from-nat-computed.rkt
   (test-dep '(reduction.rkt syntax.rkt) #f)
   'test-functor-ws-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt parse-reader.rkt parser.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-functor-ws-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt parse-reader.rkt parser.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-galois-connection.rkt
   (test-dep '() #t)
   'test-gde-errors.rkt
   (test-dep '(atms.rkt driver.rkt elab-speculation-bridge.rkt errors.rkt global-env.rkt metavar-store.rkt performance-counters.rkt prelude.rkt source-location.rkt syntax.rkt) #t)
   'test-gen-trait.rkt
   (test-dep '(driver.rkt macros.rkt namespace.rkt) #f)
   'test-general-body-01.rkt
   (test-dep '(driver.rkt errors.rkt namespace.rkt) #f)
   'test-generators.rkt
   (test-dep '(driver.rkt global-env.rkt metavar-store.rkt performance-counters.rkt prelude.rkt reduction.rkt syntax.rkt typing-core.rkt unify.rkt) #f)
   'test-generic-arith-01.rkt
   (test-dep '(driver.rkt global-env.rkt parser.rkt posit-impl.rkt prelude.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-generic-arith-03.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-generic-from.rkt
   (test-dep '(driver.rkt global-env.rkt parser.rkt posit-impl.rkt prelude.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-generic-ops-01-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-generic-ops-01-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-generic-ops-02-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-generic-ops-02-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-global-constraints-01.rkt
   (test-dep '(bb-optimization.rkt definitional-tree.rkt driver.rkt errors.rkt global-constraints.rkt global-env.rkt interval-domain.rkt macros.rkt metavar-store.rkt namespace.rkt narrowing.rkt prelude.rkt search-heuristics.rkt solver.rkt syntax.rkt trait-resolution.rkt) #f)
   'test-guards-01.rkt
   (test-dep '() #t)
   'test-hashable-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-hashable-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-hasmethod-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt prelude.rkt syntax.rkt trait-resolution.rkt zonk.rkt) #t)
   'test-hasse-registry.rkt
   (test-dep '(hasse-registry.rkt propagator.rkt sre-core.rkt) #f)
   'test-higher-rank.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-hkt-errors.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-hkt-impl.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-hkt-kind.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-hof-def-seam.rkt
   (test-dep '(driver.rkt errors.rkt prelude.rkt subtype-predicate.rkt syntax.rkt) #f)
   'test-identity-generic-ops.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-implicit-inference.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt) #t)
   'test-implicit-map-01.rkt
   (test-dep '(macros.rkt) #f)
   'test-implicit-map-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-import-no-ns.rkt
   (test-dep '(driver.rkt macros.rkt namespace.rkt) #f)
   'test-inductive.rkt
   (test-dep '(prelude.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-inexhaustive-match-warning.rkt
   (test-dep '(driver.rkt namespace.rkt) #f)
   'test-infra-cell-01.rkt
   (test-dep '(infra-cell.rkt propagator.rkt) #f)
   'test-infra-cell-atms-01.rkt
   (test-dep '(atms.rkt decision-cell.rkt infra-cell.rkt propagator.rkt) #f)
   'test-infra-cell-constraint-01.rkt
   (test-dep '(champ.rkt driver.rkt elaborator-network.rkt infra-cell.rkt metavar-store.rkt propagator.rkt syntax.rkt) #f)
   'test-infra-cell-parallel-01.rkt
   (test-dep '(infra-cell.rkt propagator.rkt) #f)
   'test-infra-cell-registration-01.rkt
   (test-dep '(champ.rkt elaborator-network.rkt infra-cell.rkt propagator.rkt syntax.rkt type-lattice.rkt) #f)
   'test-int-patterns-01.rkt
   (test-dep '() #t)
   'test-int.rkt
   (test-dep '(driver.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-integration.rkt
   (test-dep '(prelude.rkt processes.rkt qtt.rkt reduction.rkt sessions.rkt substitution.rkt syntax.rkt typing-core.rkt typing-sessions.rkt) #f)
   'test-interval-domain-01.rkt
   (test-dep '(definitional-tree.rkt driver.rkt errors.rkt global-env.rkt interval-domain.rkt macros.rkt metavar-store.rkt namespace.rkt narrowing-abstract.rkt narrowing.rkt prelude.rkt reduction.rkt syntax.rkt trait-resolution.rkt) #f)
   'test-introspection.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt sexp-readtable.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-io-boundary-01.rkt
   (test-dep '(io-bridge.rkt processes.rkt propagator.rkt session-lattice.rkt session-runtime.rkt sessions.rkt syntax.rkt) #f)
   'test-io-bridge-01.rkt
   (test-dep '(io-bridge.rkt io-ffi.rkt propagator.rkt session-runtime.rkt sessions.rkt syntax.rkt) #f)
   'test-io-cap-pipeline-01.rkt
   (test-dep '(capability-inference.rkt driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-io-caps-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-io-csv-01.rkt
   (test-dep '(io-ffi.rkt) #f)
   'test-io-csv-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-io-dep-cap-01.rkt
   (test-dep '(cap-type-bridge.rkt capability-inference.rkt driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt type-lattice.rkt) #f)
   'test-io-dep-cap-02.rkt
   (test-dep '(cap-type-bridge.rkt capability-inference.rkt driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-io-dep-session-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt pretty-print.rkt session-runtime.rkt sessions.rkt substitution.rkt syntax.rkt) #t)
   'test-io-dep-session-02.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt sessions.rkt syntax.rkt) #t)
   'test-io-file-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-io-file-02.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt sessions.rkt) #t)
   'test-io-fio-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-io-fs-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-io-main-01.rkt
   (test-dep '(capability-inference.rkt driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-io-opaque-01.rkt
   (test-dep '(foreign.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt) #f)
   'test-io-path-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-io-session-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt sessions.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-io-session-02.rkt
   (test-dep '(io-bridge.rkt processes.rkt propagator.rkt session-lattice.rkt session-runtime.rkt sessions.rkt syntax.rkt) #f)
   'test-io-session-03.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt sessions.rkt) #t)
   'test-kind-inference-where.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-kind-inference.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-lattice.rkt
   (test-dep '() #t)
   'test-let-arrow-syntax.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt parser.rkt prelude.rkt pretty-print.rkt surface-syntax.rkt syntax.rkt typing-errors.rkt) #f)
   'test-let-blocks.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt reader-forms.rkt) #t)
   'test-let-multiline-ws.rkt
   (test-dep '(errors.rkt parse-reader.rkt) #t)
   'test-list-extended-01-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-list-extended-01-02.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-list-extended-02-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-list-extended-02-02.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-list-literals.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt parse-reader.rkt pretty-print.rkt sexp-readtable.rkt syntax.rkt) #t)
   'test-loose-bvar-coverage.rkt
   (test-dep '(loose-bvar.rkt substitution.rkt syntax.rkt) #f)
   'test-lseq-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-lseq-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-lseq-literal.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt sexp-readtable.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-lseq-traits.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-lsp-repl-01.rkt
   (test-dep '(errors.rkt) #f)
   'test-map-bridge.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt syntax.rkt) #t)
   'test-map-entry.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt syntax.rkt) #t)
   'test-map-ops-eval.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt syntax.rkt) #t)
   'test-map-set-traits-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-map-set-traits-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-map.rkt
   (test-dep '(champ.rkt driver.rkt global-env.rkt metavar-store.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-match-builtins.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt) #t)
   'test-merge-fn-registry.rkt
   (test-dep '(merge-fn-registry.rkt) #f)
   'test-meta-feedback.rkt
   (test-dep '(prelude.rkt propagator.rkt syntax.rkt type-lattice.rkt typing-propagators.rkt) #f)
   'test-metavar.rkt
   (test-dep '(driver.rkt global-env.rkt metavar-store.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt zonk.rkt) #f)
   'test-method-resolution.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-mixed-map.rkt
   (test-dep '(champ.rkt driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt unify.rkt) #t)
   'test-mixfix-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-mixfix-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-module-network-01.rkt
   (test-dep '(definition-entry.rkt global-env.rkt infra-cell-sre-registrations.rkt infra-cell.rkt macros.rkt namespace.rkt phase1d-registrations.rkt propagator.rkt) #f)
   'test-mult-inference.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt prelude.rkt syntax.rkt unify.rkt zonk.rkt) #t)
   'test-mult-lattice.rkt
   (test-dep '(mult-lattice.rkt) #f)
   'test-mult-propagator.rkt
   (test-dep '(champ.rkt decision-cell.rkt driver.rkt elaborator-network.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt mult-lattice.rkt namespace.rkt prelude.rkt propagator.rkt syntax.rkt type-lattice.rkt) #t)
   'test-multi-body-defn.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt parser.rkt prelude.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-multiclause-debug.rkt
   (test-dep '(atms.rkt decision-cell.rkt propagator.rkt relations.rkt solver.rkt syntax.rkt) #f)
   'test-namespace.rkt
   (test-dep '(elaborator.rkt global-env.rkt namespace.rkt prelude.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-narrow-syntax-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-narrow-syntax-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-narrowing-01.rkt
   (test-dep '(definitional-tree.rkt macros.rkt narrowing.rkt propagator.rkt syntax.rkt term-lattice.rkt) #f)
   'test-narrowing-search-01.rkt
   (test-dep '(definitional-tree.rkt driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt narrowing.rkt prelude.rkt reduction.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-narrowing-search-02.rkt
   (test-dep '(definitional-tree.rkt driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt narrowing.rkt prelude.rkt reduction.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-native-collection-ops.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt syntax.rkt) #t)
   'test-negative-literals.rkt
   (test-dep '(driver.rkt parse-reader.rkt) #t)
   'test-new-lattice-cell.rkt
   (test-dep '(driver.rkt errors.rkt macros.rkt) #t)
   'test-nil-type.rkt
   (test-dep '(champ.rkt driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-num-lit.rkt
   (test-dep '(driver.rkt parser.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-numeric-coercion.rkt
   (test-dep '(driver.rkt global-env.rkt posit-impl.rkt prelude.rkt syntax.rkt) #f)
   'test-numeric-display.rkt
   (test-dep '(driver.rkt posit-impl.rkt pretty-print.rkt syntax.rkt) #t)
   'test-numeric-join.rkt
   (test-dep '(syntax.rkt typing-core.rkt) #f)
   'test-numeric-traits-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-numeric-traits-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-numerics-float.rkt
   (test-dep '(driver.rkt errors.rkt macros.rkt namespace.rkt) #t)
   'test-observatory-01.rkt
   (test-dep '(champ.rkt prop-observatory.rkt propagator.rkt) #f)
   'test-observatory-02.rkt
   (test-dep '(champ.rkt observatory-serialize.rkt prop-observatory.rkt propagator.rkt) #f)
   'test-ocapn-abort.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-acceptance-l3.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-behavior.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-bidirectional-interop.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-bootstrap-gift-interop.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-break-plain-interop.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-bridge-interop.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-bridge.rkt
   (test-dep '(crypto-ffi.rkt driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt ocapn-identity-ffi.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-captp-wire.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-captp.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-conversation.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-e2e.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-handoff.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt ocapn-enliven-ffi.rkt ocapn-handoff-ffi.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-handshake.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-import-object-interop.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-live-interop.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-location-key.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-locator.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-message.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-multi-questioner-interop.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-netlayer-tcp.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-netlayer.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-pipeline-forwarding-interop.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-pipeline.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-pipelined.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-pipelining-interop.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-pipelining.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-promise.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-protocols.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt sessions.rkt syntax.rkt) #f)
   'test-ocapn-questioner-interop.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-refr-passing-interop.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-refr.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-rpc.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-syrup-cross-impl.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-syrup-wire.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-syrup.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-ocapn-tcp-testing.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt tcp-ffi.rkt) #f)
   'test-ocapn-vat.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-p2-debug.rkt
   (test-dep '(driver.rkt elab-network-types.rkt metavar-store.rkt propagator.rkt substitution.rkt syntax.rkt type-lattice.rkt typing-propagators.rkt) #f)
   'test-parse-bridges.rkt
   (test-dep '(parse-bridges.rkt parse-lattice.rkt) #f)
   'test-parse-integration.rkt
   (test-dep '(champ.rkt infra-cell.rkt parse-bridges.rkt parse-lattice.rkt propagator.rkt) #f)
   'test-parse-lattice.rkt
   (test-dep '(parse-lattice.rkt) #f)
   'test-parse-reader.rkt
   (test-dep '(parse-lattice.rkt parse-reader.rkt propagator.rkt rrb.rkt surface-rewrite.rkt) #f)
   'test-parser-relational.rkt
   (test-dep '(errors.rkt parser.rkt surface-syntax.rkt) #f)
   'test-parser.rkt
   (test-dep '(errors.rkt parser.rkt source-location.rkt surface-syntax.rkt) #f)
   'test-path-expressions.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt sexp-readtable.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-path-selection-acceptance.rkt
   (test-dep '(driver.rkt errors.rkt) #f)
   'test-path-selection.rkt
   (test-dep '(champ.rkt driver.rkt elaborator.rkt errors.rkt global-constraints.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt rrb.rkt syntax.rkt trait-resolution.rkt typing-core.rkt unify.rkt) #t)
   'test-pattern-defn-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-pattern-defn-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-per-nogood.rkt
   (test-dep '(atms.rkt decision-cell.rkt propagator.rkt) #f)
   'test-perf-counters.rkt
   (test-dep '(performance-counters.rkt) #f)
   'test-phase-timing.rkt
   (test-dep '(driver.rkt global-env.rkt performance-counters.rkt) #f)
   'test-pipe-compose-e2e-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-pipe-compose-e2e-02a.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-pipe-compose-e2e-02b.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-pipe-compose-e2e-03.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-pipe-compose.rkt
   (test-dep '(macros.rkt parse-reader.rkt) #f)
   'test-placeholder.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt source-location.rkt surface-syntax.rkt) #t)
   'test-pnet-container-sentinels.rkt
   (test-dep '(champ.rkt pnet-serialize.rkt rrb.rkt syntax.rkt) #f)
   'test-pnet-dep-staleness.rkt
   (test-dep '(driver.rkt namespace.rkt pnet-serialize.rkt) #f)
   'test-pnet-registry-restore.rkt
   (test-dep '(driver.rkt errors.rkt global-constraints.rkt macros.rkt metavar-store.rkt namespace.rkt pnet-serialize.rkt typing-propagators.rkt warnings.rkt) #f)
   'test-pnet-slot-count.rkt
   (test-dep '(pnet-serialize.rkt) #f)
   'test-pnet-vec-fin.rkt
   (test-dep '(pnet-serialize.rkt syntax.rkt) #f)
   'test-posit-eq.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt posit-impl.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-posit-float-conversions.rkt
   (test-dep '() #t)
   'test-posit-identity.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-posit-impl.rkt
   (test-dep '(posit-impl.rkt) #f)
   'test-posit-literal.rkt
   (test-dep '() #t)
   'test-posit16.rkt
   (test-dep '(driver.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-posit32.rkt
   (test-dep '(driver.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-posit64.rkt
   (test-dep '(driver.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-posit8.rkt
   (test-dep '(driver.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-postfix-index-01.rkt
   (test-dep '(parse-reader.rkt) #f)
   'test-postfix-index-02.rkt
   (test-dep '(macros.rkt) #f)
   'test-postfix-index-03.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-ppn-track4.rkt
   (test-dep '(champ.rkt prelude.rkt propagator.rkt surface-rewrite.rkt syntax.rkt type-lattice.rkt typing-propagators.rkt) #f)
   'test-prelude-collections.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-prelude-numerics.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-prelude-system-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt) #t)
   'test-prelude-system-02.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-prelude.rkt
   (test-dep '(prelude.rkt) #f)
   'test-pretty-print-pvec.rkt
   (test-dep '(pretty-print.rkt syntax.rkt) #f)
   'test-pretty-print.rkt
   (test-dep '(champ.rkt prelude.rkt pretty-print.rkt sessions.rkt syntax.rkt) #f)
   'test-prim-op-firstclass.rkt
   (test-dep '() #t)
   'test-process-parse-01.rkt
   (test-dep '(errors.rkt parser.rkt surface-syntax.rkt) #f)
   'test-process-ws-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt processes.rkt sessions.rkt surface-syntax.rkt warnings.rkt) #f)
   'test-process-ws-02.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt sessions.rkt) #f)
   'test-propagator-bsp.rkt
   (test-dep '(champ.rkt propagator.rkt) #f)
   'test-propagator-descending-01.rkt
   (test-dep '(champ.rkt propagator.rkt) #f)
   'test-propagator-integration.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #t)
   'test-propagator-lvar.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt prelude.rkt syntax.rkt) #t)
   'test-propagator-network.rkt
   (test-dep '(champ.rkt propagator.rkt) #f)
   'test-propagator-patterns.rkt
   (test-dep '(prelude.rkt propagator.rkt syntax.rkt type-lattice.rkt typing-propagators.rkt) #f)
   'test-propagator-persistence.rkt
   (test-dep '(champ.rkt propagator.rkt) #f)
   'test-propagator-solver.rkt
   (test-dep '(decision-cell.rkt propagator.rkt relations.rkt solver.rkt syntax.rkt) #f)
   'test-propagator-types.rkt
   (test-dep '(global-env.rkt prelude.rkt pretty-print.rkt propagator.rkt qtt.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-propagator.rkt
   (test-dep '(champ.rkt propagator.rkt) #f)
   'test-properties.rkt
   (test-dep '(driver.rkt global-env.rkt metavar-store.rkt performance-counters.rkt prelude.rkt reduction.rkt syntax.rkt typing-core.rkt unify.rkt zonk.rkt) #f)
   'test-property-ws.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt parse-reader.rkt parser.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-provenance-errors.rkt
   (test-dep '(atms.rkt driver.rkt elab-network-types.rkt elab-speculation-bridge.rkt error-explanation.rkt errors.rkt global-env.rkt metavar-store.rkt performance-counters.rkt prelude.rkt propagator.rkt source-location.rkt syntax.rkt) #t)
   'test-provenance.rkt
   (test-dep '(provenance.rkt) #f)
   'test-punify-integration.rkt
   (test-dep '(champ.rkt ctor-registry.rkt driver.rkt elaborator-network.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt mult-lattice.rkt namespace.rkt prelude.rkt syntax.rkt type-lattice.rkt) #t)
   'test-punify-surface.rkt
   (test-dep '(errors.rkt) #t)
   'test-pvec-fold.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt syntax.rkt) #t)
   'test-pvec-int-helpers.rkt
   (test-dep '() #t)
   'test-pvec-ops-eval.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt syntax.rkt) #t)
   'test-pvec-traits.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-pvec-zip-with.rkt
   (test-dep '() #t)
   'test-pvec.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt parse-reader.rkt prelude.rkt pretty-print.rkt reduction.rkt rrb.rkt sexp-readtable.rkt substitution.rkt syntax.rkt typing-core.rkt) #t)
   'test-qtt-pipeline.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt) #t)
   'test-qtt-union-meta.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-qtt.rkt
   (test-dep '(prelude.rkt qtt.rkt reduction.rkt substitution.rkt syntax.rkt) #f)
   'test-quire.rkt
   (test-dep '(driver.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-quote.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt sexp-readtable.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-rat-literal-in-list.rkt
   (test-dep '() #t)
   'test-rat.rkt
   (test-dep '(driver.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-reader-relational.rkt
   (test-dep '(parse-reader.rkt) #f)
   'test-reader-robustness.rkt
   (test-dep '(driver.rkt errors.rkt macros.rkt namespace.rkt source-location.rkt) #f)
   'test-readiness-propagator.rkt
   (test-dep '(driver.rkt elaborator-network.rkt infra-cell.rkt metavar-store.rkt propagator.rkt resolution.rkt syntax.rkt) #f)
   'test-reason.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt relations.rkt) #f)
   'test-record-collections.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-record-node.rkt
   (test-dep '(metavar-store.rkt pnet-serialize.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt trait-resolution.rkt unify.rkt union-types.rkt) #f)
   'test-record-pnet-cache.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt pnet-serialize.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #f)
   'test-redex-model.rkt
   (test-dep '() #f)
   'test-reducible-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt syntax.rkt) #t)
   'test-reducible-02.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt syntax.rkt) #t)
   'test-reduction-perf-01-01.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt parse-reader.rkt parser.rkt posit-impl.rkt prelude.rkt reduction.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-reduction-perf-01-02.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt reduction.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-reduction-perf-02-01.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt reduction.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-reduction-perf-02-02.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt reduction.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-reduction.rkt
   (test-dep '(prelude.rkt reduction.rkt substitution.rkt syntax.rkt) #f)
   'test-refined-int.rkt
   (test-dep '(driver.rkt) #t)
   'test-refined-rat.rkt
   (test-dep '(driver.rkt) #t)
   'test-refined-subtyping.rkt
   (test-dep '(driver.rkt) #t)
   'test-rel-t1-acceptance.rkt
   (test-dep '(driver.rkt errors.rkt) #t)
   'test-rel-t1-naf.rkt
   (test-dep '(driver.rkt errors.rkt namespace.rkt relations.rkt) #f)
   'test-rel-t1-pol.rkt
   (test-dep '(champ.rkt errors.rkt narrowing.rkt performance-counters.rkt pnet-serialize.rkt syntax.rkt) #t)
   'test-rel-t1-typed-rows.rkt
   (test-dep '(champ.rkt driver.rkt errors.rkt macros.rkt metavar-store.rkt namespace.rkt pretty-print.rkt propagator.rkt relations.rkt rrb.rkt syntax.rkt typing-core.rkt) #t)
   'test-rel-t1-typed-vars.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt macros.rkt namespace.rkt parser.rkt relations.rkt syntax.rkt) #t)
   'test-relation-store-isolation.rkt
   (test-dep '(errors.rkt relations.rkt) #t)
   'test-relational-e2e.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt relations.rkt trait-resolution.rkt) #f)
   'test-relational-types.rkt
   (test-dep '(elaborator.rkt errors.rkt global-env.rkt prelude.rkt pretty-print.rkt qtt.rkt reduction.rkt solver.rkt source-location.rkt substitution.rkt surface-syntax.rkt syntax.rkt typing-core.rkt) #f)
   'test-relations-runtime.rkt
   (test-dep '(provenance.rkt relations.rkt solver.rkt) #f)
   'test-relative-path-resolution.rkt
   (test-dep '(driver.rkt errors.rkt) #f)
   'test-repl-session-01.rkt
   (test-dep '(errors.rkt repl.rkt) #f)
   'test-residuation-propagator.rkt
   (test-dep '(classify-inhabit.rkt prelude.rkt propagator.rkt syntax.rkt type-lattice.rkt typing-propagators.rkt) #f)
   'test-resolution-bridge-cids.rkt
   (test-dep '(errors.rkt macros.rkt resolution.rkt) #t)
   'test-resolution-confluence-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt prelude.rkt syntax.rkt trait-resolution.rkt zonk.rkt) #t)
   'test-retraction-stratum.rkt
   (test-dep '(cell-ops.rkt driver.rkt elaborator-network.rkt infra-cell.rkt metavar-store.rkt propagator.rkt syntax.rkt) #f)
   'test-route-soundness-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt relations.rkt trait-resolution.rkt) #t)
   'test-scheduler-odiff.rkt
   (test-dep '(propagator.rkt) #f)
   'test-schema-e2e.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt prelude.rkt syntax.rkt) #t)
   'test-schema-field-construction.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt relations.rkt) #f)
   'test-schema-properties.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt prelude.rkt syntax.rkt) #t)
   'test-schema-registry.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-schema-seal.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt relations.rkt) #f)
   'test-schema-types.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt typing-core.rkt) #t)
   'test-search-heuristics-01.rkt
   (test-dep '(definitional-tree.rkt driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt narrowing.rkt prelude.rkt search-heuristics.rkt syntax.rkt trait-resolution.rkt) #f)
   'test-selection-compose.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt prelude.rkt syntax.rkt) #t)
   'test-selection-parsing.rkt
   (test-dep '(errors.rkt parser.rkt sexp-readtable.rkt surface-syntax.rkt) #f)
   'test-selection-paths.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt sexp-readtable.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-selection-registry.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt prelude.rkt syntax.rkt) #t)
   'test-selection-typing.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt prelude.rkt syntax.rkt) #t)
   'test-sess-inference.rkt
   (test-dep '(driver.rkt metavar-store.rkt prelude.rkt processes.rkt sessions.rkt substitution.rkt syntax.rkt typing-core.rkt typing-sessions.rkt) #f)
   'test-session-async-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt pretty-print.rkt session-lattice.rkt sessions.rkt syntax.rkt) #f)
   'test-session-async-e2e.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt sessions.rkt) #f)
   'test-session-async-ws-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt sessions.rkt) #t)
   'test-session-boundary-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt pretty-print.rkt processes.rkt sessions.rkt source-location.rkt surface-syntax.rkt syntax.rkt warnings.rkt) #f)
   'test-session-caps-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt processes.rkt sessions.rkt source-location.rkt surface-syntax.rkt syntax.rkt warnings.rkt) #f)
   'test-session-caps-02.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt processes.rkt sessions.rkt surface-syntax.rkt syntax.rkt warnings.rkt) #f)
   'test-session-deadlock-01.rkt
   (test-dep '(errors.rkt processes.rkt propagator.rkt session-lattice.rkt session-propagators.rkt sessions.rkt syntax.rkt) #f)
   'test-session-e2e-ws.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt sessions.rkt) #f)
   'test-session-elaborate-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt pretty-print.rkt processes.rkt sessions.rkt surface-syntax.rkt) #f)
   'test-session-errors-01.rkt
   (test-dep '(errors.rkt pretty-print.rkt processes.rkt session-lattice.rkt session-propagators.rkt sessions.rkt syntax.rkt) #f)
   'test-session-lattice-01.rkt
   (test-dep '(session-lattice.rkt sessions.rkt syntax.rkt) #f)
   'test-session-parse-01.rkt
   (test-dep '(errors.rkt parser.rkt surface-syntax.rkt) #f)
   'test-session-parse-02.rkt
   (test-dep '(errors.rkt macros.rkt parser.rkt surface-syntax.rkt) #f)
   'test-session-propagators-01.rkt
   (test-dep '(errors.rkt processes.rkt propagator.rkt session-lattice.rkt session-propagators.rkt sessions.rkt syntax.rkt) #f)
   'test-session-runtime-01.rkt
   (test-dep '(propagator.rkt session-lattice.rkt session-runtime.rkt sessions.rkt syntax.rkt) #f)
   'test-session-runtime-02.rkt
   (test-dep '(processes.rkt propagator.rkt session-lattice.rkt session-runtime.rkt sessions.rkt syntax.rkt) #f)
   'test-session-runtime-03.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt sessions.rkt) #t)
   'test-session-runtime-04.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt sessions.rkt) #t)
   'test-session-throws-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt sessions.rkt) #f)
   'test-session-type-bridge-01.rkt
   (test-dep '(errors.rkt processes.rkt propagator.rkt session-lattice.rkt session-propagators.rkt session-type-bridge.rkt sessions.rkt syntax.rkt type-lattice.rkt) #f)
   'test-session-ws-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt sessions.rkt) #t)
   'test-sessions.rkt
   (test-dep '(prelude.rkt sessions.rkt substitution.rkt syntax.rkt) #f)
   'test-set-ops-eval.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt syntax.rkt) #t)
   'test-set.rkt
   (test-dep '(champ.rkt driver.rkt global-env.rkt parse-reader.rkt prelude.rkt pretty-print.rkt reduction.rkt sexp-readtable.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-sexp-reader-parity.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt sexp-readtable.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-sign-galois.rkt
   (test-dep '() #t)
   'test-sign-refinement.rkt
   (test-dep '(sign-refinement.rkt) #f)
   'test-solve-carrier.rkt
   (test-dep '(champ.rkt pnet-serialize.rkt rrb.rkt syntax.rkt typing-core.rkt) #t)
   'test-solver-collection-terms.rkt
   (test-dep '(errors.rkt) #t)
   'test-solver-config.rkt
   (test-dep '(solver.rkt) #f)
   'test-solver-context.rkt
   (test-dep '(atms.rkt decision-cell.rkt propagator.rkt) #f)
   'test-solver-occurs.rkt
   (test-dep '(relations.rkt) #f)
   'test-solver-parity.rkt
   (test-dep '(relations.rkt solver.rkt stratified-eval.rkt syntax.rkt) #f)
   'test-source-loc-infrastructure.rkt
   (test-dep '(champ.rkt propagator.rkt source-location.rkt surface-syntax.rkt) #f)
   'test-spec-contracts.rkt
   (test-dep '(driver.rkt macros.rkt namespace.rkt) #f)
   'test-spec-mult-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-spec-multiline-ws.rkt
   (test-dep '(parse-reader.rkt) #f)
   'test-spec-ordering.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt typing-errors.rkt) #f)
   'test-spec-store-clobber.rkt
   (test-dep '(driver.rkt macros.rkt metavar-store.rkt namespace.rkt) #f)
   'test-spec.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt typing-errors.rkt) #f)
   'test-specialization.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-specialized-cells.rkt
   (test-dep '(champ.rkt propagator.rkt) #f)
   'test-speculation-bridge.rkt
   (test-dep '(driver.rkt elab-speculation-bridge.rkt errors.rkt global-env.rkt metavar-store.rkt prelude.rkt syntax.rkt) #t)
   'test-sprint10.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt) #t)
   'test-sre-algebraic.rkt
   (test-dep '(driver.rkt session-lattice.rkt sre-core.rkt sre-sample-generator.rkt surface-syntax.rkt syntax.rkt type-lattice.rkt) #f)
   'test-sre-core.rkt
   (test-dep '(ctor-registry.rkt propagator.rkt sre-core.rkt) #f)
   'test-sre-coverage.rkt
   (test-dep '(prelude.rkt propagator.rkt syntax.rkt type-lattice.rkt typing-propagators.rkt) #f)
   'test-sre-duality.rkt
   (test-dep '(ctor-registry.rkt propagator.rkt session-lattice.rkt sessions.rkt sre-core.rkt syntax.rkt) #f)
   'test-sre-sd-properties.rkt
   (test-dep '(driver.rkt form-cells.rkt sessions.rkt sre-core.rkt sre-property-sweep.rkt sre-sample-generator.rkt surface-rewrite.rkt syntax.rkt tropical-fuel.rkt) #f)
   'test-sre-subtype.rkt
   (test-dep '(ctor-registry.rkt propagator.rkt sre-core.rkt subtype-predicate.rkt syntax.rkt type-lattice.rkt) #f)
   'test-sre-track2d.rkt
   (test-dep '(driver.rkt parse-reader.rkt rrb.rkt sre-rewrite.rkt surface-rewrite.rkt) #f)
   'test-sre-track2h.rkt
   (test-dep '(driver.rkt substitution.rkt subtype-predicate.rkt syntax.rkt type-lattice.rkt union-types.rkt) #f)
   'test-stdlib-01-data-01.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-stdlib-01-data-02.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-stdlib-01-data-03.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-stdlib-01-data-04.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-stdlib-02-traits-01.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-stdlib-02-traits-02.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-stdlib-02-traits-03.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-stdlib-02-traits-04.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-stdlib-02-traits-05.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-stdlib-02-traits-06.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-stdlib-02-traits-07.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-stdlib-03-list-01.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-stdlib-03-list-02.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-stdlib-03-list-03.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-stdlib-03-list-04-01.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt) #t)
   'test-stdlib-03-list-04-02.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt) #t)
   'test-stdlib-03-list-05.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-strategy-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt) #f)
   'test-strategy-ws-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt) #t)
   'test-stratified-eval.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt relations.rkt solver.rkt stratified-eval.rkt stratify.rkt syntax.rkt trait-resolution.rkt) #f)
   'test-stratify.rkt
   (test-dep '(stratify.rkt) #f)
   'test-string-normalize.rkt
   (test-dep '(errors.rkt) #t)
   'test-string-ops.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-structural-decomp.rkt
   (test-dep '(elaborator-network.rkt propagator.rkt syntax.rkt type-lattice.rkt) #f)
   'test-substitution-scaling.rkt
   (test-dep '(loose-bvar.rkt prelude.rkt substitution.rkt syntax.rkt) #f)
   'test-substitution.rkt
   (test-dep '(champ.rkt prelude.rkt reduction.rkt rrb.rkt substitution.rkt syntax.rkt unify.rkt) #f)
   'test-subtyping.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt posit-impl.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-support.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-constraints.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt propagator.rkt relations.rkt source-location.rkt surface-syntax.rkt syntax.rkt warnings.rkt) #t)
   'test-surface-defmacro-01.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt) #t)
   'test-surface-defmacro-02.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt) #t)
   'test-surface-integration.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt typing-core.rkt typing-errors.rkt) #f)
   'test-syntax-verify.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-syntax.rkt
   (test-dep '(prelude.rkt syntax.rkt) #f)
   'test-t3-equality-audit.rkt
   (test-dep '(syntax.rkt unify.rkt) #f)
   'test-tabling-integration.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-tabling-types.rkt
   (test-dep '(global-env.rkt prelude.rkt pretty-print.rkt propagator.rkt qtt.rkt reduction.rkt substitution.rkt syntax.rkt tabling.rkt typing-core.rkt) #f)
   'test-tabling.rkt
   (test-dep '(propagator.rkt tabling.rkt) #f)
   'test-tagged-cell-value.rkt
   (test-dep '(decision-cell.rkt propagator.rkt) #f)
   'test-term-lattice-01.rkt
   (test-dep '(term-lattice.rkt) #f)
   'test-termination-01.rkt
   (test-dep '(confluence-analysis.rkt definitional-tree.rkt driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt narrowing.rkt prelude.rkt syntax.rkt termination-analysis.rkt trait-resolution.rkt) #t)
   'test-to-conversions.rkt
   (test-dep '() #t)
   'test-trace-data.rkt
   (test-dep '(propagator.rkt) #f)
   'test-trace-serialize.rkt
   (test-dep '(propagator.rkt trace-serialize.rkt type-lattice.rkt) #f)
   'test-trait-impl-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-trait-impl-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-trait-impl-03.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-trait-impl-04-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-trait-impl-04-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-trait-introspection-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt prelude.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-trait-method-derive.rkt
   (test-dep '(driver.rkt) #t)
   'test-trait-narrowing-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt narrowing.rkt prelude.rkt reduction.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-trait-resolution-bridge.rkt
   (test-dep '(champ.rkt performance-counters.rkt propagator.rkt) #f)
   'test-trait-resolution-propagator.rkt
   (test-dep '(champ.rkt driver.rkt elaborator-network.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt syntax.rkt type-lattice.rkt) #t)
   'test-trait-resolution.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-trait-tycon-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt unify.rkt) #t)
   'test-transducer-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-transducer-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-transient.rkt
   (test-dep '(champ.rkt driver.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt prelude.rkt pretty-print.rkt reduction.rkt rrb.rkt substitution.rkt syntax.rkt typing-core.rkt) #t)
   'test-tropical-fuel.rkt
   (test-dep '(champ.rkt propagator.rkt sre-core.rkt tropical-fuel.rkt) #f)
   'test-tuple-ops.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-tycon.rkt
   (test-dep '(driver.rkt global-env.rkt metavar-store.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt trait-resolution.rkt typing-core.rkt unify.rkt zonk.rkt) #f)
   'test-type-lattice.rkt
   (test-dep '(champ.rkt prelude.rkt propagator.rkt syntax.rkt type-lattice.rkt) #f)
   'test-type-syntax-refactor.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt parser.rkt prelude.rkt sexp-readtable.rkt surface-syntax.rkt syntax.rkt typing-core.rkt) #f)
   'test-typing-fuel-scoping.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt propagator.rkt) #t)
   'test-typing-sessions.rkt
   (test-dep '(prelude.rkt processes.rkt reduction.rkt sessions.rkt substitution.rkt syntax.rkt typing-sessions.rkt) #f)
   'test-typing.rkt
   (test-dep '(prelude.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-unified-match-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-unify-cell-driven.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt metavar-store.rkt prelude.rkt syntax.rkt) #t)
   'test-unify-propagator.rkt
   (test-dep '(champ.rkt driver.rkt elaborator-network.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt mult-lattice.rkt namespace.rkt prelude.rkt syntax.rkt type-lattice.rkt unify.rkt) #t)
   'test-unify-structural.rkt
   (test-dep '(driver.rkt metavar-store.rkt prelude.rkt syntax.rkt unify.rkt) #f)
   'test-unify.rkt
   (test-dep '(driver.rkt global-env.rkt metavar-store.rkt prelude.rkt reduction.rkt syntax.rkt unify.rkt) #f)
   'test-union-find-integration-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #t)
   'test-union-find-integration-02.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #t)
   'test-union-find-types.rkt
   (test-dep '(global-env.rkt prelude.rkt pretty-print.rkt qtt.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt union-find.rkt) #f)
   'test-union-find.rkt
   (test-dep '(union-find.rkt) #f)
   'test-union-types-atms.rkt
   (test-dep '(atms.rkt classify-inhabit.rkt decision-cell.rkt elab-speculation-bridge.rkt error-explanation.rkt propagator.rkt source-location.rkt syntax.rkt typing-propagators.rkt union-types.rkt) #t)
   'test-union-types.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt surface-syntax.rkt syntax.rkt typing-core.rkt unify.rkt zonk.rkt) #f)
   'test-unit-type.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt) #t)
   'test-universe-level-inference.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt prelude.rkt syntax.rkt unify.rkt zonk.rkt) #t)
   'test-validate-match-scrutinee.rkt
   (test-dep '(driver.rkt errors.rkt) #f)
   'test-validate-node.rkt
   (test-dep '(macros.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt) #f)
   'test-validate.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt propagator.rkt relations.rkt) #t)
   'test-varargs.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parse-reader.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-vec-index-ws.rkt
   (test-dep '(driver.rkt errors.rkt) #f)
   'test-warning-accumulation.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt prelude.rkt propagator.rkt) #t)
   'test-wf-benchmark-01.rkt
   (test-dep '(relations.rkt solver.rkt stratified-eval.rkt syntax.rkt wf-engine.rkt) #f)
   'test-wf-comparison-01.rkt
   (test-dep '(relations.rkt solver.rkt stratified-eval.rkt syntax.rkt wf-engine.rkt) #f)
   'test-wf-engine-01.rkt
   (test-dep '(bilattice.rkt propagator.rkt relations.rkt solver.rkt stratified-eval.rkt syntax.rkt tabling.rkt wf-engine.rkt) #f)
   'test-wf-errors-01.rkt
   (test-dep '(relations.rkt solver.rkt stratified-eval.rkt syntax.rkt wf-engine.rkt) #f)
   'test-wf-literature-01.rkt
   (test-dep '(bilattice.rkt propagator.rkt relations.rkt solver.rkt stratified-eval.rkt syntax.rkt tabling.rkt wf-engine.rkt) #f)
   'test-wf-propagators-01.rkt
   (test-dep '(bilattice.rkt propagator.rkt wf-propagators.rkt) #f)
   'test-wf-tabling-01.rkt
   (test-dep '(propagator.rkt tabling.rkt) #f)
   'test-where-parsing.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-widen-specialization.rkt
   (test-dep '(driver.rkt errors.rkt macros.rkt syntax.rkt) #t)
   'test-widenable-trait.rkt
   (test-dep '() #t)
   'test-widening-fixpoint.rkt
   (test-dep '(champ.rkt propagator.rkt) #f)))

;; ============================================================
;; Layer 2b: Example file → test file mapping
;; ============================================================

(define example-test-map
  ;; Track 10 Phase 5: example-test-map cleared (#lang prologos examples removed)
  (hasheq))

;; ============================================================
;; Layer 3: .prologos library forward-deps
;; ============================================================

(define prologos-lib-deps
  (hasheq
   'prologos::book::arithmetic-traits '(prologos::data::nat prologos::data::string)
   'prologos::book::booleans      '()
   'prologos::book::characters-and-strings '(prologos::data::char prologos::data::list prologos::data::option prologos::data::pair prologos::data::string)
   'prologos::book::collection-functions '()
   'prologos::book::collection-traits '(prologos::data::lseq prologos::data::option)
   'prologos::book::datum-and-homoiconicity '(prologos::data::lseq)
   'prologos::book::equality      '(prologos::core::eq prologos::data::bool prologos::data::char prologos::data::list prologos::data::nat prologos::data::option prologos::data::ordering prologos::data::string)
   'prologos::book::generic-operations '(prologos::core::collection-traits prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::option)
   'prologos::book::hashable      '(prologos::data::list prologos::data::nat prologos::data::option prologos::data::ordering)
   'prologos::book::identity-and-algebra '(prologos::core::arithmetic prologos::core::conversions prologos::core::eq prologos::core::ord prologos::data::list)
   'prologos::book::lattices      '(prologos::core::eq prologos::core::lattice prologos::core::ord prologos::data::bool prologos::data::ordering prologos::data::parity prologos::data::refined-int prologos::data::refined-rat prologos::data::sign)
   'prologos::book::lazy-sequences '(prologos::core::collection-traits prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::option)
   'prologos::book::lists         '(prologos::core::collection-traits prologos::core::eq prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::nat prologos::data::option)
   'prologos::book::maps          '(prologos::core::collection-traits prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::map-entry prologos::data::option)
   'prologos::book::natural-numbers '()
   'prologos::book::ordering      '(prologos::data::bool prologos::data::char prologos::data::nat prologos::data::option prologos::data::ordering prologos::data::string)
   'prologos::book::pairs-and-options '(prologos::data::option)
   'prologos::book::persistent-vectors '(prologos::core::collection-traits prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::nat prologos::data::option)
   'prologos::book::refined-numerics '(prologos::data::option)
   'prologos::book::sets          '(prologos::core::collection-traits prologos::data::list prologos::data::lseq prologos::data::lseq-ops)
   'prologos::book::type-conversions '(prologos::data::option)
   'prologos::core                '()
   'prologos::core::abstract-domains '(prologos::core::lattice prologos::data::bool prologos::data::parity prologos::data::sign)
   'prologos::core::algebra       '(prologos::core::arithmetic prologos::core::conversions prologos::core::eq prologos::core::ord prologos::data::list)
   'prologos::core::arithmetic    '(prologos::data::nat prologos::data::string)
   'prologos::core::capabilities  '()
   'prologos::core::collection-traits '(prologos::data::lseq prologos::data::option)
   'prologos::core::collections   '()
   'prologos::core::conversions   '(prologos::data::option)
   'prologos::core::csv           '(prologos::core::capabilities prologos::core::io prologos::core::string-ops prologos::data::char prologos::data::list prologos::data::string)
   'prologos::core::eq            '(prologos::data::bool prologos::data::char prologos::data::nat prologos::data::option prologos::data::ordering prologos::data::string)
   'prologos::core::eq-derived    '(prologos::core::eq prologos::data::bool prologos::data::list)
   'prologos::core::fio           '()
   'prologos::core::gen           '()
   'prologos::core::generic-ops   '(prologos::core::collection-traits prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::option)
   'prologos::core::hashable      '(prologos::data::list prologos::data::nat prologos::data::option prologos::data::ordering)
   'prologos::core::io            '()
   'prologos::core::io-protocols  '()
   'prologos::core::lattice       '(prologos::core::eq prologos::data::bool)
   'prologos::core::list          '(prologos::core::collection-traits prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::nat prologos::data::option)
   'prologos::core::lseq          '(prologos::core::collection-traits prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::option)
   'prologos::core::map           '(prologos::core::collection-traits prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::map-entry prologos::data::option)
   'prologos::core::ord           '(prologos::data::bool prologos::data::char prologos::data::nat prologos::data::option prologos::data::ordering prologos::data::string)
   'prologos::core::path          '(prologos::data::list)
   'prologos::core::propagator    '(prologos::core::lattice)
   'prologos::core::pvec          '(prologos::core::collection-traits prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::nat prologos::data::option)
   'prologos::core::set           '(prologos::core::collection-traits prologos::data::list prologos::data::lseq prologos::data::lseq-ops)
   'prologos::core::string-ops    '(prologos::data::char prologos::data::list prologos::data::option prologos::data::pair prologos::data::string)
   'prologos::data::bool          '()
   'prologos::data::char          '()
   'prologos::data::datum         '()
   'prologos::data::either        '(prologos::data::option)
   'prologos::data::eq            '()
   'prologos::data::float         '()
   'prologos::data::io-error      '()
   'prologos::data::list          '(prologos::core::eq)
   'prologos::data::lseq          '(prologos::data::option)
   'prologos::data::lseq-ops      '(prologos::data::lseq)
   'prologos::data::map-entry     '()
   'prologos::data::nat           '()
   'prologos::data::never         '()
   'prologos::data::option        '()
   'prologos::data::ordering      '()
   'prologos::data::pair          '()
   'prologos::data::parity        '()
   'prologos::data::path          '(prologos::data::string)
   'prologos::data::reason        '(prologos::core::map prologos::core::string-ops prologos::data::list prologos::data::map-entry prologos::data::result prologos::data::string)
   'prologos::data::refined-int   '(prologos::data::option)
   'prologos::data::refined-rat   '(prologos::data::option)
   'prologos::data::result        '(prologos::data::option)
   'prologos::data::set           '(prologos::data::list)
   'prologos::data::sign          '()
   'prologos::data::string        '()
   'prologos::data::transducer    '(prologos::data::lseq)
   'prologos::io::fs              '()
   'prologos::ocapn::behavior     '(prologos::ocapn::syrup)
   'prologos::ocapn::captp-core   '(prologos::ocapn::message prologos::ocapn::promise)
   'prologos::ocapn::captp-interop-helpers '(prologos::ocapn::core)
   'prologos::ocapn::captp-session '(prologos::ocapn::syrup)
   'prologos::ocapn::captp-wire   '(prologos::ocapn::syrup)
   'prologos::ocapn::core         '(prologos::ocapn::behavior prologos::ocapn::captp-core prologos::ocapn::message prologos::ocapn::promise prologos::ocapn::refr prologos::ocapn::syrup prologos::ocapn::vat)
   'prologos::ocapn::crypto       '(prologos::core::capabilities)
   'prologos::ocapn::handshake    '(prologos::ocapn::syrup)
   'prologos::ocapn::interop-driver '(prologos::ocapn::captp-core)
   'prologos::ocapn::locator      '(prologos::data::list prologos::data::nat)
   'prologos::ocapn::message      '(prologos::ocapn::syrup)
   'prologos::ocapn::netlayer     '(prologos::ocapn::locator)
   'prologos::ocapn::pipelining   '(prologos::ocapn::vat)
   'prologos::ocapn::promise      '(prologos::ocapn::syrup)
   'prologos::ocapn::protocols    '(prologos::ocapn::message)
   'prologos::ocapn::refr         '()
   'prologos::ocapn::syrup        '(prologos::data::list)
   'prologos::ocapn::syrup-wire   '(prologos::ocapn::syrup)
   'prologos::ocapn::tcp-testing  '(prologos::core::capabilities)
   'prologos::ocapn::vat          '(prologos::ocapn::syrup)))

;; ============================================================
;; Layer 3b: Test → .prologos runtime dependencies
;; Which .prologos modules each driver-using test loads via string require
;; Conservative: if a test loads prologos::data::list, it transitively depends on
;; all of list's deps too (handled by transitive closure)
;; ============================================================

(define test-prologos-deps
  (hasheq
   'test-abstract-domains.rkt     '(prologos::core::abstract-domains prologos::core::lattice prologos::data::parity prologos::data::sign)
   'test-abstract-interpretation-e2e.rkt '(prologos::core::abstract-domains prologos::core::lattice prologos::data::parity prologos::data::sign)
   'test-arity-checking.rkt       '(prologos::data::list prologos::data::nat)
   'test-auto-implicits.rkt       '(prologos::data::list)
   'test-bundles.rkt              '(prologos::core::eq)
   'test-call-site-specialization.rkt '(prologos::core::lattice prologos::core::propagator)
   'test-char-string-02.rkt       '(prologos::data::ordering)
   'test-coherence.rkt            '(prologos::core::eq)
   'test-collection-conversions.rkt '(prologos::core::collections prologos::data::list prologos::data::lseq prologos::data::lseq-ops)
   'test-collection-fns-01.rkt    '(prologos::core::collections prologos::data::nat)
   'test-collection-fns-02.rkt    '(prologos::core::collections)
   'test-collection-runners.rkt   '(prologos::book::collection-functions prologos::core::collections prologos::data::list prologos::data::lseq-ops)
   'test-collection-traits-01.rkt '(prologos::core::collection-traits prologos::core::list prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::option)
   'test-collection-traits-02.rkt '(prologos::core::collection-traits prologos::core::list prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::option)
   'test-compile-match-tree-recursive.rkt '(prologos::data::list)
   'test-confluence-01.rkt        '(prologos::data::bool::not prologos::data::list::append prologos::data::list::head prologos::data::list::map prologos::data::nat::add prologos::data::nat::sub)
   'test-constraint-amb-01.rkt    '(prologos::data::nat::add)
   'test-constraint-postponement.rkt '(prologos::core prologos::data::bool prologos::data::list prologos::data::nat)
   'test-core-prelude.rkt         '(prologos::core)
   'test-cross-family-conversions-02.rkt '(prologos::core::conversions)
   'test-cross-family-conversions-03.rkt '(prologos::core::conversions prologos::data::option)
   'test-eq-ord-extended-01.rkt   '(prologos::core::eq prologos::core::eq-derived prologos::core::ord prologos::data::list prologos::data::option prologos::data::ordering)
   'test-eq-ord-extended-02.rkt   '(prologos::core::eq prologos::core::eq-derived prologos::core::ord prologos::data::list prologos::data::option prologos::data::ordering)
   'test-error-messages.rkt       '(prologos::core prologos::data::nat prologos::u3t::bad)
   'test-error-surfacing.rkt      '(prologos::data::list)
   'test-first-rest-01.rkt        '(prologos::data::list prologos::data::list::nil)
   'test-firstclass-ops.rkt       '(prologos::data::list)
   'test-galois-connection.rkt    '(prologos::core::lattice)
   'test-hashable-01.rkt          '(prologos::core::hashable prologos::data::list prologos::data::option prologos::data::ordering)
   'test-hashable-02.rkt          '(prologos::core::hashable prologos::data::list prologos::data::option prologos::data::ordering)
   'test-higher-rank.rkt          '(prologos::data::list)
   'test-hkt-impl.rkt             '(prologos::core::collection-traits prologos::core::list prologos::core::lseq prologos::core::pvec prologos::core::set prologos::data::list)
   'test-hkt-kind.rkt             '(prologos::core::eq prologos::core::ord prologos::data::list prologos::data::option)
   'test-identity-generic-ops.rkt '(prologos::core::algebra prologos::core::arithmetic prologos::data::list)
   'test-implicit-inference.rkt   '(prologos::core prologos::data::list prologos::data::nat prologos::data::option)
   'test-io-csv-02.rkt            '(prologos::core::csv prologos::core::io)
   'test-io-file-01.rkt           '(prologos::core::io)
   'test-io-fio-01.rkt            '(prologos::core::fio)
   'test-io-fs-01.rkt             '(prologos::io::fs)
   'test-io-main-01.rkt           '(prologos::core::csv prologos::core::io)
   'test-io-path-01.rkt           '(prologos::data::io-error prologos::data::path)
   'test-kind-inference-where.rkt '(prologos::core::collection-traits prologos::core::eq prologos::data::lseq)
   'test-kind-inference.rkt       '(prologos::core::collection-traits prologos::data::lseq)
   'test-let-blocks.rkt           '(prologos::u1t::m)
   'test-list-extended-01-01.rkt  '(prologos::core::eq prologos::data::list prologos::data::nat prologos::data::option prologos::data::option::none)
   'test-list-extended-01-02.rkt  '(prologos::core::eq prologos::data::list prologos::data::nat prologos::data::option)
   'test-list-extended-02-01.rkt  '(prologos::core::eq prologos::data::list prologos::data::nat prologos::data::option)
   'test-list-extended-02-02.rkt  '(prologos::core::eq prologos::data::list prologos::data::nat prologos::data::option prologos::data::option::none)
   'test-list-literals.rkt        '(prologos::data::list)
   'test-lseq-01.rkt              '(prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::nat prologos::data::option)
   'test-lseq-02.rkt              '(prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::nat prologos::data::option)
   'test-lseq-literal.rkt         '(prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::nat prologos::data::option)
   'test-lseq-traits.rkt          '(prologos::core::collection-traits prologos::core::lseq prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::option)
   'test-map-bridge.rkt           '(prologos::core::map prologos::data::lseq prologos::data::lseq-ops prologos::data::map-entry)
   'test-map-entry.rkt            '(prologos::data::map-entry)
   'test-map-set-traits-01.rkt    '(prologos::core::collection-traits prologos::core::map prologos::core::set prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::option prologos::data::set)
   'test-map-set-traits-02.rkt    '(prologos::core::collection-traits prologos::core::map prologos::core::set prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::nat prologos::data::option prologos::data::set)
   'test-method-resolution.rkt    '(prologos::core::eq prologos::data::bool)
   'test-mult-inference.rkt       '(prologos::core prologos::data::nat)
   'test-narrowing-search-01.rkt  '(prologos::data::bool::not prologos::data::nat::add)
   'test-new-lattice-cell.rkt     '(prologos::core::lattice prologos::core::propagator)
   'test-numeric-traits-01.rkt    '(prologos::core::arithmetic)
   'test-numeric-traits-02.rkt    '(prologos::core::algebra prologos::core::arithmetic prologos::core::conversions prologos::core::eq prologos::core::ord prologos::data::nat)
   'test-ocapn-abort.rkt          '(prologos::data::list prologos::data::option prologos::ocapn::captp-wire prologos::ocapn::message prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-acceptance-l3.rkt  '(prologos::data::list prologos::data::option prologos::ocapn prologos::ocapn::core)
   'test-ocapn-behavior.rkt       '(prologos::data::list prologos::data::option prologos::ocapn::behavior prologos::ocapn::syrup)
   'test-ocapn-bidirectional-interop.rkt '(prologos::data::option prologos::ocapn::captp-core prologos::ocapn::captp-interop-helpers prologos::ocapn::captp-wire prologos::ocapn::core prologos::ocapn::message prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-bootstrap-gift-interop.rkt '(prologos::data::option prologos::ocapn::captp-core prologos::ocapn::captp-interop-helpers prologos::ocapn::captp-wire prologos::ocapn::core prologos::ocapn::message prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-break-plain-interop.rkt '(prologos::data::option prologos::ocapn::captp-core prologos::ocapn::captp-interop-helpers prologos::ocapn::captp-wire prologos::ocapn::core prologos::ocapn::message prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-bridge-interop.rkt '(prologos::data::list prologos::data::option prologos::ocapn::captp-interop-helpers prologos::ocapn::core prologos::ocapn::message)
   'test-ocapn-bridge.rkt         '(prologos::data::list prologos::data::option prologos::data::string prologos::ocapn::captp-core prologos::ocapn::captp-interop-helpers prologos::ocapn::captp-wire prologos::ocapn::core prologos::ocapn::handshake prologos::ocapn::interop-driver prologos::ocapn::message prologos::ocapn::pipelining prologos::ocapn::syrup-wire)
   'test-ocapn-captp-wire.rkt     '(prologos::data::list prologos::data::option prologos::ocapn::captp-wire prologos::ocapn::message prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-captp.rkt          '(prologos::data::option prologos::ocapn::captp-session prologos::ocapn::message prologos::ocapn::syrup)
   'test-ocapn-conversation.rkt   '(prologos::data::list prologos::data::option prologos::ocapn::captp-wire prologos::ocapn::message prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-e2e.rkt            '(prologos::data::list prologos::data::option prologos::ocapn::core)
   'test-ocapn-handoff.rkt        '(prologos::data::list prologos::data::option prologos::data::string prologos::ocapn::captp-core prologos::ocapn::captp-interop-helpers prologos::ocapn::captp-wire prologos::ocapn::core prologos::ocapn::crypto prologos::ocapn::handshake prologos::ocapn::interop-driver prologos::ocapn::message prologos::ocapn::pipelining prologos::ocapn::syrup-wire)
   'test-ocapn-handshake.rkt      '(prologos::data::list prologos::data::option prologos::data::string prologos::ocapn::captp-wire prologos::ocapn::crypto prologos::ocapn::handshake prologos::ocapn::message prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-import-object-interop.rkt '(prologos::data::option prologos::ocapn::captp-core prologos::ocapn::captp-interop-helpers prologos::ocapn::captp-wire prologos::ocapn::core prologos::ocapn::message prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-live-interop.rkt   '(prologos::data::list prologos::data::option prologos::ocapn::captp-wire prologos::ocapn::message prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-location-key.rkt   '(prologos::data::list prologos::data::option prologos::data::string prologos::ocapn::interop-driver prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-locator.rkt        '(prologos::data::option prologos::ocapn::locator)
   'test-ocapn-message.rkt        '(prologos::data::list prologos::data::option prologos::ocapn::message prologos::ocapn::syrup)
   'test-ocapn-multi-questioner-interop.rkt '(prologos::data::option prologos::ocapn::captp-interop-helpers prologos::ocapn::captp-wire prologos::ocapn::core prologos::ocapn::message prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-netlayer-tcp.rkt   '(prologos::data::list prologos::data::option prologos::ocapn::captp-wire prologos::ocapn::message prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-netlayer.rkt       '(prologos::data::list prologos::data::option prologos::ocapn::locator prologos::ocapn::netlayer prologos::ocapn::syrup)
   'test-ocapn-pipeline-forwarding-interop.rkt '(prologos::data::option prologos::ocapn::captp-core prologos::ocapn::captp-interop-helpers prologos::ocapn::captp-wire prologos::ocapn::core prologos::ocapn::message prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-pipeline.rkt       '(prologos::data::bool prologos::data::list prologos::data::option prologos::ocapn::behavior prologos::ocapn::promise prologos::ocapn::syrup prologos::ocapn::vat)
   'test-ocapn-pipelined.rkt      '(prologos::data::list prologos::data::option prologos::ocapn::captp-wire prologos::ocapn::message prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-pipelining-interop.rkt '(prologos::data::option prologos::ocapn::captp-core prologos::ocapn::captp-interop-helpers prologos::ocapn::captp-wire prologos::ocapn::core prologos::ocapn::message prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-pipelining.rkt     '(prologos::data::list prologos::data::option prologos::ocapn::core prologos::ocapn::pipelining)
   'test-ocapn-promise.rkt        '(prologos::data::list prologos::data::option prologos::ocapn::promise prologos::ocapn::syrup)
   'test-ocapn-questioner-interop.rkt '(prologos::data::option prologos::ocapn::captp-interop-helpers prologos::ocapn::captp-wire prologos::ocapn::core prologos::ocapn::message prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-refr-passing-interop.rkt '(prologos::data::option prologos::ocapn::captp-core prologos::ocapn::captp-interop-helpers prologos::ocapn::captp-wire prologos::ocapn::core prologos::ocapn::message prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-refr.rkt           '(prologos::ocapn::refr)
   'test-ocapn-rpc.rkt            '(prologos::data::list prologos::data::option prologos::ocapn::captp-wire prologos::ocapn::message prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-syrup-cross-impl.rkt '(prologos::data::list prologos::data::option prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-syrup-wire.rkt     '(prologos::data::list prologos::data::option prologos::data::string prologos::ocapn::handshake prologos::ocapn::syrup prologos::ocapn::syrup-wire)
   'test-ocapn-syrup.rkt          '(prologos::data::list prologos::data::option prologos::ocapn::syrup)
   'test-ocapn-vat.rkt            '(prologos::data::list prologos::data::nat prologos::data::option prologos::ocapn::behavior prologos::ocapn::promise prologos::ocapn::syrup prologos::ocapn::vat)
   'test-path-selection.rkt       '(prologos::core::path prologos::data::reason prologos::data::reason::missing-required prologos::data::result prologos::nonexistent::module)
   'test-pipe-compose-e2e-01.rkt  '(prologos::data::list prologos::data::nat prologos::data::transducer)
   'test-pipe-compose-e2e-02a.rkt '(prologos::data::list prologos::data::nat prologos::data::transducer)
   'test-pipe-compose-e2e-02b.rkt '(prologos::data::list prologos::data::nat prologos::data::transducer)
   'test-pipe-compose-e2e-03.rkt  '(prologos::data::list prologos::data::nat prologos::data::transducer)
   'test-posit-float-conversions.rkt '(prologos::core::conversions)
   'test-posit-identity.rkt       '(prologos::core::algebra prologos::core::arithmetic prologos::data::list)
   'test-prelude-system-01.rkt    '(prologos::core)
   'test-prelude-system-02.rkt    '(prologos::core prologos::core::test-dep prologos::data prologos::data::nat prologos::data::test-dep prologos::data::test-dep2)
   'test-prim-op-firstclass.rkt   '(prologos::data::list)
   'test-pvec-traits.rkt          '(prologos::core::pvec prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::nat prologos::data::option)
   'test-pvec-zip-with.rkt        '(prologos::core::pvec)
   'test-qtt-pipeline.rkt         '(prologos::data::bool prologos::data::nat)
   'test-quote.rkt                '(prologos::data::datum)
   'test-rat-literal-in-list.rkt  '(prologos::data::list)
   'test-reducible-01.rkt         '(prologos::core::collection-traits prologos::core::collections prologos::core::list prologos::core::lseq prologos::core::pvec prologos::core::set prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::nat prologos::data::option)
   'test-reducible-02.rkt         '(prologos::core::collection-traits prologos::core::collections prologos::core::list prologos::core::lseq prologos::core::pvec prologos::core::set prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::nat prologos::data::option)
   'test-refined-int.rkt          '(prologos::data::option prologos::data::refined-int)
   'test-refined-rat.rkt          '(prologos::data::option prologos::data::refined-rat)
   'test-refined-subtyping.rkt    '(prologos::data::option prologos::data::refined-int prologos::data::refined-rat)
   'test-rel-t1-typed-rows.rkt    '(prologos::data::list)
   'test-sexp-reader-parity.rkt   '(prologos::data::list)
   'test-sign-galois.rkt          '(prologos::core::abstract-domains prologos::core::lattice prologos::data::sign)
   'test-spec-mult-01.rkt         '(prologos::core::fio)
   'test-sprint10.rkt             '(prologos::data::nat)
   'test-stdlib-01-data-01.rkt    '(prologos::data::bool prologos::data::eq prologos::data::nat prologos::data::option prologos::data::ordering prologos::data::pair prologos::data::result)
   'test-stdlib-01-data-02.rkt    '(prologos::data::bool prologos::data::eq prologos::data::list prologos::data::nat prologos::data::option prologos::data::ordering prologos::data::pair prologos::data::result)
   'test-stdlib-01-data-03.rkt    '(prologos::data::bool prologos::data::eq prologos::data::nat prologos::data::option prologos::data::ordering prologos::data::pair prologos::data::result)
   'test-stdlib-01-data-04.rkt    '(prologos::core prologos::data::bool prologos::data::eq prologos::data::nat prologos::data::option prologos::data::ordering prologos::data::pair prologos::data::result)
   'test-stdlib-02-traits-01.rkt  '(prologos::data::option prologos::data::ordering prologos::data::result)
   'test-stdlib-02-traits-02.rkt  '(prologos::data::nat prologos::data::option prologos::data::result)
   'test-stdlib-02-traits-03.rkt  '(prologos::data::list prologos::data::nat)
   'test-stdlib-02-traits-04.rkt  '(prologos::core::eq prologos::core::ord prologos::data::list prologos::data::ordering)
   'test-stdlib-02-traits-05.rkt  '(prologos::core::eq prologos::core::ord prologos::data::list)
   'test-stdlib-02-traits-06.rkt  '(prologos::data::list prologos::data::nat prologos::data::option prologos::data::ordering prologos::data::result)
   'test-stdlib-02-traits-07.rkt  '(prologos::data::list prologos::data::nat prologos::data::option prologos::data::result)
   'test-stdlib-03-list-01.rkt    '(prologos::data::list prologos::data::nat prologos::data::option)
   'test-stdlib-03-list-02.rkt    '(prologos::data::list prologos::data::nat prologos::data::option)
   'test-stdlib-03-list-03.rkt    '(prologos::data::list prologos::data::nat)
   'test-stdlib-03-list-04-01.rkt '(prologos::data::list)
   'test-stdlib-03-list-04-02.rkt '(prologos::data::list prologos::data::nat)
   'test-stdlib-03-list-05.rkt    '(prologos::data::list prologos::data::nat)
   'test-string-normalize.rkt     '(prologos::core::string-ops prologos::data::list prologos::data::string)
   'test-string-ops.rkt           '(prologos::core::string-ops prologos::data::option prologos::data::option::none prologos::data::option::some)
   'test-subtyping.rkt            '(prologos::data::nat)
   'test-surface-defmacro-01.rkt  '(prologos::core prologos::data::nat)
   'test-surface-defmacro-02.rkt  '(prologos::data::nat)
   'test-termination-01.rkt       '(prologos::data::bool::not prologos::data::list::append prologos::data::list::head prologos::data::list::map prologos::data::nat::add prologos::data::nat::sub)
   'test-trait-impl-02.rkt        '(prologos::data::either prologos::data::either::right prologos::data::nat prologos::data::never prologos::data::option prologos::data::pair prologos::data::result)
   'test-trait-impl-03.rkt        '(prologos::core::eq prologos::core::ord prologos::data::ordering)
   'test-trait-impl-04-01.rkt     '(prologos::core::collection-traits prologos::core::list prologos::data::list prologos::data::list::nil prologos::data::nat prologos::data::option prologos::data::option::none prologos::data::option::some)
   'test-trait-impl-04-02.rkt     '(prologos::core::generic-ops prologos::core::list prologos::data::list prologos::data::nat prologos::data::option prologos::data::option::none prologos::data::option::some)
   'test-trait-resolution.rkt     '(prologos::core::eq prologos::data::bool prologos::data::list)
   'test-transducer-01.rkt        '(prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::transducer)
   'test-transducer-02.rkt        '(prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::nat prologos::data::transducer)
   'test-unit-type.rkt            '(prologos::data::list)
   'test-universe-level-inference.rkt '(prologos::core prologos::data::bool prologos::data::nat)
   'test-validate.rkt             '(prologos::data::reason prologos::data::reason::unexpected-field)
   'test-varargs.rkt              '(prologos::data::list)
   'test-where-parsing.rkt        '(prologos::core::eq)
   'test-widen-specialization.rkt '(prologos::core::lattice prologos::core::propagator)
   'test-widenable-trait.rkt      '(prologos::core::lattice)))

;; ============================================================
;; File scanning functions (used for auto-scan of unknown modules)
;; Also shared with update-deps.rkt for --check mode.
;; ============================================================

;; Read a .rkt file and extract local require deps ("foo.rkt" or "../foo.rkt" patterns)
;; Handles #lang line by reading it first via read-language
(define (scan-rkt-requires filepath)
  (with-handlers ([exn:fail? (λ (e) '())])
    (define port (open-input-file filepath))
    (port-count-lines! port)
    (read-language port (λ () (void)))
    (define forms
      (let loop ([acc '()])
        (define form (read port))
        (if (eof-object? form)
            (reverse acc)
            (loop (cons form acc)))))
    (close-input-port port)
    (define deps (mutable-seteq))
    (for ([form (in-list forms)])
      (when (and (pair? form) (eq? (car form) 'require))
        (extract-string-requires (cdr form) deps)))
    (sort (set->list deps) symbol<?)))

;; Walk a require spec extracting string paths that reference local .rkt files
(define (extract-string-requires specs deps)
  (for ([spec (in-list specs)])
    (cond
      [(string? spec)
       (define base (last (string-split spec "/")))
       (when (string-suffix? base ".rkt")
         (set-add! deps (string->symbol base)))]
      [(and (pair? spec)
            (memq (car spec) '(only-in except-in prefix-in rename-in combine-in
                               relative-in for-syntax for-template for-label)))
       (extract-string-requires (cdr spec) deps)]
      [(and (pair? spec) (eq? (car spec) 'file)
            (pair? (cdr spec)) (string? (cadr spec)))
       (define base (last (string-split (cadr spec) "/")))
       (when (string-suffix? base ".rkt")
         (set-add! deps (string->symbol base)))])))

;; Scan a test file for its source module requires (../foo.rkt patterns)
(define (scan-test-source-deps filepath)
  (with-handlers ([exn:fail? (λ (e) '())])
    (define port (open-input-file filepath))
    (port-count-lines! port)
    (read-language port (λ () (void)))
    (define forms
      (let loop ([acc '()])
        (define form (read port))
        (if (eof-object? form)
            (reverse acc)
            (loop (cons form acc)))))
    (close-input-port port)
    (define deps (mutable-seteq))
    (for ([form (in-list forms)])
      (when (and (pair? form) (eq? (car form) 'require))
        (extract-test-source-requires (cdr form) deps)))
    (sort (set->list deps) symbol<?)))

(define (extract-test-source-requires specs deps)
  (for ([spec (in-list specs)])
    (cond
      [(string? spec)
       (when (string-prefix? spec "../")
         (define base (substring spec 3))
         (when (and (string-suffix? base ".rkt")
                    (not (string-contains? base "/")))
           (set-add! deps (string->symbol base))))]
      [(and (pair? spec)
            (memq (car spec) '(only-in except-in prefix-in rename-in combine-in
                               relative-in for-syntax for-template for-label)))
       (extract-test-source-requires (cdr spec) deps)])))

;; Check if a test file uses the driver (run-ns, run-last, run-ws, etc.)
(define (test-uses-driver? filepath)
  (with-handlers ([exn:fail? (λ (e) #f)])
    (define content (file->string filepath))
    (or (string-contains? content "run-ns")
        (string-contains? content "run-last")
        (string-contains? content "run-ws")
        (string-contains? content "run-lang")
        (string-contains? content "run-sexp"))))

;; Scan a test file for .prologos runtime module loads
(define (scan-test-prologos-deps filepath)
  (with-handlers ([exn:fail? (λ (e) '())])
    (define content (file->string filepath))
    (define deps (mutable-seteq))
    (for ([m (in-list (regexp-match* #rx"prologos::[a-z][a-z0-9:_-]*[a-z0-9]" content))])
      (set-add! deps (string->symbol m)))
    (sort (set->list deps) symbol<?)))

;; Scan a .prologos file for require deps
(define (scan-prologos-requires filepath)
  (with-handlers ([exn:fail? (λ (e) '())])
    (define content (file->string filepath))
    (define deps (mutable-seteq))
    (for ([m (in-list (regexp-match* #rx"require +\\[?(prologos::[a-z][a-z0-9:_-]*)" content))])
      (define match-result (regexp-match #rx"(prologos::[a-z][a-z0-9:_-]*)" m))
      (when match-result
        (set-add! deps (string->symbol (cadr match-result)))))
    (sort (set->list deps) symbol<?)))

;; Convert a prologos module name to its filesystem path
;; e.g., 'prologos::data::nat + project-root → project-root/lib/prologos/data/nat.prologos
(define (prologos-mod->path mod-sym project-root)
  (define parts (string-split (symbol->string mod-sym) "::"))
  ;; prologos::data::nat → lib/prologos/data/nat.prologos
  (define rel-parts (cdr parts))  ; drop leading "prologos"
  (define dir-parts (drop-right rel-parts 1))
  (define filename (string-append (last rel-parts) ".prologos"))
  (apply build-path project-root "lib" "prologos"
         (append dir-parts (list filename))))

;; ============================================================
;; Graph algorithms
;; ============================================================

;; Invert a forward-dep hash: {A → (B C)} becomes {B → (A), C → (A)}
(define (invert-dag dag)
  (define result (make-hasheq))
  ;; Initialize all keys with empty lists
  (for ([k (in-hash-keys dag)])
    (hash-set! result k '()))
  (for ([(mod deps) (in-hash dag)])
    (for ([dep (in-list deps)])
      (hash-set! result dep (cons mod (hash-ref result dep '())))))
  (for/hasheq ([(k v) (in-hash result)])
    (values k (remove-duplicates v))))

;; BFS transitive closure: given reverse-dag and start nodes,
;; return all nodes reachable from start (inclusive)
(define (transitive-closure reverse-dag start-nodes)
  (define visited (mutable-seteq))
  (define queue (list->mutable-seteq (set->list start-nodes)))
  (let loop ()
    (cond
      [(set-empty? queue) visited]
      [else
       (define node (set-first queue))
       (set-remove! queue node)
       (unless (set-member? visited node)
         (set-add! visited node)
         (for ([dep (in-list (hash-ref reverse-dag node '()))])
           (unless (set-member? visited dep)
             (set-add! queue dep))))
       (loop)])))

;; Convenience: convert mutable set to immutable
(define (list->mutable-seteq lst)
  (define s (mutable-seteq))
  (for ([x (in-list lst)]) (set-add! s x))
  s)

;; Compute full reverse-dep closure for a DAG
(define (compute-reverse-closure forward-deps)
  (invert-dag forward-deps))

;; ============================================================
;; Precomputed reverse-dep maps (computed once at module load)
;; ============================================================

(define source-reverse-deps   (compute-reverse-closure source-deps))
(define prologos-reverse-deps (compute-reverse-closure prologos-lib-deps))

;; ============================================================
;; Main algorithm: compute-affected-tests
;; ============================================================

;; Main entry point.
;; #:project-root — if provided, unknown modules are auto-scanned from disk
;;   instead of falling back to "run all". Pass the prologos/ directory path.
(define (compute-affected-tests changed-files #:project-root [project-root #f])
  (define affected-tests (mutable-seteq))

  ;; Classify changed files
  (define changed-sources (mutable-seteq))
  (define changed-prologos-mods (mutable-seteq))
  (define changed-tests-list (mutable-seteq))

  (for ([cf (in-list changed-files)])
    (cond
      [(changed-source? cf)
       (set-add! changed-sources (changed-source-name cf))]
      [(changed-test? cf)
       ;; Always re-run a changed test
       (set-add! affected-tests (changed-test-name cf))
       (set-add! changed-tests-list (changed-test-name cf))]
      [(changed-prologos? cf)
       (set-add! changed-prologos-mods (changed-prologos-name cf))]
      [(changed-example? cf)
       ;; Map example → test files
       (define tests (hash-ref example-test-map (changed-example-name cf) '()))
       (for ([t (in-list tests)])
         (set-add! affected-tests t))]))

  ;; Detect unknown modules not in DAG
  (define unknown-sources
    (for/list ([s (in-set changed-sources)]
               #:when (not (hash-has-key? source-deps s)))
      s))
  (define unknown-prologos
    (for/list ([p (in-set changed-prologos-mods)]
               #:when (not (hash-has-key? prologos-lib-deps p)))
      p))
  (define unknown-tests
    (for/list ([t (in-set changed-tests-list)]
               #:when (not (hash-has-key? test-deps t)))
      t))

  ;; Build working copies of DAG data, possibly patched with auto-scanned entries
  (define effective-source-deps source-deps)
  (define effective-test-deps test-deps)
  (define effective-prologos-deps prologos-lib-deps)
  (define effective-test-prologos test-prologos-deps)

  ;; Auto-scan unknown modules if project-root is available
  (define has-unknowns?
    (or (pair? unknown-sources) (pair? unknown-prologos) (pair? unknown-tests)))

  (when (and has-unknowns? project-root)
    (eprintf "Auto-scanning ~a new module(s) not in dep-graph.rkt:\n"
             (+ (length unknown-sources) (length unknown-prologos) (length unknown-tests)))

    ;; Auto-scan unknown source modules
    (for ([s (in-list unknown-sources)])
      (define filepath (build-path project-root (symbol->string s)))
      (cond
        [(file-exists? filepath)
         (define deps (scan-rkt-requires filepath))
         ;; Filter to known source modules only
         (define known (list->seteq (hash-keys effective-source-deps)))
         (define filtered (filter (λ (d) (set-member? known d)) deps))
         (eprintf "  source: ~a → deps: ~a\n" s filtered)
         (set! effective-source-deps
               (hash-set effective-source-deps s filtered))]
        [else
         (eprintf "  source: ~a (file not found, using empty deps)\n" s)
         (set! effective-source-deps
               (hash-set effective-source-deps s '()))]))

    ;; Auto-scan unknown .prologos modules
    (for ([p (in-list unknown-prologos)])
      (define filepath (prologos-mod->path p project-root))
      (cond
        [(file-exists? filepath)
         (define deps (scan-prologos-requires (path->string filepath)))
         (eprintf "  prologos: ~a → deps: ~a\n" p deps)
         (set! effective-prologos-deps
               (hash-set effective-prologos-deps p deps))]
        [else
         (eprintf "  prologos: ~a (file not found, using empty deps)\n" p)
         (set! effective-prologos-deps
               (hash-set effective-prologos-deps p '()))]))

    ;; Auto-scan unknown test files
    (for ([t (in-list unknown-tests)])
      (define filepath (build-path project-root "tests" (symbol->string t)))
      (cond
        [(file-exists? filepath)
         (define src-deps (scan-test-source-deps filepath))
         (define driver? (test-uses-driver? filepath))
         (eprintf "  test: ~a → src-deps: ~a, driver?: ~a\n" t src-deps driver?)
         (set! effective-test-deps
               (hash-set effective-test-deps t (test-dep src-deps driver?)))
         ;; Also scan prologos deps if it uses the driver
         (when driver?
           (define pl-deps (scan-test-prologos-deps filepath))
           (unless (null? pl-deps)
             (set! effective-test-prologos
                   (hash-set effective-test-prologos t pl-deps))))]
        [else
         (eprintf "  test: ~a (file not found, skipping)\n" t)])))

  ;; If unknowns exist but no project-root provided, fall back to all tests
  (when (and has-unknowns? (not project-root))
    (eprintf "WARNING: Unknown modules detected (not in dep-graph.rkt):\n")
    (for ([s (in-list unknown-sources)])
      (eprintf "  source: ~a\n" s))
    (for ([p (in-list unknown-prologos)])
      (eprintf "  prologos: ~a\n" p))
    (for ([t (in-list unknown-tests)])
      (eprintf "  test: ~a\n" t))
    (eprintf "Running ALL tests (no project-root for auto-scan).\n")
    (eprintf "Pass #:project-root or update dep-graph.rkt manually.\n")
    (for ([t (in-list (all-test-files))])
      (set-add! affected-tests t)))

  ;; Compute reverse-deps from effective (possibly patched) data
  (define eff-source-reverse (compute-reverse-closure effective-source-deps))
  (define eff-prologos-reverse (compute-reverse-closure effective-prologos-deps))

  ;; Step 1: Expand source changes to transitive dependents
  (define source-closure
    (if (set-empty? changed-sources)
        (seteq)
        (transitive-closure eff-source-reverse changed-sources)))

  ;; Step 2: Map source closure to affected tests
  (for ([(test-name td) (in-hash effective-test-deps)])
    (define test-mods (test-dep-source-modules td))
    (when (for/or ([m (in-list test-mods)])
            (set-member? source-closure m))
      (set-add! affected-tests test-name)))

  ;; Step 3: Expand .prologos changes to transitive dependents
  (define prologos-closure
    (if (set-empty? changed-prologos-mods)
        (seteq)
        (transitive-closure eff-prologos-reverse changed-prologos-mods)))

  ;; Step 4: Map .prologos closure to affected tests
  (unless (set-empty? prologos-closure)
    (for ([(test-name prologos-mods) (in-hash effective-test-prologos)])
      (when (for/or ([m (in-list prologos-mods)])
              (set-member? prologos-closure m))
        (set-add! affected-tests test-name))))

  ;; Convert to sorted list
  (sort (set->list affected-tests) symbol<?))

;; ============================================================
;; Utility: all test files
;; ============================================================

(define (all-test-files)
  (sort (hash-keys test-deps) symbol<?))
