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
   'prelude.rkt         '()
   'source-location.rkt '()
   'syntax.rkt          '(prelude.rkt)
   'surface-syntax.rkt  '(source-location.rkt)
   'errors.rkt          '(source-location.rkt)
   'sexp-readtable.rkt  '()
   'reader.rkt          '()
   'namespace.rkt       '()
   'global-env.rkt      '()
   'multi-dispatch.rkt  '()
   'posit-impl.rkt      '()
   'champ.rkt           '()
   'propagator.rkt      '(champ.rkt)
   'rrb.rkt             '()
   'foreign.rkt         '(syntax.rkt)
   'sessions.rkt        '(prelude.rkt syntax.rkt substitution.rkt)
   'substitution.rkt    '(prelude.rkt syntax.rkt)
   'macros.rkt          '(surface-syntax.rkt source-location.rkt errors.rkt
                          namespace.rkt global-env.rkt)
   'parser.rkt          '(source-location.rkt surface-syntax.rkt errors.rkt
                          sexp-readtable.rkt macros.rkt)
   'metavar-store.rkt   '(syntax.rkt prelude.rkt sessions.rkt source-location.rkt)
   'zonk.rkt            '(syntax.rkt metavar-store.rkt substitution.rkt)
   'reduction.rkt       '(prelude.rkt syntax.rkt substitution.rkt global-env.rkt
                          posit-impl.rkt macros.rkt metavar-store.rkt
                          foreign.rkt champ.rkt rrb.rkt)
   'unify.rkt           '(syntax.rkt prelude.rkt reduction.rkt metavar-store.rkt
                          substitution.rkt zonk.rkt source-location.rkt)
   'typing-core.rkt     '(prelude.rkt syntax.rkt substitution.rkt reduction.rkt
                          unify.rkt global-env.rkt macros.rkt namespace.rkt
                          metavar-store.rkt)
   'qtt.rkt             '(prelude.rkt syntax.rkt substitution.rkt reduction.rkt
                          unify.rkt typing-core.rkt metavar-store.rkt global-env.rkt)
   'pretty-print.rkt    '(prelude.rkt syntax.rkt sessions.rkt metavar-store.rkt
                          champ.rkt)
   'elaborator.rkt      '(prelude.rkt syntax.rkt source-location.rkt
                          surface-syntax.rkt errors.rkt global-env.rkt
                          namespace.rkt metavar-store.rkt pretty-print.rkt
                          multi-dispatch.rkt foreign.rkt posit-impl.rkt
                          champ.rkt macros.rkt substitution.rkt)
   'typing-errors.rkt   '(prelude.rkt syntax.rkt reduction.rkt typing-core.rkt
                          qtt.rkt source-location.rkt errors.rkt
                          pretty-print.rkt global-env.rkt)
   'trait-resolution.rkt '(syntax.rkt prelude.rkt metavar-store.rkt macros.rkt
                           zonk.rkt errors.rkt source-location.rkt)
   'processes.rkt        '(sessions.rkt)
   'typing-sessions.rkt  '(prelude.rkt syntax.rkt substitution.rkt reduction.rkt
                           typing-core.rkt sessions.rkt processes.rkt
                           metavar-store.rkt)
   'driver.rkt           '(prelude.rkt syntax.rkt reduction.rkt typing-core.rkt
                           source-location.rkt surface-syntax.rkt errors.rkt
                           parser.rkt elaborator.rkt pretty-print.rkt
                           typing-errors.rkt global-env.rkt macros.rkt
                           sexp-readtable.rkt reader.rkt namespace.rkt
                           metavar-store.rkt zonk.rkt qtt.rkt
                           multi-dispatch.rkt foreign.rkt trait-resolution.rkt)
   'lang-error.rkt       '(source-location.rkt errors.rkt)
   'expander.rkt         '(source-location.rkt surface-syntax.rkt errors.rkt
                           parser.rkt elaborator.rkt prelude.rkt syntax.rkt
                           typing-core.rkt typing-errors.rkt reduction.rkt
                           pretty-print.rkt global-env.rkt lang-error.rkt
                           macros.rkt metavar-store.rkt zonk.rkt
                           multi-dispatch.rkt trait-resolution.rkt)
   'repl-support.rkt     '(parser.rkt driver.rkt errors.rkt global-env.rkt macros.rkt)
   'main.rkt             '(expander.rkt repl-support.rkt)
   'sexp.rkt             '(main.rkt sexp-readtable.rkt)
   'repl.rkt             '(source-location.rkt errors.rkt parser.rkt driver.rkt
                           pretty-print.rkt global-env.rkt reader.rkt macros.rkt
                           sexp-readtable.rkt)
   'inductive.rkt        '(syntax.rkt typing-core.rkt)
   'type-lattice.rkt     '(syntax.rkt reduction.rkt zonk.rkt substitution.rkt)
   'elaborator-network.rkt '(propagator.rkt type-lattice.rkt champ.rkt syntax.rkt)
   'elab-speculation.rkt '(elaborator-network.rkt atms.rkt type-lattice.rkt propagator.rkt)
   'elab-speculation-bridge.rkt '(metavar-store.rkt)))

;; ============================================================
;; Layer 2: Test → source module dependencies
;; ============================================================

(struct test-dep (source-modules uses-driver?) #:transparent)

(define test-deps
  (hasheq
   ;; === Unit tests (driver=no) ===
   'test-prelude.rkt
   (test-dep '(prelude.rkt) #f)
   'test-syntax.rkt
   (test-dep '(prelude.rkt syntax.rkt) #f)
   'test-errors.rkt
   (test-dep '(source-location.rkt errors.rkt) #f)
   'test-reader.rkt
   (test-dep '(reader.rkt) #f)
   'test-substitution.rkt
   (test-dep '(prelude.rkt syntax.rkt substitution.rkt) #f)
   'test-reduction.rkt
   (test-dep '(prelude.rkt syntax.rkt substitution.rkt reduction.rkt) #f)
   'test-sessions.rkt
   (test-dep '(prelude.rkt syntax.rkt substitution.rkt sessions.rkt) #f)
   'test-typing.rkt
   (test-dep '(prelude.rkt syntax.rkt substitution.rkt reduction.rkt typing-core.rkt) #f)
   'test-qtt.rkt
   (test-dep '(prelude.rkt syntax.rkt substitution.rkt reduction.rkt qtt.rkt) #f)
   'test-inductive.rkt
   (test-dep '(prelude.rkt syntax.rkt substitution.rkt reduction.rkt typing-core.rkt inductive.rkt) #f)
   'test-eliminator-typing.rkt
   (test-dep '(prelude.rkt syntax.rkt substitution.rkt reduction.rkt typing-core.rkt qtt.rkt) #f)
   'test-integration.rkt
   (test-dep '(prelude.rkt syntax.rkt substitution.rkt reduction.rkt typing-core.rkt
               qtt.rkt sessions.rkt processes.rkt typing-sessions.rkt) #f)
   'test-defmacro.rkt
   (test-dep '(macros.rkt) #f)
   'test-posit-impl.rkt
   (test-dep '(posit-impl.rkt) #f)
   'test-pretty-print.rkt
   (test-dep '(prelude.rkt syntax.rkt sessions.rkt pretty-print.rkt) #f)
   'test-namespace.rkt
   (test-dep '(namespace.rkt global-env.rkt syntax.rkt prelude.rkt elaborator.rkt
               surface-syntax.rkt source-location.rkt) #f)
   'test-parser.rkt
   (test-dep '(surface-syntax.rkt parser.rkt errors.rkt) #f)
   'test-elaborator.rkt
   (test-dep '(prelude.rkt syntax.rkt surface-syntax.rkt parser.rkt elaborator.rkt
               errors.rkt global-env.rkt metavar-store.rkt) #f)
   'test-unify.rkt
   (test-dep '(prelude.rkt syntax.rkt metavar-store.rkt reduction.rkt unify.rkt
               global-env.rkt) #f)
   'test-metavar.rkt
   (test-dep '(prelude.rkt syntax.rkt metavar-store.rkt substitution.rkt reduction.rkt
               pretty-print.rkt zonk.rkt global-env.rkt) #f)
   'test-sess-inference.rkt
   (test-dep '(prelude.rkt syntax.rkt substitution.rkt sessions.rkt processes.rkt
               metavar-store.rkt typing-sessions.rkt) #f)
   'test-typing-sessions.rkt
   (test-dep '(prelude.rkt syntax.rkt substitution.rkt reduction.rkt sessions.rkt
               processes.rkt typing-sessions.rkt) #f)

   ;; === Hybrid tests (require driver but also specific modules) ===
   'test-posit8.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt) #f)
   'test-posit16.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt) #f)
   'test-posit32.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt) #f)
   'test-posit64.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt) #f)
   'test-quire.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt) #f)
   'test-int.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt) #f)
   'test-rat.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt) #f)
   'test-set.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt champ.rkt reader.rkt
               sexp-readtable.rkt) #f)
   'test-pvec.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt rrb.rkt reader.rkt
               sexp-readtable.rkt) #f)
   'test-pvec-traits.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt rrb.rkt namespace.rkt
               macros.rkt qtt.rkt)
             '(prologos::core::pvec))
   'test-map-set-traits-01.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt namespace.rkt
               macros.rkt qtt.rkt champ.rkt)
             '(prologos::core::set prologos::core::map))
   'test-map-set-traits-02.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt namespace.rkt
               macros.rkt qtt.rkt champ.rkt)
             '(prologos::core::set prologos::core::map))
   'test-pvec-ops-eval.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt rrb.rkt namespace.rkt
               macros.rkt qtt.rkt)
             '(prologos::core::pvec))
   'test-pvec-fold.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt rrb.rkt namespace.rkt
               macros.rkt qtt.rkt parser.rkt elaborator.rkt zonk.rkt)
             '())
   'test-native-collection-ops.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt rrb.rkt champ.rkt namespace.rkt
               macros.rkt qtt.rkt parser.rkt elaborator.rkt zonk.rkt)
             '())
   'test-set-ops-eval.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt namespace.rkt
               macros.rkt qtt.rkt champ.rkt)
             '(prologos::core::set))
   'test-map-ops-eval.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt namespace.rkt
               macros.rkt qtt.rkt champ.rkt)
             '(prologos::core::map))
   'test-map-entry.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt namespace.rkt
               macros.rkt qtt.rkt)
             '(prologos::data::map-entry))
   'test-map-bridge.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt namespace.rkt
               macros.rkt qtt.rkt champ.rkt)
             '(prologos::data::map-entry prologos::core::map))
   'test-lseq-traits.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt namespace.rkt
               macros.rkt qtt.rkt)
             '(prologos::core::lseq))
   'test-identity-generic-ops.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt namespace.rkt
               macros.rkt qtt.rkt)
             '(prologos::core::algebra))
   'test-posit-identity.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt namespace.rkt
               macros.rkt qtt.rkt)
             '(prologos::core::algebra
               prologos::core::arithmetic prologos::core::arithmetic))
   'test-posit-eq.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt namespace.rkt
               macros.rkt qtt.rkt posit-impl.rkt)
             '(prologos::core::eq))
   'test-collection-conversions.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt namespace.rkt
               macros.rkt qtt.rkt)
             '(prologos::core::collections))
   'test-prelude-collections.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt namespace.rkt
               macros.rkt qtt.rkt)
             #f)
   'test-map.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt champ.rkt) #f)
   'test-mixed-map.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               unify.rkt pretty-print.rkt driver.rkt global-env.rkt metavar-store.rkt
               namespace.rkt macros.rkt champ.rkt) #f)
   'test-transient.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt rrb.rkt champ.rkt
               namespace.rkt macros.rkt errors.rkt) #f)
   'test-approx-literal.rkt
   (test-dep '(syntax.rkt prelude.rkt surface-syntax.rkt reader.rkt parser.rkt
               driver.rkt global-env.rkt posit-impl.rkt) #f)
   'test-decimal-literal.rkt
   (test-dep '(syntax.rkt prelude.rkt surface-syntax.rkt reader.rkt parser.rkt
               driver.rkt global-env.rkt posit-impl.rkt) #f)
   'test-generic-arith-01.rkt
   (test-dep '(syntax.rkt prelude.rkt surface-syntax.rkt parser.rkt elaborator.rkt
               typing-core.rkt qtt.rkt reduction.rkt substitution.rkt zonk.rkt
               pretty-print.rkt driver.rkt global-env.rkt posit-impl.rkt) #f)
   'test-generic-from.rkt
   (test-dep '(syntax.rkt prelude.rkt surface-syntax.rkt parser.rkt elaborator.rkt
               typing-core.rkt qtt.rkt reduction.rkt substitution.rkt zonk.rkt
               pretty-print.rkt driver.rkt global-env.rkt posit-impl.rkt) #f)
   'test-numeric-join.rkt
   (test-dep '(syntax.rkt typing-core.rkt) #f)
   'test-numeric-coercion.rkt
   (test-dep '(syntax.rkt prelude.rkt surface-syntax.rkt parser.rkt elaborator.rkt
               typing-core.rkt qtt.rkt reduction.rkt substitution.rkt zonk.rkt
               pretty-print.rkt driver.rkt global-env.rkt posit-impl.rkt) #f)
   'test-coercion-warnings.rkt
   (test-dep '(syntax.rkt prelude.rkt surface-syntax.rkt parser.rkt elaborator.rkt
               typing-core.rkt qtt.rkt reduction.rkt substitution.rkt zonk.rkt
               pretty-print.rkt driver.rkt global-env.rkt posit-impl.rkt warnings.rkt) #f)

   ;; === Driver/integration tests (driver=yes) ===
   'test-stdlib-01-data-01.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-stdlib-01-data-02.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-stdlib-01-data-03.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-stdlib-01-data-04.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-stdlib-02-traits-01.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-stdlib-02-traits-02.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-stdlib-02-traits-03.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-stdlib-02-traits-04.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-stdlib-02-traits-05.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-stdlib-02-traits-06.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-stdlib-02-traits-07.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-stdlib-03-list-01.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-stdlib-03-list-02.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-stdlib-03-list-03.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-stdlib-03-list-04-01.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-stdlib-03-list-04-02.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-stdlib-03-list-05.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-list-extended-01-01.rkt
   (test-dep '(errors.rkt driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-list-extended-01-02.rkt
   (test-dep '(errors.rkt driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-list-extended-02-01.rkt
   (test-dep '(errors.rkt driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-list-extended-02-02.rkt
   (test-dep '(errors.rkt driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-core-prelude.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-prelude-system-01.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt errors.rkt elaborator.rkt) #t)
   'test-prelude-system-02.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt errors.rkt elaborator.rkt) #t)
   'test-auto-implicits.rkt
   (test-dep '(errors.rkt global-env.rkt driver.rkt namespace.rkt macros.rkt
               metavar-store.rkt) #t)
   'test-kind-inference-where.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt) #t)
   'test-sprint10.rkt
   (test-dep '(errors.rkt global-env.rkt driver.rkt namespace.rkt macros.rkt
               metavar-store.rkt) #t)
   'test-surface-defmacro-01.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt metavar-store.rkt) #t)
   'test-surface-defmacro-02.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt metavar-store.rkt) #t)
   'test-match-builtins.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt metavar-store.rkt) #t)
   'test-unit-type.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt metavar-store.rkt) #t)
   'test-qtt-pipeline.rkt
   (test-dep '(errors.rkt driver.rkt global-env.rkt namespace.rkt macros.rkt
               metavar-store.rkt) #t)
   'test-implicit-inference.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt metavar-store.rkt) #t)
   'test-constraint-postponement.rkt
   (test-dep '(prelude.rkt syntax.rkt metavar-store.rkt unify.rkt global-env.rkt
               driver.rkt namespace.rkt macros.rkt zonk.rkt) #t)
   'test-mult-inference.rkt
   (test-dep '(prelude.rkt syntax.rkt metavar-store.rkt unify.rkt global-env.rkt
               driver.rkt namespace.rkt macros.rkt zonk.rkt) #t)
   'test-universe-level-inference.rkt
   (test-dep '(prelude.rkt syntax.rkt metavar-store.rkt unify.rkt global-env.rkt
               driver.rkt namespace.rkt macros.rkt zonk.rkt) #t)
   'test-error-messages.rkt
   (test-dep '(prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt errors.rkt
               metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt global-env.rkt
               driver.rkt macros.rkt namespace.rkt unify.rkt) #t)
   'test-arity-checking.rkt
   (test-dep '(prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt errors.rkt
               metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt global-env.rkt
               driver.rkt macros.rkt namespace.rkt) #t)
   'test-let-arrow-syntax.rkt
   (test-dep '(prelude.rkt syntax.rkt surface-syntax.rkt parser.rkt elaborator.rkt
               pretty-print.rkt errors.rkt typing-errors.rkt global-env.rkt
               driver.rkt macros.rkt) #t)
   'test-spec.rkt
   (test-dep '(prelude.rkt syntax.rkt surface-syntax.rkt parser.rkt elaborator.rkt
               pretty-print.rkt errors.rkt typing-errors.rkt global-env.rkt
               driver.rkt macros.rkt source-location.rkt) #t)
   'test-spec-ordering.rkt
   (test-dep '(prelude.rkt syntax.rkt surface-syntax.rkt parser.rkt elaborator.rkt
               pretty-print.rkt errors.rkt typing-errors.rkt global-env.rkt
               driver.rkt macros.rkt source-location.rkt) #t)
   'test-free-ordering.rkt
   (test-dep '(global-env.rkt driver.rkt macros.rkt) #t)
   'test-extended-spec.rkt
   (test-dep '(prelude.rkt syntax.rkt surface-syntax.rkt parser.rkt elaborator.rkt
               pretty-print.rkt errors.rkt global-env.rkt
               driver.rkt macros.rkt reader.rkt source-location.rkt) #t)
   'test-surface-integration.rkt
   (test-dep '(prelude.rkt syntax.rkt reduction.rkt typing-core.rkt source-location.rkt
               surface-syntax.rkt parser.rkt elaborator.rkt pretty-print.rkt errors.rkt
               typing-errors.rkt global-env.rkt driver.rkt macros.rkt) #t)
   'test-type-syntax-refactor.rkt
   (test-dep '(prelude.rkt syntax.rkt surface-syntax.rkt parser.rkt elaborator.rkt errors.rkt
               driver.rkt global-env.rkt metavar-store.rkt macros.rkt sexp-readtable.rkt
               typing-core.rkt) #t)
   'test-union-types.rkt
   (test-dep '(prelude.rkt syntax.rkt substitution.rkt reduction.rkt zonk.rkt unify.rkt
               pretty-print.rkt metavar-store.rkt global-env.rkt surface-syntax.rkt
               parser.rkt elaborator.rkt errors.rkt driver.rkt macros.rkt
               typing-core.rkt) #t)
   'test-placeholder.rkt
   (test-dep '(source-location.rkt surface-syntax.rkt errors.rkt metavar-store.rkt
               global-env.rkt driver.rkt macros.rkt multi-dispatch.rkt) #t)
   'test-multi-body-defn.rkt
   (test-dep '(prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt errors.rkt
               metavar-store.rkt parser.rkt elaborator.rkt global-env.rkt
               driver.rkt macros.rkt multi-dispatch.rkt) #t)
   'test-list-literals.rkt
   (test-dep '(reader.rkt macros.rkt sexp-readtable.rkt pretty-print.rkt syntax.rkt
               errors.rkt driver.rkt global-env.rkt namespace.rkt) #t)
   'test-trait-impl-01.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt) #t)
   'test-trait-impl-02.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt) #t)
   'test-trait-impl-03.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt) #t)
   'test-trait-impl-04-01.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt) #t)
   'test-trait-impl-04-02.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt) #t)
   'test-trait-resolution.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt trait-resolution.rkt) #t)
   'test-method-resolution.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt trait-resolution.rkt) #t)
   'test-bundles.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt trait-resolution.rkt) #t)
   'test-config-audit.rkt
   (test-dep '(macros.rkt typing-core.rkt warnings.rkt prelude.rkt syntax.rkt
               source-location.rkt surface-syntax.rkt parser.rkt elaborator.rkt
               pretty-print.rkt errors.rkt global-env.rkt driver.rkt reader.rkt
               namespace.rkt trait-resolution.rkt) #t)
   'test-prelude-numerics.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt trait-resolution.rkt) #t)
   'test-generic-arith-02.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt) #t)
   'test-where-parsing.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt) #t)
   'test-hkt-kind.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt) #t)
   'test-kind-inference.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt) #t)
   'test-hkt-impl.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt) #t)
   'test-coherence.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt trait-resolution.rkt) #t)
   'test-bare-methods.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt) #t)
   'test-tycon.rkt
   (test-dep '(syntax.rkt prelude.rkt metavar-store.rkt substitution.rkt zonk.rkt
               reduction.rkt typing-core.rkt pretty-print.rkt unify.rkt
               trait-resolution.rkt global-env.rkt) #f)
   'test-numeric-traits-01.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt trait-resolution.rkt) #t)
   'test-numeric-traits-02.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt trait-resolution.rkt) #t)
   'test-cross-family-conversions-01.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt posit-impl.rkt) #t)
   'test-cross-family-conversions-02.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt posit-impl.rkt) #t)
   'test-cross-family-conversions-03.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt posit-impl.rkt) #t)
   'test-subtyping.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt posit-impl.rkt) #t)
   'test-collection-traits-01.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt) #t)
   'test-collection-traits-02.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt) #t)
   'test-reducible.rkt
   (test-dep '(macros.rkt syntax.rkt errors.rkt metavar-store.rkt
               global-env.rkt driver.rkt namespace.rkt) #t)
   'test-generic-ops-01-01.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt) #t)
   'test-generic-ops-01-02.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt) #t)
   'test-generic-ops-02-01.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt) #t)
   'test-generic-ops-02-02.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt) #t)
   'test-hkt-errors.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt trait-resolution.rkt) #t)
   'test-specialization.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt) #t)
   'test-constraint-inference.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt) #t)
   'test-eq-ord-extended-01.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt) #t)
   'test-eq-ord-extended-02.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt) #t)
   'test-hashable-01.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt) #t)
   'test-hashable-02.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt) #t)
   'test-lseq-01.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt) #t)
   'test-lseq-02.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt) #t)
   'test-lseq-literal.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt reader.rkt
               sexp-readtable.rkt) #t)
   'test-foreign.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt foreign.rkt) #t)
   'test-foreign-block.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt foreign.rkt) #t)
   'test-pipe-compose.rkt
   (test-dep '(macros.rkt reader.rkt) #f)  ; Fast unit/preparse tests only (split from E2E)
   'test-pipe-compose-e2e-01.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt reader.rkt) #t)
   'test-pipe-compose-e2e-02.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt reader.rkt) #t)
   'test-dot-access.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt reader.rkt) #t)
   'test-nil-type.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt reader.rkt champ.rkt unify.rkt qtt.rkt zonk.rkt
               substitution.rkt) #t)
   'test-mixfix.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt reader.rkt) #t)
   'test-implicit-map.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt reader.rkt) #t)
   'test-char-string.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt reader.rkt zonk.rkt substitution.rkt qtt.rkt
               unify.rkt foreign.rkt) #t)
   'test-string-ops.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt reader.rkt foreign.rkt) #t)
   'test-transducer-01.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt) #t)
   'test-transducer-02.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt) #t)
   'test-higher-rank.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt reader.rkt) #t)
   'test-varargs.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt reader.rkt) #t)
   'test-sexp-reader-parity.rkt
   (test-dep '(sexp-readtable.rkt reader.rkt macros.rkt prelude.rkt syntax.rkt
               source-location.rkt surface-syntax.rkt errors.rkt metavar-store.rkt
               parser.rkt elaborator.rkt pretty-print.rkt global-env.rkt driver.rkt
               reduction.rkt namespace.rkt trait-resolution.rkt) #t)
   'test-introspection.rkt
   (test-dep '(sexp-readtable.rkt reader.rkt macros.rkt prelude.rkt syntax.rkt
               source-location.rkt surface-syntax.rkt errors.rkt metavar-store.rkt
               parser.rkt elaborator.rkt pretty-print.rkt global-env.rkt driver.rkt
               reduction.rkt namespace.rkt trait-resolution.rkt) #t)
   'test-quote.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt surface-syntax.rkt source-location.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt sexp-readtable.rkt reader.rkt namespace.rkt
               trait-resolution.rkt) #t)

   ;; === #lang tests ===
   'test-lang-01-sexp.rkt
   (test-dep '(main.rkt sexp.rkt expander.rkt) #t)
   'test-lang-02-ws.rkt
   (test-dep '(main.rkt sexp.rkt expander.rkt) #t)
   'test-lang-03-macros.rkt
   (test-dep '(main.rkt sexp.rkt expander.rkt) #t)
   'test-lang-04-repl.rkt
   (test-dep '(main.rkt sexp.rkt expander.rkt) #t)
   'test-lang-errors-01-sexp.rkt
   (test-dep '(main.rkt sexp.rkt expander.rkt) #t)
   'test-lang-errors-02-ws.rkt
   (test-dep '(main.rkt sexp.rkt expander.rkt) #t)
   'test-reduction-perf-01-01.rkt
   (test-dep '(syntax.rkt prelude.rkt surface-syntax.rkt reader.rkt parser.rkt
               driver.rkt global-env.rkt reduction.rkt namespace.rkt macros.rkt
               posit-impl.rkt) #t)
   'test-reduction-perf-01-02.rkt
   (test-dep '(syntax.rkt prelude.rkt surface-syntax.rkt reader.rkt parser.rkt
               driver.rkt global-env.rkt reduction.rkt namespace.rkt macros.rkt) #t)
   'test-reduction-perf-02-01.rkt
   (test-dep '(syntax.rkt prelude.rkt surface-syntax.rkt reader.rkt parser.rkt
               driver.rkt global-env.rkt reduction.rkt namespace.rkt macros.rkt) #t)
   'test-reduction-perf-02-02.rkt
   (test-dep '(syntax.rkt prelude.rkt surface-syntax.rkt reader.rkt parser.rkt
               driver.rkt global-env.rkt reduction.rkt namespace.rkt macros.rkt) #t)
   'test-lattice.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt namespace.rkt
               macros.rkt qtt.rkt)
             '(prologos::core::lattice))
   'test-propagator.rkt
   (test-dep '(propagator.rkt champ.rkt) #f)
   'test-propagator-network.rkt
   (test-dep '(propagator.rkt champ.rkt) #f)
   'test-propagator-persistence.rkt
   (test-dep '(propagator.rkt champ.rkt) #f)
   'test-propagator-bsp.rkt
   (test-dep '(propagator.rkt champ.rkt) #f)
   'test-propagator-types.rkt
   (test-dep '(propagator.rkt syntax.rkt typing-core.rkt qtt.rkt substitution.rkt pretty-print.rkt) #f)
   'test-propagator-integration.rkt
   (test-dep '(propagator.rkt syntax.rkt typing-core.rkt reduction.rkt parser.rkt elaborator.rkt surface-syntax.rkt) #t)
   'test-propagator-lvar.rkt
   (test-dep '(propagator.rkt syntax.rkt typing-core.rkt reduction.rkt parser.rkt elaborator.rkt
               surface-syntax.rkt namespace.rkt macros.rkt) #t)
   'test-new-lattice-cell.rkt
   (test-dep '(propagator.rkt syntax.rkt typing-core.rkt qtt.rkt reduction.rkt parser.rkt
               elaborator.rkt surface-syntax.rkt namespace.rkt macros.rkt) #t)
   'test-call-site-specialization.rkt
   (test-dep '(propagator.rkt syntax.rkt typing-core.rkt qtt.rkt reduction.rkt parser.rkt
               elaborator.rkt surface-syntax.rkt namespace.rkt macros.rkt driver.rkt) #t)
   ;; Widenable trait + widening fixpoint (Phase 6a)
   'test-widenable-trait.rkt
   (test-dep '(propagator.rkt syntax.rkt typing-core.rkt qtt.rkt reduction.rkt parser.rkt
               elaborator.rkt surface-syntax.rkt namespace.rkt macros.rkt) #t)
   'test-widening-fixpoint.rkt
   (test-dep '(propagator.rkt champ.rkt) #f)
   ;; GaloisConnection trait (Phase 6b)
   'test-galois-connection.rkt
   (test-dep '(syntax.rkt typing-core.rkt qtt.rkt reduction.rkt parser.rkt
               elaborator.rkt surface-syntax.rkt namespace.rkt macros.rkt) #t)
   ;; Sign-Galois connection (Phase 6 deferred, now complete)
   'test-sign-galois.rkt
   (test-dep '(syntax.rkt typing-core.rkt qtt.rkt reduction.rkt parser.rkt
               elaborator.rkt surface-syntax.rkt namespace.rkt macros.rkt) #t)
   ;; Cross-domain propagation (Phase 6c)
   'test-cross-domain-propagator.rkt
   (test-dep '(propagator.rkt champ.rkt) #f)
   ;; Abstract domains (Phase 6d)
   'test-abstract-domains.rkt
   (test-dep '(syntax.rkt typing-core.rkt qtt.rkt reduction.rkt parser.rkt
               elaborator.rkt surface-syntax.rkt namespace.rkt macros.rkt) #t)
   ;; Phase 6e: Integration + specialization
   'test-widen-specialization.rkt
   (test-dep '(propagator.rkt syntax.rkt typing-core.rkt qtt.rkt reduction.rkt parser.rkt
               elaborator.rkt surface-syntax.rkt namespace.rkt macros.rkt driver.rkt) #t)
   'test-abstract-interpretation-e2e.rkt
   (test-dep '(propagator.rkt champ.rkt syntax.rkt typing-core.rkt qtt.rkt reduction.rkt parser.rkt
               elaborator.rkt surface-syntax.rkt namespace.rkt macros.rkt) #t)
   ;; Negative literal support
   'test-negative-literals.rkt
   (test-dep '(reader.rkt parser.rkt syntax.rkt typing-core.rkt qtt.rkt reduction.rkt
               elaborator.rkt surface-syntax.rkt namespace.rkt macros.rkt) #t)
   ;; Refined numeric types (PosInt/NegInt/Zero, PosRat/NegRat)
   'test-refined-int.rkt
   (test-dep '(syntax.rkt typing-core.rkt qtt.rkt reduction.rkt parser.rkt
               elaborator.rkt surface-syntax.rkt namespace.rkt macros.rkt) #t)
   'test-refined-rat.rkt
   (test-dep '(syntax.rkt typing-core.rkt qtt.rkt reduction.rkt parser.rkt
               elaborator.rkt surface-syntax.rkt namespace.rkt macros.rkt) #t)
   ;; Refined numeric subtyping (Phase E: PosInt <: Int, NegRat <: Rat, etc.)
   'test-refined-subtyping.rkt
   (test-dep '(syntax.rkt typing-core.rkt qtt.rkt reduction.rkt parser.rkt
               elaborator.rkt surface-syntax.rkt namespace.rkt macros.rkt) #t)
   ;; UnionFind (persistent disjoint sets)
   'test-union-find.rkt
   (test-dep '(union-find.rkt) #f)
   'test-union-find-types.rkt
   (test-dep '(union-find.rkt syntax.rkt typing-core.rkt qtt.rkt substitution.rkt pretty-print.rkt reduction.rkt) #f)
   'test-union-find-integration.rkt
   (test-dep '(union-find.rkt syntax.rkt typing-core.rkt reduction.rkt parser.rkt elaborator.rkt surface-syntax.rkt) #t)
   ;; ATMS (hypothetical reasoning)
   'test-atms.rkt
   (test-dep '(atms.rkt propagator.rkt) #f)
   'test-atms-types.rkt
   (test-dep '(atms.rkt propagator.rkt syntax.rkt typing-core.rkt qtt.rkt substitution.rkt pretty-print.rkt reduction.rkt) #f)
   'test-atms-integration.rkt
   (test-dep '(atms.rkt propagator.rkt syntax.rkt typing-core.rkt reduction.rkt parser.rkt elaborator.rkt surface-syntax.rkt) #t)
   ;; Tabling (SLG-style memoization)
   'test-tabling.rkt
   (test-dep '(tabling.rkt propagator.rkt) #f)
   'test-tabling-types.rkt
   (test-dep '(tabling.rkt propagator.rkt syntax.rkt typing-core.rkt qtt.rkt substitution.rkt pretty-print.rkt reduction.rkt) #f)
   'test-tabling-integration.rkt
   (test-dep '(tabling.rkt propagator.rkt syntax.rkt typing-core.rkt reduction.rkt parser.rkt elaborator.rkt surface-syntax.rkt) #t)
   ;; Relational language (Phase 7)
   'test-solver-config.rkt
   (test-dep '(solver.rkt) #f)
   'test-relations-runtime.rkt
   (test-dep '(relations.rkt propagator.rkt tabling.rkt union-find.rkt solver.rkt) #f)
   'test-stratify.rkt
   (test-dep '(stratify.rkt) #f)
   'test-provenance.rkt
   (test-dep '(provenance.rkt solver.rkt) #f)
   'test-reader-relational.rkt
   (test-dep '(reader.rkt sexp-readtable.rkt) #f)
   'test-parser-relational.rkt
   (test-dep '(parser.rkt surface-syntax.rkt macros.rkt sexp-readtable.rkt) #f)
   'test-relational-types.rkt
   (test-dep '(syntax.rkt typing-core.rkt qtt.rkt substitution.rkt pretty-print.rkt reduction.rkt elaborator.rkt surface-syntax.rkt solver.rkt) #f)
   'test-relational-e2e.rkt
   (test-dep '(driver.rkt parser.rkt elaborator.rkt reduction.rkt relations.rkt solver.rkt macros.rkt surface-syntax.rkt syntax.rkt) #f)
   'test-perf-counters.rkt
   (test-dep '(performance-counters.rkt) #f)
   'test-phase-timing.rkt
   (test-dep '(performance-counters.rkt driver.rkt global-env.rkt) #t)
   'test-generators.rkt
   (test-dep '(syntax.rkt typing-core.rkt metavar-store.rkt reduction.rkt unify.rkt global-env.rkt performance-counters.rkt) #f)
   'test-properties.rkt
   (test-dep '(syntax.rkt typing-core.rkt metavar-store.rkt reduction.rkt unify.rkt zonk.rkt global-env.rkt performance-counters.rkt) #f)
   'test-type-lattice.rkt
   (test-dep '(type-lattice.rkt syntax.rkt reduction.rkt zonk.rkt substitution.rkt propagator.rkt champ.rkt) #f)
   'test-elaborator-network.rkt
   (test-dep '(elaborator-network.rkt propagator.rkt type-lattice.rkt champ.rkt syntax.rkt) #f)
   'test-elab-speculation.rkt
   (test-dep '(elab-speculation.rkt elaborator-network.rkt atms.rkt type-lattice.rkt propagator.rkt) #f)
   'test-speculation-bridge.rkt
   (test-dep '(elab-speculation-bridge.rkt metavar-store.rkt typing-core.rkt qtt.rkt) #t)))

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
   ;; Foundation types (no deps)
   'prologos::core             '()
   'prologos::data::nat         '()
   'prologos::data::bool        '()
   'prologos::data::option      '()
   'prologos::data::ordering    '()
   'prologos::data::pair        '()
   'prologos::data::never       '()
   'prologos::data::eq          '()
   'prologos::data::datum       '()

   ;; Data structures layer 1
   'prologos::data::lseq        '(prologos::data::option)
   'prologos::data::list        '(prologos::core::eq prologos::data::option prologos::data::nat)
   'prologos::data::either      '(prologos::data::option)
   'prologos::data::result      '(prologos::data::option)
   'prologos::data::set         '(prologos::data::list)
   'prologos::data::lseq-ops    '(prologos::data::lseq)
   'prologos::data::transducer  '(prologos::data::lseq)

   ;; Trait definitions
   'prologos::core::eq              '(prologos::data::nat prologos::data::bool
                                          prologos::data::ordering prologos::data::option
                                          prologos::data::char prologos::data::string)
   'prologos::core::eq-derived      '(prologos::core::eq prologos::data::list
                                          prologos::data::bool)
   'prologos::core::ord              '(prologos::data::ordering prologos::data::nat prologos::data::bool
                                          prologos::data::option prologos::data::char prologos::data::string)
   ;; add/sub/mul/div/neg/abs traits + instances + add-string-instance merged into prologos::core::arithmetic
   'prologos::core::arithmetic      '(prologos::data::nat prologos::data::string)
   ;; from-trait/from-instances/tryfrom-trait/tryfrom-instances/into-trait/fromint-trait/fromint-posit-instances/fromrat-trait/fromrat-posit-instances merged into prologos::core::conversions
   'prologos::core::conversions     '(prologos::data::option)
   ;; hashable-trait + hashable-instances + hashable-char-instance + hashable-string-instance merged into prologos::core::hashable
   'prologos::core::hashable         '(prologos::data::nat prologos::data::option
                                       prologos::data::list prologos::data::ordering)
   'prologos::core::collection-traits '(prologos::data::lseq prologos::data::option)
   ;; partialord-trait merged into prologos::core::ord

   ;; Trait instances
   ;; eq-instances, eq-derived, eq-numeric-instances merged into prologos::core::eq
   ;; ord-instances, ord-numeric-instances merged into prologos::core::ord
   ;; add-instances/sub-instances/mul-instances/div-instances/neg-instances/abs-instances merged into prologos::core::arithmetic
   ;; from-instances/tryfrom-instances/fromint-posit-instances/fromrat-posit-instances merged into prologos::core::conversions
   ;; hashable-instances merged into prologos::core::hashable

   ;; Char/String data modules
   'prologos::data::char         '()
   'prologos::data::string       '()

   ;; Char/String trait instances
   ;; eq-char-instance merged into prologos::core::eq
   ;; ord-char-instance merged into prologos::core::ord
   ;; hashable-char-instance merged into prologos::core::hashable
   ;; eq-string-instance merged into prologos::core::eq
   ;; ord-string-instance merged into prologos::core::ord
   ;; hashable-string-instance merged into prologos::core::hashable
   ;; add-string-instance merged into prologos::core::arithmetic

   ;; String operations
   'prologos::core::string-ops    '(prologos::data::string prologos::data::char
                                    prologos::data::list prologos::data::option
                                    prologos::data::pair)

   ;; Collection trait instances (consolidated by type)
   ;; list: Seqable, Buildable, Foldable, Reducible, Indexed, Functor, Seq
   'prologos::core::list           '(prologos::core::collection-traits prologos::data::list
                                     prologos::data::lseq prologos::data::lseq-ops
                                     prologos::data::option prologos::data::nat)
   ;; pvec: Seqable, Buildable, Foldable, Reducible, Indexed, Functor + ops
   'prologos::core::pvec           '(prologos::core::collection-traits prologos::data::list
                                     prologos::data::lseq prologos::data::lseq-ops
                                     prologos::data::option prologos::data::nat)
   ;; set: Seqable, Buildable, Foldable, Reducible, Setlike + ops
   'prologos::core::set            '(prologos::core::collection-traits prologos::data::list
                                     prologos::data::lseq prologos::data::lseq-ops)
   ;; lseq: Seqable, Buildable, Foldable, Reducible, Seq
   'prologos::core::lseq           '(prologos::core::collection-traits prologos::data::lseq
                                     prologos::data::lseq-ops prologos::data::list
                                     prologos::data::option)
   ;; map: Keyed + ops
   'prologos::core::map            '(prologos::core::collection-traits prologos::data::option
                                     prologos::data::list prologos::data::map-entry
                                     prologos::data::lseq prologos::data::lseq-ops)
   'prologos::core::generic-ops  '(prologos::core::collection-traits prologos::data::option
                                   prologos::data::list prologos::data::lseq prologos::data::lseq-ops)

   ;; Consolidated lattice hierarchy (lattice-trait + lattice-instances + has-top-trait +
   ;; has-top-instances + bounded-lattice + widenable-trait + widenable-instances +
   ;; galois-trait + galois-instances)
   'prologos::core::lattice             '(prologos::core::eq
                                          prologos::data::bool)
   'prologos::core::propagator          '(prologos::core::lattice)

   ;; Standard capability types + subtype hierarchy
   'prologos::core::capabilities       '()

   ;; Consolidated abstract domains (sign-lattice + sign-galois + parity-lattice +
   ;; refined-int-instances + refined-rat-instances)
   'prologos::data::sign                '()
   'prologos::data::parity              '()
   'prologos::data::refined-int         '(prologos::data::option)
   'prologos::data::refined-rat         '(prologos::data::option)
   'prologos::core::abstract-domains    '(prologos::data::sign
                                          prologos::data::parity
                                          prologos::core::lattice
                                          prologos::core::eq
                                          prologos::core::ord
                                          prologos::data::ordering
                                          prologos::data::refined-int
                                          prologos::data::refined-rat
                                          prologos::data::bool)

   ;; Higher-level abstractions
   'prologos::core::algebra '(prologos::core::arithmetic
                              prologos::core::eq prologos::core::ord
                              prologos::core::conversions
                              prologos::data::list)
   'prologos::core::collections '(prologos::core::collection-traits
                                   prologos::core::list
                                   prologos::data::lseq prologos::data::lseq-ops
                                   prologos::data::list prologos::data::option)))

;; ============================================================
;; Layer 3b: Test → .prologos runtime dependencies
;; Which .prologos modules each driver-using test loads via string require
;; Conservative: if a test loads prologos::data::list, it transitively depends on
;; all of list's deps too (handled by transitive closure)
;; ============================================================

(define test-prologos-deps
  (hasheq
   ;; Tests that load specific .prologos modules at runtime
   ;; (extracted from require strings in test files)
   'test-stdlib-01-data-01.rkt   '(prologos::data::nat prologos::data::bool prologos::data::list
                                  prologos::data::option prologos::data::result
                                  prologos::data::ordering prologos::data::pair prologos::data::eq)
   'test-stdlib-01-data-02.rkt   '(prologos::data::nat prologos::data::bool prologos::data::list
                                  prologos::data::option prologos::data::result
                                  prologos::data::ordering prologos::data::pair prologos::data::eq)
   'test-stdlib-01-data-03.rkt   '(prologos::data::nat prologos::data::bool prologos::data::list
                                  prologos::data::option prologos::data::result
                                  prologos::data::ordering prologos::data::pair prologos::data::eq)
   'test-stdlib-01-data-04.rkt   '(prologos::data::nat prologos::data::bool prologos::data::list
                                  prologos::data::option prologos::data::result
                                  prologos::data::ordering prologos::data::pair prologos::data::eq)
   'test-stdlib-02-traits-01.rkt '(prologos::data::nat prologos::data::bool prologos::data::list
                                  prologos::data::option prologos::data::result
                                  prologos::core::eq prologos::core::ord
                                  prologos::data::ordering)
   'test-stdlib-02-traits-02.rkt '(prologos::data::nat prologos::data::bool prologos::data::list
                                  prologos::data::option prologos::data::result
                                  prologos::core::eq prologos::core::ord
                                  prologos::data::ordering)
   'test-stdlib-02-traits-03.rkt '(prologos::data::nat prologos::data::bool prologos::data::list
                                  prologos::data::option prologos::data::result
                                  prologos::core::eq prologos::core::ord
                                  prologos::data::ordering)
   'test-stdlib-02-traits-04.rkt '(prologos::data::nat prologos::data::bool prologos::data::list
                                  prologos::data::option prologos::data::result
                                  prologos::core::eq prologos::core::ord
                                  prologos::data::ordering)
   'test-stdlib-02-traits-05.rkt '(prologos::data::nat prologos::data::bool prologos::data::list
                                  prologos::data::option prologos::data::result
                                  prologos::core::eq prologos::core::ord
                                  prologos::data::ordering)
   'test-stdlib-02-traits-06.rkt '(prologos::data::nat prologos::data::bool prologos::data::list
                                  prologos::data::option prologos::data::result
                                  prologos::core::eq prologos::core::ord
                                  prologos::data::ordering)
   'test-stdlib-02-traits-07.rkt '(prologos::data::nat prologos::data::bool prologos::data::list
                                  prologos::data::option prologos::data::result
                                  prologos::core::eq prologos::core::ord
                                  prologos::data::ordering)
   'test-stdlib-03-list-01.rkt   '(prologos::data::nat prologos::data::bool prologos::data::list
                                  prologos::data::option prologos::core::eq)
   'test-stdlib-03-list-02.rkt   '(prologos::data::nat prologos::data::bool prologos::data::list
                                  prologos::data::option prologos::core::eq)
   'test-stdlib-03-list-03.rkt   '(prologos::data::nat prologos::data::bool prologos::data::list
                                  prologos::data::option prologos::core::eq)
   'test-stdlib-03-list-04-01.rkt '(prologos::data::nat prologos::data::bool prologos::data::list
                                  prologos::data::option prologos::core::eq)
   'test-stdlib-03-list-04-02.rkt '(prologos::data::nat prologos::data::bool prologos::data::list
                                  prologos::data::option prologos::core::eq)
   'test-stdlib-03-list-05.rkt   '(prologos::data::nat prologos::data::bool prologos::data::list
                                  prologos::data::option prologos::core::eq)
   'test-list-extended-01-01.rkt '(prologos::data::list prologos::data::nat prologos::data::option
                                  prologos::core::eq)
   'test-list-extended-01-02.rkt '(prologos::data::list prologos::data::nat prologos::data::option
                                  prologos::core::eq)
   'test-list-extended-02-01.rkt '(prologos::data::list prologos::data::nat prologos::data::option
                                  prologos::core::eq)
   'test-list-extended-02-02.rkt '(prologos::data::list prologos::data::nat prologos::data::option
                                  prologos::core::eq)
   'test-trait-impl-01.rkt       '(prologos::data::nat prologos::data::bool prologos::data::option
                                  prologos::data::either prologos::data::list
                                  prologos::core::eq prologos::core::collection-traits
                                  prologos::core::list prologos::core::generic-ops)
   'test-trait-impl-02.rkt       '(prologos::data::nat prologos::data::bool prologos::data::option
                                  prologos::data::either prologos::data::list
                                  prologos::core::eq prologos::core::collection-traits
                                  prologos::core::list prologos::core::generic-ops)
   'test-trait-impl-03.rkt       '(prologos::data::nat prologos::data::bool prologos::data::option
                                  prologos::data::either prologos::data::list
                                  prologos::core::eq prologos::core::collection-traits
                                  prologos::core::list prologos::core::generic-ops)
   'test-trait-impl-04-01.rkt     '(prologos::data::nat prologos::data::bool prologos::data::option
                                  prologos::data::either prologos::data::list
                                  prologos::core::eq prologos::core::collection-traits
                                  prologos::core::list prologos::core::generic-ops)
   'test-trait-impl-04-02.rkt     '(prologos::data::nat prologos::data::bool prologos::data::option
                                  prologos::data::either prologos::data::list
                                  prologos::core::eq prologos::core::collection-traits
                                  prologos::core::list prologos::core::generic-ops)
   'test-trait-resolution.rkt   '(prologos::data::nat prologos::data::bool prologos::core::eq)
   'test-method-resolution.rkt  '(prologos::data::nat prologos::data::bool prologos::core::eq
                                  prologos::core::arithmetic)
   'test-bundles.rkt            '(prologos::data::nat prologos::data::bool prologos::core::eq
                                  prologos::core::arithmetic prologos::core::algebra)
   'test-prelude-numerics.rkt   '(prologos::core::arithmetic prologos::core::arithmetic
                                  prologos::core::conversions
                                  prologos::core::algebra)
   'test-generic-arith-02.rkt   '(prologos::core::algebra
                                  prologos::core::arithmetic prologos::core::arithmetic
                                  prologos::core::arithmetic prologos::core::arithmetic
                                  prologos::core::arithmetic prologos::core::arithmetic
                                  prologos::core::arithmetic prologos::core::arithmetic
                                  prologos::core::arithmetic prologos::core::arithmetic
                                  prologos::core::arithmetic prologos::core::arithmetic)
   'test-numeric-traits-01.rkt   '(prologos::data::nat prologos::core::arithmetic
                                  prologos::core::arithmetic prologos::core::arithmetic
                                  prologos::core::eq prologos::core::ord)
   'test-numeric-traits-02.rkt   '(prologos::data::nat prologos::core::arithmetic
                                  prologos::core::arithmetic prologos::core::arithmetic
                                  prologos::core::eq prologos::core::ord
                                  prologos::core::algebra)
   'test-cross-family-conversions-01.rkt '(prologos::core::conversions
                                        prologos::data::nat prologos::data::option)
   'test-cross-family-conversions-02.rkt '(prologos::core::conversions
                                        prologos::data::nat prologos::data::option)
   'test-cross-family-conversions-03.rkt '(prologos::core::conversions
                                        prologos::data::nat prologos::data::option)
   'test-subtyping.rkt          '(prologos::data::nat)
   'test-eq-ord-extended-01.rkt  '(prologos::data::nat prologos::data::bool prologos::data::ordering
                                  prologos::data::option prologos::data::list
                                  prologos::core::eq prologos::core::ord
                                  prologos::core::eq)
   'test-eq-ord-extended-02.rkt  '(prologos::data::nat prologos::data::bool prologos::data::ordering
                                  prologos::data::option prologos::data::list
                                  prologos::core::eq prologos::core::ord
                                  prologos::core::eq)
   'test-hashable-01.rkt         '(prologos::core::hashable
                                  prologos::data::nat prologos::data::bool prologos::data::ordering
                                  prologos::data::option prologos::data::list)
   'test-hashable-02.rkt         '(prologos::core::hashable
                                  prologos::data::nat prologos::data::bool prologos::data::ordering
                                  prologos::data::option prologos::data::list)
   'test-collection-traits-01.rkt '(prologos::data::list prologos::data::nat prologos::data::option
                                  prologos::core::list
                                  prologos::core::collections)
   'test-collection-traits-02.rkt '(prologos::data::list prologos::data::nat prologos::data::option
                                  prologos::core::list
                                  prologos::core::collections)
   'test-reducible.rkt            '(prologos::core::collection-traits prologos::core::collection-traits
                                  prologos::core::list prologos::core::pvec
                                  prologos::core::set prologos::core::lseq
                                  prologos::core::collections
                                  prologos::data::list prologos::data::nat prologos::data::option
                                  prologos::data::lseq prologos::data::lseq-ops)
   'test-generic-ops-01-01.rkt    '(prologos::data::list prologos::data::nat prologos::data::option
                                  prologos::core::collection-traits prologos::core::generic-ops
                                  prologos::core::collections)
   'test-generic-ops-01-02.rkt    '(prologos::data::list prologos::data::nat prologos::data::option
                                  prologos::core::collection-traits prologos::core::generic-ops
                                  prologos::core::collections)
   'test-generic-ops-02-01.rkt    '(prologos::data::list prologos::data::nat prologos::data::option
                                  prologos::core::collection-traits prologos::core::generic-ops
                                  prologos::core::collections)
   'test-generic-ops-02-02.rkt    '(prologos::data::list prologos::data::nat prologos::data::option
                                  prologos::core::collection-traits prologos::core::generic-ops
                                  prologos::core::collections)
   'test-hkt-errors.rkt         '()  ; Uses ns/prelude — no extra lib deps
   'test-specialization.rkt     '()  ; Uses ns/prelude — no extra lib deps
   'test-constraint-inference.rkt '() ; Uses ns/prelude — no extra lib deps
   'test-lseq-01.rkt             '(prologos::data::lseq prologos::data::lseq-ops prologos::data::list
                                  prologos::data::nat prologos::data::option)
   'test-lseq-02.rkt             '(prologos::data::lseq prologos::data::lseq-ops prologos::data::list
                                  prologos::data::nat prologos::data::option)
   'test-lseq-literal.rkt       '(prologos::data::lseq prologos::data::list prologos::data::nat)
   'test-foreign.rkt            '(prologos::data::nat)
   'test-foreign-block.rkt      '(prologos::data::nat)
   'test-pipe-compose.rkt       '()  ; Fast tests only — no .prologos deps
   'test-pipe-compose-e2e-01.rkt '(prologos::data::nat prologos::data::list
                                  prologos::data::transducer prologos::data::lseq
                                  prologos::data::lseq-ops)
   'test-pipe-compose-e2e-02.rkt '(prologos::data::nat prologos::data::list
                                  prologos::data::transducer prologos::data::lseq
                                  prologos::data::lseq-ops)
   'test-transducer-01.rkt       '(prologos::data::nat prologos::data::list prologos::data::lseq
                                  prologos::data::transducer)
   'test-transducer-02.rkt       '(prologos::data::nat prologos::data::list prologos::data::lseq
                                  prologos::data::transducer)
   'test-higher-rank.rkt        '(prologos::data::nat prologos::data::list)
   'test-varargs.rkt            '(prologos::data::nat prologos::data::list)
   'test-mixfix.rkt             '(prologos::data::nat prologos::data::list)
   'test-sexp-reader-parity.rkt '(prologos::data::nat prologos::data::list)
   'test-introspection.rkt      '(prologos::data::datum)
   'test-quote.rkt              '(prologos::data::datum)
   'test-kind-inference.rkt     '(prologos::core::collection-traits prologos::core::collection-traits
                                  prologos::data::lseq prologos::data::nat)
   'test-hkt-impl.rkt           '(prologos::core::collection-traits prologos::core::collection-traits
                                  prologos::core::collection-traits prologos::core::collection-traits
                                  prologos::core::list prologos::core::pvec
                                  prologos::core::lseq prologos::core::set
                                  prologos::data::nat prologos::data::list prologos::data::lseq)
   'test-coherence.rkt          '(prologos::core::eq prologos::data::nat)
   'test-bare-methods.rkt       '(prologos::core::eq prologos::core::ord
                                  prologos::core::arithmetic prologos::data::nat)
   'test-hkt-kind.rkt           '(prologos::data::nat prologos::data::option prologos::data::list)
   'test-match-builtins.rkt     '(prologos::data::nat)
   'test-list-literals.rkt      '(prologos::data::nat prologos::data::list)
   'test-core-prelude.rkt       '(prologos::data::nat)
   'test-prelude-system-01.rkt   '(prologos::core prologos::data::nat prologos::data::bool
                                  prologos::data::pair prologos::data::ordering prologos::data::eq
                                  prologos::data::list prologos::data::option prologos::data::result
                                  prologos::core::eq prologos::core::ord
                                  prologos::core::arithmetic prologos::core::arithmetic
                                  prologos::core::arithmetic prologos::core::arithmetic
                                  prologos::core::arithmetic prologos::core::conversions
                                  prologos::core::algebra
                                  prologos::core::eq prologos::core::eq
                                  prologos::core::ord prologos::core::ord
                                  prologos::core::arithmetic prologos::core::arithmetic
                                  prologos::core::arithmetic prologos::core::arithmetic
                                  prologos::core::arithmetic)
   'test-prelude-system-02.rkt   '(prologos::core prologos::data::nat prologos::data::bool
                                  prologos::data::pair prologos::data::ordering prologos::data::eq
                                  prologos::data::list prologos::data::option prologos::data::result
                                  prologos::core::eq prologos::core::ord
                                  prologos::core::arithmetic prologos::core::arithmetic
                                  prologos::core::arithmetic prologos::core::arithmetic
                                  prologos::core::arithmetic prologos::core::conversions
                                  prologos::core::algebra
                                  prologos::core::eq prologos::core::eq
                                  prologos::core::ord prologos::core::ord
                                  prologos::core::arithmetic prologos::core::arithmetic
                                  prologos::core::arithmetic prologos::core::arithmetic
                                  prologos::core::arithmetic)
   'test-auto-implicits.rkt     '(prologos::data::nat)
   'test-kind-inference-where.rkt '(prologos::core::collection-traits prologos::core::collection-traits
                                    prologos::core::eq prologos::core::ord
                                    prologos::data::lseq)
   'test-sprint10.rkt           '(prologos::data::nat prologos::data::bool)
   'test-surface-defmacro-01.rkt '(prologos::data::nat)
   'test-surface-defmacro-02.rkt '(prologos::data::nat)
   'test-where-parsing.rkt      '(prologos::data::nat prologos::data::bool prologos::core::eq)
   'test-error-messages.rkt     '(prologos::data::nat prologos::core::eq)
   'test-constraint-postponement.rkt '(prologos::data::nat prologos::core)
   'test-mult-inference.rkt     '(prologos::data::nat)
   'test-universe-level-inference.rkt '(prologos::data::nat prologos::core)
   'test-unit-type.rkt          '(prologos::data::nat)
   'test-qtt-pipeline.rkt       '(prologos::data::nat)
   'test-implicit-inference.rkt  '(prologos::data::nat)
   'test-char-string.rkt         '(prologos::data::char prologos::data::string
                                   prologos::core::eq prologos::core::ord
                                   prologos::core::hashable
                                   prologos::core::arithmetic)
   'test-string-ops.rkt          '(prologos::data::char prologos::data::string
                                   prologos::core::string-ops
                                   prologos::data::list prologos::data::option
                                   prologos::data::pair)
   'test-lattice.rkt             '(prologos::core::lattice
                                   prologos::core::eq
                                   prologos::data::bool)
   'test-propagator-lvar.rkt     '(prologos::core::lattice
                                   prologos::core::propagator
                                   prologos::data::bool)
   'test-new-lattice-cell.rkt    '(prologos::core::propagator
                                   prologos::core::lattice)
   'test-call-site-specialization.rkt '(prologos::core::propagator
                                        prologos::core::lattice)
   'test-widenable-trait.rkt          '(prologos::core::lattice
                                        prologos::core::propagator)
   'test-galois-connection.rkt        '(prologos::core::lattice)
   'test-sign-galois.rkt              '(prologos::core::lattice
                                        prologos::core::abstract-domains
                                        prologos::data::sign
                                        prologos::data::bool)
   'test-abstract-domains.rkt         '(prologos::data::sign
                                        prologos::data::parity
                                        prologos::core::lattice
                                        prologos::core::abstract-domains)
   'test-widen-specialization.rkt     '(prologos::core::propagator
                                        prologos::core::lattice)
   'test-abstract-interpretation-e2e.rkt '(prologos::core::propagator
                                           prologos::core::lattice
                                           prologos::core::abstract-domains
                                           prologos::data::sign
                                           prologos::data::parity)
   'test-refined-int.rkt               '(prologos::data::refined-int
                                           prologos::core::abstract-domains
                                           prologos::data::option
                                           prologos::core::eq
                                           prologos::core::ord
                                           prologos::data::ordering)
   'test-refined-rat.rkt               '(prologos::data::refined-rat
                                           prologos::core::abstract-domains
                                           prologos::data::option
                                           prologos::core::eq
                                           prologos::core::ord
                                           prologos::data::ordering)
   'test-refined-subtyping.rkt         '(prologos::data::refined-int
                                           prologos::data::refined-rat
                                           prologos::core::abstract-domains
                                           prologos::data::option
                                           prologos::core::eq
                                           prologos::core::ord
                                           prologos::data::ordering)))

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
