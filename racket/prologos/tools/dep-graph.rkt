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
   'atms.rkt                      '(propagator.rkt)
   'cap-type-bridge.rkt           '(capability-inference.rkt global-env.rkt macros.rkt propagator.rkt syntax.rkt type-lattice.rkt)
   'capability-inference.rkt      '(atms.rkt global-env.rkt macros.rkt propagator.rkt syntax.rkt)
   'champ.rkt                     '()
   'driver.rkt                    '(atms.rkt cap-type-bridge.rkt capability-inference.rkt champ.rkt elab-speculation-bridge.rkt elaborator-network.rkt elaborator.rkt errors.rkt foreign.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt performance-counters.rkt prelude.rkt pretty-print.rkt propagator.rkt qtt.rkt reader.rkt reduction.rkt relations.rkt sexp-readtable.rkt source-location.rkt stratified-eval.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt type-lattice.rkt typing-core.rkt typing-errors.rkt unify.rkt warnings.rkt zonk.rkt)
   'elab-speculation-bridge.rkt   '(atms.rkt metavar-store.rkt performance-counters.rkt)
   'elab-speculation.rkt          '(atms.rkt elaborator-network.rkt propagator.rkt type-lattice.rkt)
   'elaborator-network.rkt        '(champ.rkt propagator.rkt syntax.rkt type-lattice.rkt)
   'elaborator.rkt                '(champ.rkt errors.rkt foreign.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt performance-counters.rkt posit-impl.rkt prelude.rkt pretty-print.rkt source-location.rkt substitution.rkt surface-syntax.rkt syntax.rkt warnings.rkt)
   'errors.rkt                    '(source-location.rkt)
   'expander.rkt                  '(elaborator.rkt errors.rkt global-env.rkt lang-error.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt repl-support.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt typing-errors.rkt zonk.rkt)
   'foreign.rkt                   '(syntax.rkt)
   'global-env.rkt                '()
   'inductive.rkt                 '(syntax.rkt typing-core.rkt)
   'lang-error.rkt                '(errors.rkt source-location.rkt)
   'macros.rkt                    '(errors.rkt global-env.rkt namespace.rkt source-location.rkt surface-syntax.rkt syntax.rkt)
   'main.rkt                      '(expander.rkt repl-support.rkt)
   'metavar-store.rkt             '(champ.rkt performance-counters.rkt prelude.rkt sessions.rkt source-location.rkt syntax.rkt)
   'multi-dispatch.rkt            '()
   'namespace.rkt                 '()
   'parser.rkt                    '(errors.rkt macros.rkt sexp-readtable.rkt source-location.rkt surface-syntax.rkt)
   'performance-counters.rkt      '()
   'posit-impl.rkt                '()
   'prelude.rkt                   '()
   'pretty-print.rkt              '(atms.rkt champ.rkt metavar-store.rkt prelude.rkt propagator.rkt rrb.rkt sessions.rkt syntax.rkt tabling.rkt union-find.rkt)
   'processes.rkt                 '(sessions.rkt)
   'propagator.rkt                '(champ.rkt)
   'provenance.rkt                '()
   'qtt.rkt                       '(elab-speculation-bridge.rkt global-env.rkt metavar-store.rkt prelude.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt unify.rkt)
   'reader.rkt                    '()
   'reduction.rkt                 '(atms.rkt champ.rkt foreign.rkt global-env.rkt macros.rkt metavar-store.rkt performance-counters.rkt posit-impl.rkt prelude.rkt propagator.rkt provenance.rkt relations.rkt rrb.rkt solver.rkt stratified-eval.rkt substitution.rkt syntax.rkt tabling.rkt union-find.rkt)
   'relations.rkt                 '(performance-counters.rkt propagator.rkt provenance.rkt solver.rkt syntax.rkt tabling.rkt union-find.rkt)
   'repl-support.rkt              '(driver.rkt errors.rkt global-env.rkt macros.rkt parser.rkt)
   'repl.rkt                      '(driver.rkt errors.rkt global-env.rkt macros.rkt parser.rkt pretty-print.rkt reader.rkt sexp-readtable.rkt source-location.rkt)
   'rrb.rkt                       '()
   'sessions.rkt                  '(prelude.rkt substitution.rkt syntax.rkt)
   'sexp-readtable.rkt            '()
   'sexp.rkt                      '(main.rkt)
   'solver.rkt                    '()
   'source-location.rkt           '()
   'stratified-eval.rkt           '(relations.rkt solver.rkt stratify.rkt syntax.rkt tabling.rkt)
   'stratify.rkt                  '()
   'substitution.rkt              '(prelude.rkt syntax.rkt)
   'surface-syntax.rkt            '(source-location.rkt)
   'syntax.rkt                    '(prelude.rkt)
   'tabling.rkt                   '(propagator.rkt)
   'trait-resolution.rkt          '(errors.rkt macros.rkt metavar-store.rkt performance-counters.rkt prelude.rkt pretty-print.rkt source-location.rkt syntax.rkt unify.rkt zonk.rkt)
   'type-lattice.rkt              '(prelude.rkt reduction.rkt substitution.rkt syntax.rkt zonk.rkt)
   'typing-core.rkt               '(elab-speculation-bridge.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt performance-counters.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt unify.rkt warnings.rkt)
   'typing-errors.rkt             '(atms.rkt elab-speculation-bridge.rkt errors.rkt global-env.rkt performance-counters.rkt prelude.rkt pretty-print.rkt qtt.rkt reduction.rkt source-location.rkt syntax.rkt typing-core.rkt)
   'typing-sessions.rkt           '(metavar-store.rkt prelude.rkt processes.rkt reduction.rkt sessions.rkt substitution.rkt syntax.rkt typing-core.rkt)
   'unify.rkt                     '(metavar-store.rkt performance-counters.rkt prelude.rkt reduction.rkt source-location.rkt substitution.rkt syntax.rkt zonk.rkt)
   'union-find.rkt                '()
   'warnings.rkt                  '()
   'zonk.rkt                      '(metavar-store.rkt performance-counters.rkt substitution.rkt syntax.rkt)))

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
   'test-approx-literal.rkt
   (test-dep '(driver.rkt global-env.rkt parser.rkt posit-impl.rkt prelude.rkt reader.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-arity-checking.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-atms-integration.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-atms-types.rkt
   (test-dep '(atms.rkt global-env.rkt prelude.rkt pretty-print.rkt propagator.rkt qtt.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-atms.rkt
   (test-dep '(atms.rkt propagator.rkt) #f)
   'test-auto-implicits.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt) #t)
   'test-bare-methods.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
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
   'test-char-string.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt reader.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
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
   'test-collection-traits-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-collection-traits-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-config-audit.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt pretty-print.rkt reader.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt warnings.rkt) #f)
   'test-constraint-inference.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-constraint-postponement.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt prelude.rkt syntax.rkt unify.rkt zonk.rkt) #t)
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
   'test-decimal-literal.rkt
   (test-dep '(driver.rkt global-env.rkt parser.rkt posit-impl.rkt prelude.rkt reader.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-defmacro.rkt
   (test-dep '(macros.rkt) #f)
   'test-dot-access.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt reader.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-elab-speculation.rkt
   (test-dep '(atms.rkt elab-speculation.rkt elaborator-network.rkt prelude.rkt propagator.rkt syntax.rkt type-lattice.rkt) #f)
   'test-elaborator-network.rkt
   (test-dep '(elaborator-network.rkt propagator.rkt syntax.rkt type-lattice.rkt) #f)
   'test-structural-decomp.rkt
   (test-dep '(elaborator-network.rkt propagator.rkt syntax.rkt type-lattice.rkt) #f)
   'test-elaborator.rkt
   (test-dep '(elaborator.rkt errors.rkt global-env.rkt metavar-store.rkt parser.rkt prelude.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-eliminator-typing.rkt
   (test-dep '(prelude.rkt qtt.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-eq-ord-extended-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-eq-ord-extended-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-error-messages.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt unify.rkt) #t)
   'test-errors.rkt
   (test-dep '(errors.rkt source-location.rkt) #f)
   'test-extended-spec.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt parser.rkt pretty-print.rkt reader.rkt source-location.rkt surface-syntax.rkt syntax.rkt warnings.rkt) #f)
   'test-foreign-block.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt foreign.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-foreign.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt foreign.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-free-ordering.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt) #t)
   'test-functor-ws.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt parser.rkt pretty-print.rkt reader.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-galois-connection.rkt
   (test-dep '() #t)
   'test-generators.rkt
   (test-dep '(global-env.rkt metavar-store.rkt performance-counters.rkt prelude.rkt reduction.rkt syntax.rkt typing-core.rkt unify.rkt) #f)
   'test-generic-arith-01.rkt
   (test-dep '(driver.rkt global-env.rkt parser.rkt posit-impl.rkt prelude.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-generic-arith-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
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
   'test-hashable-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-hashable-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-higher-rank.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt reader.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-hkt-errors.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-hkt-impl.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-hkt-kind.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-identity-generic-ops.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-implicit-inference.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt) #t)
   'test-implicit-map.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt reader.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-inductive.rkt
   (test-dep '(prelude.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-int.rkt
   (test-dep '(driver.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-integration.rkt
   (test-dep '(prelude.rkt processes.rkt qtt.rkt reduction.rkt sessions.rkt substitution.rkt syntax.rkt typing-core.rkt typing-sessions.rkt) #f)
   'test-introspection.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt reader.rkt reduction.rkt sexp-readtable.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-kind-inference-where.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-kind-inference.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-lang-01-sexp.rkt
   (test-dep '() #f)
   'test-lang-02-ws.rkt
   (test-dep '() #f)
   'test-lang-03-macros.rkt
   (test-dep '() #f)
   'test-lang-04-repl.rkt
   (test-dep '() #f)
   'test-lang-errors-01-sexp.rkt
   (test-dep '() #f)
   'test-lang-errors-02-ws.rkt
   (test-dep '() #f)
   'test-lattice.rkt
   (test-dep '() #t)
   'test-let-arrow-syntax.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt parser.rkt prelude.rkt pretty-print.rkt surface-syntax.rkt syntax.rkt typing-errors.rkt) #f)
   'test-list-extended-01-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-list-extended-01-02.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-list-extended-02-01.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-list-extended-02-02.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt) #t)
   'test-list-literals.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt pretty-print.rkt reader.rkt sexp-readtable.rkt syntax.rkt) #t)
   'test-lseq-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-lseq-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-lseq-literal.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt reader.rkt sexp-readtable.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-lseq-traits.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
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
   'test-metavar.rkt
   (test-dep '(global-env.rkt metavar-store.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt zonk.rkt) #f)
   'test-method-resolution.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-mixed-map.rkt
   (test-dep '(champ.rkt driver.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt unify.rkt) #t)
   'test-mixfix.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt reader.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-mult-inference.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt prelude.rkt syntax.rkt unify.rkt zonk.rkt) #t)
   'test-multi-body-defn.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt parser.rkt prelude.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-namespace.rkt
   (test-dep '(elaborator.rkt global-env.rkt namespace.rkt prelude.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-native-collection-ops.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt syntax.rkt) #t)
   'test-negative-literals.rkt
   (test-dep '(driver.rkt reader.rkt) #t)
   'test-new-lattice-cell.rkt
   (test-dep '(driver.rkt errors.rkt macros.rkt) #t)
   'test-nil-type.rkt
   (test-dep '(champ.rkt driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt reader.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-numeric-coercion.rkt
   (test-dep '(driver.rkt global-env.rkt posit-impl.rkt prelude.rkt syntax.rkt) #f)
   'test-numeric-join.rkt
   (test-dep '(syntax.rkt typing-core.rkt) #f)
   'test-numeric-traits-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-numeric-traits-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-parser-relational.rkt
   (test-dep '(errors.rkt parser.rkt surface-syntax.rkt) #f)
   'test-parser.rkt
   (test-dep '(errors.rkt parser.rkt source-location.rkt surface-syntax.rkt) #f)
   'test-path-expressions.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt sexp-readtable.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-perf-counters.rkt
   (test-dep '(performance-counters.rkt) #f)
   'test-phase-timing.rkt
   (test-dep '(driver.rkt global-env.rkt performance-counters.rkt) #f)
   'test-pipe-compose-e2e-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt reader.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-pipe-compose-e2e-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt reader.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-pipe-compose.rkt
   (test-dep '(macros.rkt reader.rkt) #f)
   'test-placeholder.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt source-location.rkt surface-syntax.rkt) #t)
   'test-posit-eq.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt posit-impl.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-posit-identity.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-posit-impl.rkt
   (test-dep '(posit-impl.rkt) #f)
   'test-posit16.rkt
   (test-dep '(driver.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-posit32.rkt
   (test-dep '(driver.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-posit64.rkt
   (test-dep '(driver.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-posit8.rkt
   (test-dep '(driver.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
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
   'test-pretty-print.rkt
   (test-dep '(prelude.rkt pretty-print.rkt sessions.rkt syntax.rkt) #f)
   'test-process-parse-01.rkt
   (test-dep '(errors.rkt parser.rkt surface-syntax.rkt) #f)
   'test-propagator-bsp.rkt
   (test-dep '(champ.rkt propagator.rkt) #f)
   'test-propagator-integration.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #t)
   'test-propagator-lvar.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt prelude.rkt syntax.rkt) #t)
   'test-propagator-network.rkt
   (test-dep '(champ.rkt propagator.rkt) #f)
   'test-propagator-persistence.rkt
   (test-dep '(champ.rkt propagator.rkt) #f)
   'test-propagator-types.rkt
   (test-dep '(global-env.rkt prelude.rkt pretty-print.rkt propagator.rkt qtt.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-propagator.rkt
   (test-dep '(champ.rkt propagator.rkt) #f)
   'test-properties.rkt
   (test-dep '(global-env.rkt metavar-store.rkt performance-counters.rkt prelude.rkt reduction.rkt syntax.rkt typing-core.rkt unify.rkt zonk.rkt) #f)
   'test-property-ws.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt parser.rkt pretty-print.rkt reader.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-provenance-errors.rkt
   (test-dep '(driver.rkt elab-speculation-bridge.rkt errors.rkt global-env.rkt metavar-store.rkt performance-counters.rkt prelude.rkt source-location.rkt syntax.rkt) #t)
   'test-provenance.rkt
   (test-dep '(provenance.rkt) #f)
   'test-pvec-fold.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt syntax.rkt) #t)
   'test-pvec-ops-eval.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt syntax.rkt) #t)
   'test-pvec-traits.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-pvec.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt prelude.rkt pretty-print.rkt reader.rkt reduction.rkt rrb.rkt sexp-readtable.rkt substitution.rkt syntax.rkt typing-core.rkt) #t)
   'test-qtt-pipeline.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt) #t)
   'test-qtt.rkt
   (test-dep '(prelude.rkt qtt.rkt reduction.rkt substitution.rkt syntax.rkt) #f)
   'test-quire.rkt
   (test-dep '(driver.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-quote.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt reader.rkt sexp-readtable.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-rat.rkt
   (test-dep '(driver.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-reader-relational.rkt
   (test-dep '(reader.rkt) #f)
   'test-reader.rkt
   (test-dep '(reader.rkt) #f)
   'test-reducible.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt syntax.rkt) #t)
   'test-reduction-perf-01-01.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt parser.rkt posit-impl.rkt prelude.rkt reader.rkt reduction.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-reduction-perf-01-02.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt parser.rkt prelude.rkt reader.rkt reduction.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-reduction-perf-02-01.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt parser.rkt prelude.rkt reader.rkt reduction.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-reduction-perf-02-02.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt namespace.rkt parser.rkt prelude.rkt reader.rkt reduction.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-reduction.rkt
   (test-dep '(prelude.rkt reduction.rkt substitution.rkt syntax.rkt) #f)
   'test-refined-int.rkt
   (test-dep '(driver.rkt) #t)
   'test-refined-rat.rkt
   (test-dep '(driver.rkt) #t)
   'test-refined-subtyping.rkt
   (test-dep '(driver.rkt) #t)
   'test-relational-e2e.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt reader.rkt relations.rkt trait-resolution.rkt) #f)
   'test-relational-types.rkt
   (test-dep '(elaborator.rkt errors.rkt global-env.rkt prelude.rkt pretty-print.rkt qtt.rkt reduction.rkt solver.rkt source-location.rkt substitution.rkt surface-syntax.rkt syntax.rkt typing-core.rkt) #f)
   'test-relations-runtime.rkt
   (test-dep '(provenance.rkt relations.rkt solver.rkt) #f)
   'test-schema-e2e.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt prelude.rkt syntax.rkt) #t)
   'test-schema-properties.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt prelude.rkt syntax.rkt) #t)
   'test-schema-registry.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-schema-types.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt typing-core.rkt) #t)
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
   (test-dep '(metavar-store.rkt prelude.rkt processes.rkt sessions.rkt substitution.rkt syntax.rkt typing-core.rkt typing-sessions.rkt) #f)
   'test-session-parse-01.rkt
   (test-dep '(errors.rkt parser.rkt surface-syntax.rkt) #f)
   'test-session-parse-02.rkt
   (test-dep '(errors.rkt macros.rkt parser.rkt surface-syntax.rkt) #f)
   'test-sessions.rkt
   (test-dep '(prelude.rkt sessions.rkt substitution.rkt syntax.rkt) #f)
   'test-set-ops-eval.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt multi-dispatch.rkt namespace.rkt syntax.rkt) #t)
   'test-set.rkt
   (test-dep '(champ.rkt driver.rkt global-env.rkt prelude.rkt pretty-print.rkt reader.rkt reduction.rkt sexp-readtable.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-sexp-reader-parity.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt reader.rkt reduction.rkt sexp-readtable.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-sign-galois.rkt
   (test-dep '() #t)
   'test-solver-config.rkt
   (test-dep '(solver.rkt) #f)
   'test-spec-ordering.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt typing-errors.rkt) #f)
   'test-spec.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt typing-errors.rkt) #f)
   'test-specialization.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
   'test-speculation-bridge.rkt
   (test-dep '(driver.rkt elab-speculation-bridge.rkt errors.rkt global-env.rkt metavar-store.rkt prelude.rkt syntax.rkt) #t)
   'test-sprint10.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt) #t)
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
   'test-stratified-eval.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt reader.rkt relations.rkt solver.rkt stratified-eval.rkt stratify.rkt syntax.rkt trait-resolution.rkt) #f)
   'test-stratify.rkt
   (test-dep '(stratify.rkt) #f)
   'test-string-ops.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt reader.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-substitution.rkt
   (test-dep '(prelude.rkt substitution.rkt syntax.rkt) #f)
   'test-subtyping.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt posit-impl.rkt prelude.rkt pretty-print.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-support.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt) #t)
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
   'test-tabling-integration.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-tabling-types.rkt
   (test-dep '(global-env.rkt prelude.rkt pretty-print.rkt propagator.rkt qtt.rkt reduction.rkt substitution.rkt syntax.rkt tabling.rkt typing-core.rkt) #f)
   'test-tabling.rkt
   (test-dep '(propagator.rkt tabling.rkt) #f)
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
   'test-trait-resolution.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt) #t)
   'test-transducer-01.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt reader.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-transducer-02.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt reader.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
   'test-transient.rkt
   (test-dep '(champ.rkt driver.rkt errors.rkt global-env.rkt macros.rkt namespace.rkt prelude.rkt pretty-print.rkt reduction.rkt rrb.rkt substitution.rkt syntax.rkt typing-core.rkt) #t)
   'test-tycon.rkt
   (test-dep '(global-env.rkt metavar-store.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt trait-resolution.rkt typing-core.rkt unify.rkt zonk.rkt) #f)
   'test-type-lattice.rkt
   (test-dep '(champ.rkt prelude.rkt propagator.rkt syntax.rkt type-lattice.rkt) #f)
   'test-type-syntax-refactor.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt parser.rkt prelude.rkt sexp-readtable.rkt surface-syntax.rkt syntax.rkt typing-core.rkt) #f)
   'test-typing-sessions.rkt
   (test-dep '(prelude.rkt processes.rkt reduction.rkt sessions.rkt substitution.rkt syntax.rkt typing-sessions.rkt) #f)
   'test-typing.rkt
   (test-dep '(prelude.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #f)
   'test-unify.rkt
   (test-dep '(global-env.rkt metavar-store.rkt prelude.rkt reduction.rkt syntax.rkt unify.rkt) #f)
   'test-unify-cell-driven.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt metavar-store.rkt prelude.rkt syntax.rkt unify.rkt) #t)
   'test-unify-structural.rkt
   (test-dep '(prelude.rkt syntax.rkt unify.rkt) #f)
   'test-union-find-integration.rkt
   (test-dep '(driver.rkt errors.rkt global-env.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt) #t)
   'test-union-find-types.rkt
   (test-dep '(global-env.rkt prelude.rkt pretty-print.rkt qtt.rkt reduction.rkt substitution.rkt syntax.rkt typing-core.rkt union-find.rkt) #f)
   'test-union-find.rkt
   (test-dep '(union-find.rkt) #f)
   'test-union-types.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt parser.rkt prelude.rkt pretty-print.rkt reduction.rkt substitution.rkt surface-syntax.rkt syntax.rkt typing-core.rkt unify.rkt zonk.rkt) #f)
   'test-unit-type.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt) #t)
   'test-universe-level-inference.rkt
   (test-dep '(driver.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt prelude.rkt syntax.rkt unify.rkt zonk.rkt) #t)
   'test-varargs.rkt
   (test-dep '(driver.rkt elaborator.rkt errors.rkt global-env.rkt macros.rkt metavar-store.rkt namespace.rkt parser.rkt prelude.rkt pretty-print.rkt reader.rkt reduction.rkt source-location.rkt surface-syntax.rkt syntax.rkt trait-resolution.rkt typing-core.rkt) #t)
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
  (hasheq
   'hello.rkt           '(test-lang-01-sexp.rkt test-lang-04-repl.rkt)
   'hello-ws.rkt        '(test-lang-02-ws.rkt)
   'identity.rkt        '(test-lang-01-sexp.rkt)
   'identity-ws.rkt     '(test-lang-02-ws.rkt)
   'defn.rkt            '(test-lang-03-macros.rkt test-lang-04-repl.rkt)
   'defn-ws.rkt         '(test-lang-03-macros.rkt)
   'pairs.rkt           '(test-lang-01-sexp.rkt)
   'pairs-ws.rkt        '(test-lang-02-ws.rkt)
   'vectors.rkt         '(test-lang-01-sexp.rkt)
   'vectors-ws.rkt      '(test-lang-02-ws.rkt)
   'spec-ws.rkt         '(test-lang-03-macros.rkt)
   'posit8.rkt          '(test-lang-01-sexp.rkt)
   'posit8-ws.rkt       '(test-lang-02-ws.rkt)
   'macros.rkt          '(test-lang-03-macros.rkt)
   'macros-ws.rkt       '(test-lang-03-macros.rkt)
   'let-arrow-ws.rkt    '(test-lang-03-macros.rkt)
   'type-error.rkt      '(test-lang-errors-01-sexp.rkt)
   'type-error-ws.rkt   '(test-lang-errors-02-ws.rkt)
   'unbound-var.rkt     '(test-lang-errors-01-sexp.rkt)
   'unbound-var-ws.rkt  '(test-lang-errors-02-ws.rkt)))

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
   'prologos::core::.#map-ops     '()
   'prologos::core::abstract-domains '(prologos::core::eq prologos::core::lattice prologos::core::ord prologos::data::bool prologos::data::ordering prologos::data::parity prologos::data::refined-int prologos::data::refined-rat prologos::data::sign)
   'prologos::core::algebra       '(prologos::core::arithmetic prologos::core::conversions prologos::core::eq prologos::core::ord prologos::data::list)
   'prologos::core::arithmetic    '(prologos::data::nat prologos::data::string)
   'prologos::core::capabilities  '()
   'prologos::core::collection-traits '(prologos::data::lseq prologos::data::option)
   'prologos::core::collections   '()
   'prologos::core::conversions   '(prologos::data::option)
   'prologos::core::eq            '(prologos::data::bool prologos::data::char prologos::data::nat prologos::data::option prologos::data::ordering prologos::data::string)
   'prologos::core::eq-derived    '(prologos::core::eq prologos::data::bool prologos::data::list)
   'prologos::core::generic-ops   '(prologos::core::collection-traits prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::option)
   'prologos::core::hashable      '(prologos::data::list prologos::data::nat prologos::data::option prologos::data::ordering)
   'prologos::core::lattice       '(prologos::core::eq prologos::data::bool)
   'prologos::core::list          '(prologos::core::collection-traits prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::nat prologos::data::option)
   'prologos::core::lseq          '(prologos::core::collection-traits prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::option)
   'prologos::core::map           '(prologos::core::collection-traits prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::map-entry prologos::data::option)
   'prologos::core::ord           '(prologos::data::bool prologos::data::char prologos::data::nat prologos::data::option prologos::data::ordering prologos::data::string)
   'prologos::core::propagator    '(prologos::core::lattice)
   'prologos::core::pvec          '(prologos::core::collection-traits prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::nat prologos::data::option)
   'prologos::core::set           '(prologos::core::collection-traits prologos::data::list prologos::data::lseq prologos::data::lseq-ops)
   'prologos::core::string-ops    '(prologos::data::char prologos::data::list prologos::data::option prologos::data::pair prologos::data::string)
   'prologos::data::bool          '()
   'prologos::data::char          '()
   'prologos::data::datum         '()
   'prologos::data::either        '(prologos::data::option)
   'prologos::data::eq            '()
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
   'prologos::data::refined-int   '(prologos::data::option)
   'prologos::data::refined-rat   '(prologos::data::option)
   'prologos::data::result        '(prologos::data::option)
   'prologos::data::set           '(prologos::data::list)
   'prologos::data::sign          '()
   'prologos::data::string        '()
   'prologos::data::transducer    '(prologos::data::lseq)))

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
   'test-char-string.rkt          '(prologos::data::ordering)
   'test-coherence.rkt            '(prologos::core::eq)
   'test-collection-conversions.rkt '(prologos::core::collections prologos::data::list prologos::data::lseq prologos::data::lseq-ops)
   'test-collection-fns-01.rkt    '(prologos::core::collections prologos::data::nat)
   'test-collection-fns-02.rkt    '(prologos::core::collections)
   'test-collection-traits-01.rkt '(prologos::core::collection-traits prologos::core::list prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::option)
   'test-collection-traits-02.rkt '(prologos::core::collection-traits prologos::core::list prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::option)
   'test-constraint-postponement.rkt '(prologos::core prologos::data::bool prologos::data::list prologos::data::nat)
   'test-core-prelude.rkt         '(prologos::core)
   'test-cross-family-conversions-02.rkt '(prologos::core::conversions)
   'test-cross-family-conversions-03.rkt '(prologos::core::conversions prologos::data::option)
   'test-eq-ord-extended-01.rkt   '(prologos::core::eq prologos::core::eq-derived prologos::core::ord prologos::data::list prologos::data::option prologos::data::ordering)
   'test-eq-ord-extended-02.rkt   '(prologos::core::eq prologos::core::eq-derived prologos::core::ord prologos::data::list prologos::data::option prologos::data::ordering)
   'test-error-messages.rkt       '(prologos::core prologos::data::nat)
   'test-galois-connection.rkt    '(prologos::core::lattice)
   'test-generic-arith-02.rkt     '(prologos::core::algebra prologos::core::arithmetic)
   'test-hashable-01.rkt          '(prologos::core::hashable prologos::data::list prologos::data::option prologos::data::ordering)
   'test-hashable-02.rkt          '(prologos::core::hashable prologos::data::list prologos::data::option prologos::data::ordering)
   'test-higher-rank.rkt          '(prologos::data::list)
   'test-hkt-impl.rkt             '(prologos::core::collection-traits prologos::core::list prologos::core::lseq prologos::core::pvec prologos::core::set prologos::data::list)
   'test-hkt-kind.rkt             '(prologos::core::eq prologos::core::ord prologos::data::list prologos::data::option)
   'test-identity-generic-ops.rkt '(prologos::core::algebra prologos::core::arithmetic prologos::data::list)
   'test-implicit-inference.rkt   '(prologos::core prologos::data::list prologos::data::nat prologos::data::option)
   'test-kind-inference-where.rkt '(prologos::core::collection-traits prologos::core::eq prologos::data::lseq)
   'test-kind-inference.rkt       '(prologos::core::collection-traits prologos::data::lseq)
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
   'test-new-lattice-cell.rkt     '(prologos::core::lattice prologos::core::propagator)
   'test-numeric-traits-01.rkt    '(prologos::core::arithmetic)
   'test-numeric-traits-02.rkt    '(prologos::core::algebra prologos::core::arithmetic prologos::core::conversions prologos::core::eq prologos::core::ord prologos::data::nat)
   'test-pipe-compose-e2e-01.rkt  '(prologos::data::list prologos::data::nat prologos::data::transducer)
   'test-pipe-compose-e2e-02.rkt  '(prologos::data::list prologos::data::nat prologos::data::transducer)
   'test-posit-identity.rkt       '(prologos::core::algebra prologos::core::arithmetic prologos::data::list)
   'test-prelude-system-01.rkt    '(prologos::core)
   'test-prelude-system-02.rkt    '(prologos::core prologos::core::test-dep prologos::data prologos::data::nat prologos::data::test-dep prologos::data::test-dep2)
   'test-pvec-traits.rkt          '(prologos::core::pvec prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::nat prologos::data::option)
   'test-qtt-pipeline.rkt         '(prologos::data::bool prologos::data::nat)
   'test-quote.rkt                '(prologos::data::datum)
   'test-reducible.rkt            '(prologos::core::collection-traits prologos::core::collections prologos::core::list prologos::core::lseq prologos::core::pvec prologos::core::set prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::nat prologos::data::option)
   'test-refined-int.rkt          '(prologos::core::abstract-domains prologos::core::eq prologos::core::ord prologos::data::option prologos::data::ordering prologos::data::refined-int)
   'test-refined-rat.rkt          '(prologos::core::abstract-domains prologos::core::eq prologos::core::ord prologos::data::option prologos::data::ordering prologos::data::refined-rat)
   'test-refined-subtyping.rkt    '(prologos::core::abstract-domains prologos::core::eq prologos::data::option prologos::data::refined-int prologos::data::refined-rat)
   'test-sexp-reader-parity.rkt   '(prologos::data::list)
   'test-sign-galois.rkt          '(prologos::core::abstract-domains prologos::core::lattice prologos::data::sign)
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
   'test-string-ops.rkt           '(prologos::core::string-ops prologos::data::option prologos::data::option::none prologos::data::option::some)
   'test-subtyping.rkt            '(prologos::data::nat)
   'test-surface-defmacro-01.rkt  '(prologos::core prologos::data::nat)
   'test-surface-defmacro-02.rkt  '(prologos::data::nat)
   'test-trait-impl-02.rkt        '(prologos::data::either prologos::data::either::right prologos::data::nat prologos::data::never prologos::data::option prologos::data::pair prologos::data::result)
   'test-trait-impl-03.rkt        '(prologos::core::eq prologos::core::ord prologos::data::ordering)
   'test-trait-impl-04-01.rkt     '(prologos::core::collection-traits prologos::core::list prologos::data::list prologos::data::list::nil prologos::data::nat prologos::data::option prologos::data::option::none prologos::data::option::some)
   'test-trait-impl-04-02.rkt     '(prologos::core::generic-ops prologos::core::list prologos::data::list prologos::data::nat prologos::data::option prologos::data::option::none prologos::data::option::some)
   'test-trait-resolution.rkt     '(prologos::core::eq prologos::data::bool prologos::data::list)
   'test-transducer-01.rkt        '(prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::transducer)
   'test-transducer-02.rkt        '(prologos::data::list prologos::data::lseq prologos::data::lseq-ops prologos::data::nat prologos::data::transducer)
   'test-unit-type.rkt            '(prologos::data::list)
   'test-universe-level-inference.rkt '(prologos::core prologos::data::bool prologos::data::nat)
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
