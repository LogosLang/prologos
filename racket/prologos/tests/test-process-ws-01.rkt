#lang racket/base

;;;
;;; Tests for WS-mode process body desugaring (Phase S2c)
;;; Validates reader tokenization of !/!!/!:/?:, preparse desugaring
;;; of process bodies, and E2E pipeline via process-string.
;;;

(require rackunit
         racket/list
         racket/string
         racket/port
         "../reader.rkt"
         "../macros.rkt"
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../errors.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../sessions.rkt"
         "../processes.rkt"
         "../metavar-store.rkt"
         "../warnings.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Read a string using the Prologos WS reader, return the datum
(define (ws-read s)
  (define in (open-input-string s))
  (prologos-read in))

;; Run with minimal state, return last result string
(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-capability-registry (hasheq)]
                 [current-capability-warnings '()]
                 [current-mult-meta-store (make-hasheq)])
    (define results (process-string s))
    (if (and (list? results) (not (null? results)))
        (last results)
        results)))

;; ========================================
;; Reader: ! tokenization (S2c Step 1)
;; ========================================

(test-case "reader: standalone ! tokenizes as symbol"
  (define d (ws-read "!"))
  ;; Top-level reader wraps in list
  (check-equal? d '(!)))

(test-case "reader: !! tokenizes as symbol"
  (define d (ws-read "!!"))
  (check-equal? d '(!!)))

(test-case "reader: !: tokenizes as symbol"
  (define d (ws-read "!:"))
  (check-equal? d '(!:)))

(test-case "reader: ?: tokenizes as single symbol"
  (define d (ws-read "?:"))
  (check-equal? d '(?:)))

(test-case "reader: ? alone still works"
  (define d (ws-read "?"))
  (check-equal? d '(?)))

(test-case "reader: self ! x tokenizes as 3 symbols"
  (define d (ws-read "self ! x"))
  (check-equal? d '(self ! x)))

(test-case "reader: name := ch ? tokenizes correctly"
  (define d (ws-read "name := ch ?"))
  (check-equal? d '(name := ch ?)))

(test-case "reader: ! inside identifier still works"
  ;; zero! as a single identifier (! is ident-continue)
  (define d (ws-read "zero!"))
  (check-equal? d '(zero!)))

;; ========================================
;; Preparse: desugar-defproc-ws (S2c Step 2)
;; ========================================

(test-case "preparse: send + stop → proc-send + proc-stop"
  (define result
    (desugar-defproc-ws '(defproc foo : S (self ! "hello") stop)))
  (check-equal? result
    '(defproc foo : S (proc-send self "hello" (proc-stop)))))

(test-case "preparse: recv + stop → proc-recv + proc-stop"
  (define result
    (desugar-defproc-ws '(defproc foo : S (name := self ?) stop)))
  (check-equal? result
    '(defproc foo : S (proc-recv self name (proc-stop)))))

(test-case "preparse: send + recv chain right-nests"
  (define result
    (desugar-defproc-ws '(defproc foo : S (self ! "hello") (name := self ?) stop)))
  (check-equal? result
    '(defproc foo : S (proc-send self "hello" (proc-recv self name (proc-stop))))))

(test-case "preparse: select + stop"
  (define result
    (desugar-defproc-ws '(defproc foo : S (select self :done) stop)))
  (check-equal? result
    '(defproc foo : S (proc-sel self :done (proc-stop)))))

(test-case "preparse: offer with branches"
  (define result
    (desugar-defproc-ws '(defproc foo : S
                           (offer self ($pipe :a stop) ($pipe :b (self ! "x") stop)))))
  (check-equal? result
    '(defproc foo : S (proc-case self ((:a (proc-stop))
                                       (:b (proc-send self "x" (proc-stop))))))))

(test-case "preparse: link passes through"
  (define result
    (desugar-defproc-ws '(defproc foo : S (link c1 c2))))
  (check-equal? result
    '(defproc foo : S (proc-link c1 c2))))

(test-case "preparse: rec produces proc-rec"
  (define result
    (desugar-defproc-ws '(defproc foo : S (self ! "x") rec)))
  (check-equal? result
    '(defproc foo : S (proc-send self "x" (proc-rec)))))

(test-case "preparse: with capability binders in header"
  (define result
    (desugar-defproc-ws '(defproc foo : S ($brace-params net :0 NetCap) (self ! "x") stop)))
  (check-equal? result
    '(defproc foo : S ($brace-params net :0 NetCap) (proc-send self "x" (proc-stop)))))

(test-case "preparse: no session type — body only"
  (define result
    (desugar-defproc-ws '(defproc foo (self ! "x") stop)))
  (check-equal? result
    '(defproc foo (proc-send self "x" (proc-stop)))))

(test-case "preparse: sexp form passes through unchanged"
  (define result
    (desugar-defproc-ws '(defproc foo : S (proc-send self "x" (proc-stop)))))
  (check-equal? result
    '(defproc foo : S (proc-send self "x" (proc-stop)))))

(test-case "preparse: anonymous proc desugars"
  (define result
    (desugar-proc-ws '(proc : S (self ! "hi") stop)))
  (check-equal? result
    '(proc : S (proc-send self "hi" (proc-stop)))))

(test-case "preparse: dependent send !: desugars to proc-send"
  (define result
    (desugar-defproc-ws '(defproc foo : S (self !: val) stop)))
  (check-equal? result
    '(defproc foo : S (proc-send self val (proc-stop)))))

(test-case "preparse: dependent recv ?: desugars to proc-recv"
  (define result
    (desugar-defproc-ws '(defproc foo : S (name := self ?:) stop)))
  (check-equal? result
    '(defproc foo : S (proc-recv self name (proc-stop)))))

;; ========================================
;; E2E: WS-desugared forms through pipeline
;; ========================================

(test-case "e2e: defproc with desugared send/stop type-checks"
  (define result
    (run (string-append
          "(session Greeting (Send String End))\n"
          "(defproc greeter : Greeting (self ! \"hello\") stop)")))
  (check-true (string? result))
  (check-true (string-contains? result "type-checked")))

(test-case "e2e: defproc without session type defines"
  (define result
    (run "(defproc handler (self ! \"hello\") stop)"))
  (check-true (string? result))
  (check-true (string-contains? result "defined")))

(test-case "e2e: defproc with send + recv chain"
  (define result
    (run (string-append
          "(session Echo (Send String (Recv String End)))\n"
          "(defproc echo-client : Echo (self ! \"hello\") (reply := self ?) stop)")))
  (check-true (string? result))
  (check-true (string-contains? result "type-checked")))
