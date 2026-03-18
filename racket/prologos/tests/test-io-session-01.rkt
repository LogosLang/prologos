#lang racket/base

;;;
;;; test-io-session-01.rkt — IO session protocol definition tests
;;;
;;; Phase IO-E1: Tests for FileRead, FileWrite, FileAppend, FileRW
;;; session protocols from lib/prologos/core/io-protocols.prologos.
;;;
;;; Pattern: Shared fixture with process-string, session registry access.
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt"
         "../sessions.rkt")

;; ========================================
;; Shared Fixture (io-protocols module loaded once)
;; ========================================

(define shared-preamble
  "(ns test-io-protocols)
(imports (prologos::core::io-protocols :refer-all))")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-session-reg)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-session-registry))))

;; ========================================
;; Group 1: Protocol Parsing
;; ========================================

(test-case "FileRead: parses as session type"
  (define entry (hash-ref shared-session-reg 'FileRead #f))
  (check-true (session-entry? entry)
              "FileRead should be registered in session registry")
  (define st (session-entry-session-type entry))
  ;; Top level should be Mu (rec wrapping)
  (check-true (sess-mu? st)
              "FileRead should be recursive (Mu)"))

(test-case "FileWrite: parses as session type"
  (define entry (hash-ref shared-session-reg 'FileWrite #f))
  (check-true (session-entry? entry)
              "FileWrite should be registered in session registry")
  (define st (session-entry-session-type entry))
  (check-true (sess-mu? st)
              "FileWrite should be recursive (Mu)"))

(test-case "FileAppend: parses as session type"
  (define entry (hash-ref shared-session-reg 'FileAppend #f))
  (check-true (session-entry? entry)
              "FileAppend should be registered in session registry")
  (define st (session-entry-session-type entry))
  (check-true (sess-mu? st)
              "FileAppend should be recursive (Mu)"))

(test-case "FileRW: parses as session type"
  (define entry (hash-ref shared-session-reg 'FileRW #f))
  (check-true (session-entry? entry)
              "FileRW should be registered in session registry")
  (define st (session-entry-session-type entry))
  (check-true (sess-mu? st)
              "FileRW should be recursive (Mu)"))

;; ========================================
;; Group 2: Session Structure
;; ========================================

(test-case "FileRead: body is Choice with 3 branches"
  (define st (session-entry-session-type (hash-ref shared-session-reg 'FileRead)))
  (define body (sess-mu-body st))
  (check-true (sess-choice? body)
              "FileRead body should be Choice (internal choice)")
  (define branches (sess-choice-branches body))
  (check-equal? (length branches) 3
                "FileRead should have 3 branches: :read-all, :read-line, :close"))

(test-case "FileRead: :read-all branch is Recv String then End"
  (define st (session-entry-session-type (hash-ref shared-session-reg 'FileRead)))
  (define body (sess-mu-body st))
  (define branches (sess-choice-branches body))
  (define read-all (cdr (assq ':read-all branches)))
  (check-true (sess-recv? read-all)
              ":read-all branch should start with Recv")
  (check-true (sess-end? (sess-recv-cont read-all))
              ":read-all continuation should be End"))

(test-case "FileRead: :read-line branch is Recv String then recurse"
  (define st (session-entry-session-type (hash-ref shared-session-reg 'FileRead)))
  (define body (sess-mu-body st))
  (define branches (sess-choice-branches body))
  (define read-line (cdr (assq ':read-line branches)))
  (check-true (sess-recv? read-line)
              ":read-line branch should start with Recv")
  ;; The continuation should be sess-svar (de Bruijn index 0 = self-reference to Mu)
  (check-true (sess-svar? (sess-recv-cont read-line))
              ":read-line continuation should be a session variable (recursion)")
  (check-equal? (sess-svar-index (sess-recv-cont read-line)) 0
                "Session variable index should be 0 (self-reference)"))

(test-case "FileRead: :close branch is End"
  (define st (session-entry-session-type (hash-ref shared-session-reg 'FileRead)))
  (define body (sess-mu-body st))
  (define branches (sess-choice-branches body))
  (define close-branch (cdr (assq ':close branches)))
  (check-true (sess-end? close-branch)
              ":close branch should be End"))

;; ========================================
;; Group 3: Duality
;; ========================================

(test-case "FileRead: dual has Offer"
  (define st (session-entry-session-type (hash-ref shared-session-reg 'FileRead)))
  (define d (dual st))
  ;; Dual of Mu is Mu
  (check-true (sess-mu? d)
              "Dual of Mu should be Mu")
  ;; Body: dual of Choice is Offer
  (define body (sess-mu-body d))
  (check-true (sess-offer? body)
              "Dual of Choice should be Offer"))

(test-case "FileRead dual: :read-all branch is Send then End"
  (define st (session-entry-session-type (hash-ref shared-session-reg 'FileRead)))
  (define d (dual st))
  (define body (sess-mu-body d))
  (define branches (sess-offer-branches body))
  (define read-all (cdr (assq ':read-all branches)))
  ;; Dual of Recv is Send
  (check-true (sess-send? read-all)
              "Dual of Recv should be Send")
  (check-true (sess-end? (sess-send-cont read-all))
              "Dual continuation should be End"))

(test-case "FileWrite: dual :write branch is Recv"
  (define st (session-entry-session-type (hash-ref shared-session-reg 'FileWrite)))
  (define d (dual st))
  (define body (sess-mu-body d))
  (check-true (sess-offer? body)
              "Dual of FileWrite Choice should be Offer")
  (define branches (sess-offer-branches body))
  (define write-branch (cdr (assq ':write branches)))
  ;; Dual of Send is Recv
  (check-true (sess-recv? write-branch)
              "Dual of Send (write) should be Recv"))
