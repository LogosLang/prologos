#lang racket/base
;; DEFERRED 160, the open question: does the DRIVER (not test-support) leak a `spec` from one program
;; into a same-named `defn` of a LATER program in the same Racket process — the LSP / run-file shape?
;; Every program goes through `process-file` exactly as tools/run-file.rkt:55 and lsp/server.rkt:561
;; call it (no binding of current-persistent-registry-net-box around it).
;; Run: timeout -k 10 300 racket probe160-driver.rkt <checkout>/racket/prologos
(require racket/file racket/string racket/port)
(define root (vector-ref (current-command-line-arguments) 0))
(define (dr mod sym) (dynamic-require (string->path (string-append root "/" mod)) sym))
(define process-file (dr "driver.rkt" 'process-file))
(define prologos-error? (dr "errors.rkt" 'prologos-error?))
(define prologos-error-message (dr "errors.rkt" 'prologos-error-message))
(define dir (make-temporary-file "probe160-~a" 'directory))
(define (run label name src)
  (define p (build-path dir name))
  (call-with-output-file p #:exists 'truncate (λ (o) (display src o)))
  (define rs (parameterize ([current-output-port (open-output-nowhere)]
                            [current-error-port (open-output-nowhere)])
               (process-file p #:evaluate? #f)))
  (define errs (filter prologos-error? rs))
  (printf "~a -> ~a\n" label
          (if (null? errs)
              (format "ok (~a results; last ~a)" (length rs)
                      (let ([s (format "~a" (if (null? rs) "" (car (reverse rs))))]) (substring s 0 (min 50 (string-length s)))))
              (string-join (for/list ([e errs]) (let ([m (prologos-error-message e)]) (substring m 0 (min 95 (string-length m))))) " | ")))
  (null? errs))
(define victim "ns t\ndefn ok2\n  | zero -> 1\n  | suc _ -> 2\n")
(define control "ns t\ndefn okq\n  | zero -> 1\n  | suc _ -> 2\n")
(define spec-prog "ns test\nspec ok2 Nat -> Nat\ndefn ok2\n  | zero -> 1N\n  | suc _ -> 2N\n")
(define a (run "1. victim, first program in the process " "v1.prologos" victim))
(define b (run "2. spec ok2 Nat -> Nat in ns test        " "s.prologos" spec-prog))
(define c (run "3. victim again (ns t), same process     " "v2.prologos" victim))
(define d (run "4. control okq (ns t)                    " "c.prologos" control))
(printf "VERDICT: ~a\n"
        (cond [(not (and a b d)) "INCONCLUSIVE (a precondition program failed)"]
              [c "NO driver-level leak: the victim still defines after the spec program"]
              [else "DRIVER-LEVEL LEAK: the spec from ns test reached ns t's defn"]))
(delete-directory/files dir)
