#lang racket/base
;; DEFERRED 160 probe: does a `spec` declared in one namespace apply to a same-named `defn`
;; in ANOTHER namespace processed later in the same Racket process?
;; Run: timeout -k 10 120 racket probe160-spec-leak.rkt <checkout>/racket/prologos
(require racket/runtime-path)
(define root (vector-ref (current-command-line-arguments) 0))
(define-values (run-ns-last run-ns-ws-last prologos-error? prologos-error-message)
  (let ([ts (string->path (string-append root "/tests/test-support.rkt"))]
        [er (string->path (string-append root "/errors.rkt"))])
    (values (dynamic-require ts 'run-ns-last)
            (dynamic-require ts 'run-ns-ws-last)
            (dynamic-require er 'prologos-error?)
            (dynamic-require er 'prologos-error-message))))
(define (show label r)
  (printf "~a -> ~a\n" label
          (if (prologos-error? r)
              (let ([m (prologos-error-message r)]) (substring m 0 (min 90 (string-length m))))
              (format "ok: ~v" r))))
(define victim "ns t\ndefn ok2\n  | zero -> 1\n  | suc _ -> 2\n")
(define victim-other "ns t\ndefn okq\n  | zero -> 1\n  | suc _ -> 2\n")
(show "1. victim, fresh process          " (run-ns-ws-last victim))
(show "2. spec ok2 Nat -> Nat in ns test " (run-ns-last "(ns test)\n(spec ok2 Nat -> Nat)\n(defn ok2 [v] (match v (zero -> 1N) (n -> 2N)))"))
(show "3. victim again, ns t             " (run-ns-ws-last victim))
(show "4. control: same body, other name " (run-ns-ws-last victim-other))
