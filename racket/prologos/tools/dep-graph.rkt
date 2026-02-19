#lang racket/base

;; dep-graph.rkt — Three-layer dependency DAG for targeted test running
;;
;; Layer 1: Source .rkt module forward-deps (module → modules it requires)
;; Layer 2: Test → source module deps (test → source modules it requires)
;; Layer 3: .prologos library forward-deps (lib → libs it requires)
;;
;; Plus: reverse-dep computation and affected-test-set algorithm.

(require racket/hash racket/list racket/set racket/string)

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
         (struct-out changed-example))

;; ============================================================
;; Change classification structs
;; ============================================================

(struct changed-source  (name) #:transparent)   ; symbol like 'syntax.rkt
(struct changed-test    (name) #:transparent)   ; symbol like 'test-parser.rkt
(struct changed-prologos (name) #:transparent)  ; symbol like 'prologos.data.nat
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
   'inductive.rkt        '(syntax.rkt typing-core.rkt)))

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
   'test-map.rkt
   (test-dep '(syntax.rkt prelude.rkt substitution.rkt reduction.rkt typing-core.rkt
               pretty-print.rkt driver.rkt global-env.rkt champ.rkt) #f)
   'test-approx-literal.rkt
   (test-dep '(syntax.rkt prelude.rkt surface-syntax.rkt reader.rkt parser.rkt
               driver.rkt global-env.rkt posit-impl.rkt) #f)

   ;; === Driver/integration tests (driver=yes) ===
   'test-stdlib.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-list-extended.rkt
   (test-dep '(errors.rkt driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-core-prelude.rkt
   (test-dep '(driver.rkt global-env.rkt namespace.rkt macros.rkt) #t)
   'test-auto-implicits.rkt
   (test-dep '(errors.rkt global-env.rkt driver.rkt namespace.rkt macros.rkt
               metavar-store.rkt) #t)
   'test-sprint10.rkt
   (test-dep '(errors.rkt global-env.rkt driver.rkt namespace.rkt macros.rkt
               metavar-store.rkt) #t)
   'test-surface-defmacro.rkt
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
   'test-trait-impl.rkt
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
   'test-where-parsing.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt) #t)
   'test-hkt-kind.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt) #t)
   'test-numeric-traits.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt trait-resolution.rkt) #t)
   'test-cross-family-conversions.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt posit-impl.rkt) #t)
   'test-subtyping.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt posit-impl.rkt) #t)
   'test-collection-traits.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt) #t)
   'test-generic-ops.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt) #t)
   'test-eq-ord-extended.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt) #t)
   'test-hashable.rkt
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt namespace.rkt multi-dispatch.rkt) #t)
   'test-lseq.rkt
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
   (test-dep '(macros.rkt prelude.rkt syntax.rkt source-location.rkt surface-syntax.rkt
               errors.rkt metavar-store.rkt parser.rkt elaborator.rkt pretty-print.rkt
               global-env.rkt driver.rkt reduction.rkt typing-core.rkt namespace.rkt
               trait-resolution.rkt reader.rkt) #t)
   'test-transducer.rkt
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
   'test-lang.rkt
   (test-dep '(main.rkt sexp.rkt expander.rkt) #t)
   'test-lang-errors.rkt
   (test-dep '(main.rkt sexp.rkt expander.rkt) #t)))

;; ============================================================
;; Layer 2b: Example file → test file mapping
;; ============================================================

(define example-test-map
  (hasheq
   'hello.rkt           '(test-lang.rkt)
   'hello-ws.rkt        '(test-lang.rkt)
   'identity.rkt        '(test-lang.rkt)
   'identity-ws.rkt     '(test-lang.rkt)
   'defn.rkt            '(test-lang.rkt)
   'defn-ws.rkt         '(test-lang.rkt)
   'pairs.rkt           '(test-lang.rkt)
   'pairs-ws.rkt        '(test-lang.rkt)
   'vectors.rkt         '(test-lang.rkt)
   'vectors-ws.rkt      '(test-lang.rkt)
   'spec-ws.rkt         '(test-lang.rkt)
   'posit8.rkt          '(test-lang.rkt)
   'posit8-ws.rkt       '(test-lang.rkt)
   'macros.rkt          '(test-lang.rkt)
   'macros-ws.rkt       '(test-lang.rkt)
   'let-arrow-ws.rkt    '(test-lang.rkt)
   'type-error.rkt      '(test-lang-errors.rkt)
   'type-error-ws.rkt   '(test-lang-errors.rkt)
   'unbound-var.rkt     '(test-lang-errors.rkt)
   'unbound-var-ws.rkt  '(test-lang-errors.rkt)))

;; ============================================================
;; Layer 3: .prologos library forward-deps
;; ============================================================

(define prologos-lib-deps
  (hasheq
   ;; Foundation types (no deps)
   'prologos.core             '()
   'prologos.data.nat         '()
   'prologos.data.bool        '()
   'prologos.data.option      '()
   'prologos.data.ordering    '()
   'prologos.data.pair        '()
   'prologos.data.never       '()
   'prologos.data.eq          '()
   'prologos.data.datum       '()

   ;; Data structures layer 1
   'prologos.data.lseq        '(prologos.data.option)
   'prologos.data.list        '(prologos.core.eq-trait prologos.data.option prologos.data.nat)
   'prologos.data.either      '(prologos.data.option)
   'prologos.data.result      '(prologos.data.option)
   'prologos.data.set         '(prologos.data.list)
   'prologos.data.lseq-ops    '(prologos.data.lseq)
   'prologos.data.transducer  '(prologos.data.lseq)

   ;; Trait definitions
   'prologos.core.eq-trait         '(prologos.data.nat prologos.data.bool)
   'prologos.core.ord-trait        '(prologos.data.ordering prologos.data.nat prologos.data.bool)
   'prologos.core.add-trait        '(prologos.data.nat)
   'prologos.core.sub-trait        '(prologos.data.nat)
   'prologos.core.mul-trait        '(prologos.data.nat)
   'prologos.core.div-trait        '()
   'prologos.core.neg-trait        '()
   'prologos.core.abs-trait        '()
   'prologos.core.fromint-trait    '()
   'prologos.core.fromrat-trait    '()
   'prologos.core.from-trait       '()
   'prologos.core.into-trait       '(prologos.core.from-trait)
   'prologos.core.tryfrom-trait    '(prologos.data.option)
   'prologos.core.hashable-trait   '(prologos.data.nat)
   'prologos.core.seq-trait        '(prologos.data.option)
   'prologos.core.seqable-trait    '(prologos.data.lseq)
   'prologos.core.buildable-trait  '(prologos.data.lseq)
   'prologos.core.foldable-trait   '()
   'prologos.core.functor-trait    '()
   'prologos.core.indexed-trait    '(prologos.data.option)
   'prologos.core.keyed-trait      '(prologos.data.option)
   'prologos.core.setlike-trait    '()
   'prologos.core.partialord-trait '(prologos.data.option prologos.data.ordering)

   ;; Trait instances
   'prologos.core.eq-instances          '(prologos.core.eq-trait prologos.data.bool
                                          prologos.data.ordering)
   'prologos.core.ord-instances         '(prologos.core.ord-trait prologos.data.ordering)
   'prologos.core.eq-derived            '(prologos.core.eq-trait prologos.data.option
                                          prologos.data.list prologos.data.bool)
   'prologos.core.eq-numeric-instances  '(prologos.core.eq-trait prologos.data.bool)
   'prologos.core.ord-numeric-instances '(prologos.core.ord-trait prologos.data.ordering
                                          prologos.data.bool)
   'prologos.core.add-instances         '(prologos.core.add-trait)
   'prologos.core.sub-instances         '(prologos.core.sub-trait)
   'prologos.core.mul-instances         '(prologos.core.mul-trait)
   'prologos.core.div-instances         '(prologos.core.div-trait)
   'prologos.core.neg-instances         '(prologos.core.neg-trait)
   'prologos.core.abs-instances         '(prologos.core.abs-trait)
   'prologos.core.from-instances        '(prologos.core.from-trait)
   'prologos.core.tryfrom-instances     '(prologos.core.tryfrom-trait prologos.data.option)
   'prologos.core.fromint-posit-instances '(prologos.core.fromint-trait)
   'prologos.core.fromrat-posit-instances '(prologos.core.fromrat-trait)
   'prologos.core.hashable-instances    '(prologos.core.hashable-trait prologos.data.nat
                                          prologos.data.option prologos.data.list
                                          prologos.data.ordering)

   ;; Collection trait instances
   'prologos.core.seq-list       '(prologos.core.seq-trait prologos.data.list
                                   prologos.data.option)
   'prologos.core.seqable-list   '(prologos.core.seqable-trait prologos.data.lseq
                                   prologos.data.lseq-ops prologos.data.list)
   'prologos.core.buildable-list '(prologos.core.buildable-trait prologos.data.lseq
                                   prologos.data.lseq-ops prologos.data.list)
   'prologos.core.indexed-list   '(prologos.core.indexed-trait prologos.data.option
                                   prologos.data.list prologos.data.nat)
   'prologos.core.foldable-list  '(prologos.core.foldable-trait prologos.data.list)
   'prologos.core.functor-list   '(prologos.core.functor-trait prologos.data.list)
   'prologos.core.seq-functions  '(prologos.core.seq-trait prologos.data.option
                                   prologos.data.list)

   ;; Higher-level abstractions
   'prologos.core.numeric-bundles '(prologos.core.add-trait prologos.core.sub-trait
                                    prologos.core.mul-trait prologos.core.div-trait
                                    prologos.core.neg-trait prologos.core.abs-trait
                                    prologos.core.eq-trait prologos.core.ord-trait
                                    prologos.core.fromint-trait prologos.core.fromrat-trait)
   'prologos.core.collection-ops '(prologos.core.seqable-list prologos.core.buildable-list
                                   prologos.data.lseq prologos.data.lseq-ops
                                   prologos.data.list)))

;; ============================================================
;; Layer 3b: Test → .prologos runtime dependencies
;; Which .prologos modules each driver-using test loads via string require
;; Conservative: if a test loads prologos.data.list, it transitively depends on
;; all of list's deps too (handled by transitive closure)
;; ============================================================

(define test-prologos-deps
  (hasheq
   ;; Tests that load specific .prologos modules at runtime
   ;; (extracted from require strings in test files)
   'test-stdlib.rkt             '(prologos.data.nat prologos.data.bool prologos.data.list
                                  prologos.data.option prologos.core.eq-trait
                                  prologos.core.ord-trait prologos.data.ordering)
   'test-list-extended.rkt      '(prologos.data.list prologos.data.nat prologos.data.option
                                  prologos.core.eq-trait)
   'test-trait-impl.rkt         '(prologos.data.nat prologos.data.bool prologos.data.option
                                  prologos.data.either prologos.data.list
                                  prologos.core.eq-trait prologos.core.seq-trait
                                  prologos.core.seq-list prologos.core.seq-functions)
   'test-trait-resolution.rkt   '(prologos.data.nat prologos.data.bool prologos.core.eq-trait)
   'test-method-resolution.rkt  '(prologos.data.nat prologos.data.bool prologos.core.eq-trait
                                  prologos.core.add-trait)
   'test-bundles.rkt            '(prologos.data.nat prologos.data.bool prologos.core.eq-trait
                                  prologos.core.add-trait prologos.core.numeric-bundles)
   'test-numeric-traits.rkt     '(prologos.data.nat prologos.core.add-trait
                                  prologos.core.sub-trait prologos.core.mul-trait
                                  prologos.core.eq-trait prologos.core.ord-trait)
   'test-cross-family-conversions.rkt '(prologos.core.from-trait prologos.core.tryfrom-trait
                                        prologos.core.fromint-trait prologos.core.fromrat-trait
                                        prologos.data.nat prologos.data.option)
   'test-subtyping.rkt          '(prologos.data.nat)
   'test-eq-ord-extended.rkt    '(prologos.data.nat prologos.data.bool prologos.data.ordering
                                  prologos.data.option prologos.data.list
                                  prologos.core.eq-trait prologos.core.ord-trait
                                  prologos.core.eq-derived)
   'test-hashable.rkt           '(prologos.core.hashable-trait prologos.core.hashable-instances
                                  prologos.data.nat prologos.data.bool prologos.data.ordering
                                  prologos.data.option prologos.data.list)
   'test-collection-traits.rkt  '(prologos.data.list prologos.data.nat prologos.data.option
                                  prologos.core.indexed-list prologos.core.foldable-list
                                  prologos.core.functor-list prologos.core.seq-list
                                  prologos.core.seqable-list prologos.core.buildable-list
                                  prologos.core.collection-ops)
   'test-generic-ops.rkt        '(prologos.data.list prologos.data.nat prologos.data.option
                                  prologos.core.seq-trait prologos.core.seq-functions
                                  prologos.core.collection-ops)
   'test-lseq.rkt               '(prologos.data.lseq prologos.data.lseq-ops prologos.data.list
                                  prologos.data.nat prologos.data.option)
   'test-lseq-literal.rkt       '(prologos.data.lseq prologos.data.list prologos.data.nat)
   'test-foreign.rkt            '(prologos.data.nat)
   'test-foreign-block.rkt      '(prologos.data.nat)
   'test-pipe-compose.rkt       '(prologos.data.nat prologos.data.list)
   'test-transducer.rkt         '(prologos.data.nat prologos.data.list prologos.data.lseq
                                  prologos.data.transducer)
   'test-higher-rank.rkt        '(prologos.data.nat prologos.data.list)
   'test-varargs.rkt            '(prologos.data.nat prologos.data.list)
   'test-sexp-reader-parity.rkt '(prologos.data.nat prologos.data.list)
   'test-introspection.rkt      '(prologos.data.datum)
   'test-quote.rkt              '(prologos.data.datum)
   'test-hkt-kind.rkt           '(prologos.data.nat prologos.data.option prologos.data.list)
   'test-match-builtins.rkt     '(prologos.data.nat)
   'test-list-literals.rkt      '(prologos.data.nat prologos.data.list)
   'test-core-prelude.rkt       '(prologos.data.nat)
   'test-auto-implicits.rkt     '(prologos.data.nat)
   'test-sprint10.rkt           '(prologos.data.nat prologos.data.bool)
   'test-surface-defmacro.rkt   '(prologos.data.nat)
   'test-where-parsing.rkt      '(prologos.data.nat prologos.data.bool prologos.core.eq-trait)
   'test-error-messages.rkt     '(prologos.data.nat prologos.core.eq-trait)
   'test-constraint-postponement.rkt '(prologos.data.nat prologos.core)
   'test-mult-inference.rkt     '(prologos.data.nat)
   'test-universe-level-inference.rkt '(prologos.data.nat prologos.core)
   'test-unit-type.rkt          '(prologos.data.nat)
   'test-qtt-pipeline.rkt       '(prologos.data.nat)
   'test-implicit-inference.rkt  '(prologos.data.nat)))

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

(define (compute-affected-tests changed-files)
  (define affected-tests (mutable-seteq))

  ;; Classify changed files
  (define changed-sources (mutable-seteq))
  (define changed-prologos-mods (mutable-seteq))

  (for ([cf (in-list changed-files)])
    (cond
      [(changed-source? cf)
       (set-add! changed-sources (changed-source-name cf))]
      [(changed-test? cf)
       ;; Always re-run a changed test
       (set-add! affected-tests (changed-test-name cf))]
      [(changed-prologos? cf)
       (set-add! changed-prologos-mods (changed-prologos-name cf))]
      [(changed-example? cf)
       ;; Map example → test files
       (define tests (hash-ref example-test-map (changed-example-name cf) '()))
       (for ([t (in-list tests)])
         (set-add! affected-tests t))]))

  ;; Step 1: Expand source changes to transitive dependents
  (define source-closure
    (if (set-empty? changed-sources)
        (seteq)
        (transitive-closure source-reverse-deps changed-sources)))

  ;; Step 2: Map source closure to affected tests
  (for ([(test-name td) (in-hash test-deps)])
    (define test-mods (test-dep-source-modules td))
    (when (for/or ([m (in-list test-mods)])
            (set-member? source-closure m))
      (set-add! affected-tests test-name)))

  ;; Step 3: Expand .prologos changes to transitive dependents
  (define prologos-closure
    (if (set-empty? changed-prologos-mods)
        (seteq)
        (transitive-closure prologos-reverse-deps changed-prologos-mods)))

  ;; Step 4: Map .prologos closure to affected tests
  (unless (set-empty? prologos-closure)
    (for ([(test-name prologos-mods) (in-hash test-prologos-deps)])
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
