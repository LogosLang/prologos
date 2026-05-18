#lang racket/base

;;;
;;; test-ocapn-protocols.rkt — Phase 53: OCapN protocols as session types
;;;
;;; Verifies that the session-type specifications in
;;; `prologos::ocapn::protocols` are well-formed:
;;;
;;;   1. All 8 sessions load successfully through the WS-mode
;;;      `session NAME body` form (via process-file).
;;;   2. Each session's dual round-trips: dual (dual S) = S. This
;;;      catches asymmetry bugs in our session-type writing.
;;;   3. Structural sanity per protocol (e.g., CapTPSession is a
;;;      Recv-Send-Mu(Offer) shape; PipelinedQuestion is Send-Mu(Choice)).
;;;

(require rackunit
         racket/list
         racket/runtime-path
         "test-support.rkt"
         "../driver.rkt"
         "../errors.rkt"
         "../sessions.rkt"
         "../macros.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt"
         "../multi-dispatch.rkt")

(define-runtime-path PROTOCOLS-FILE
  "../lib/prologos/ocapn/protocols.prologos")

;; ========================================
;; Setup: load protocols.prologos once
;; ========================================

(define-values (protocols-registry)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)]
                 [current-session-registry (hasheq)])
    (install-module-loader!)
    (process-file (path->string PROTOCOLS-FILE))
    (current-session-registry)))

(define (lookup name)
  (hash-ref protocols-registry name #f))

;; ========================================
;; Group 1: all 8 sessions load
;; ========================================

(test-case "protocols: all 8 session names registered"
  (for ([name '(Handshake QuestionAnswer PipelinedQuestion ListenProtocol
                GcExport GiftWithdraw GiftDeposit CapTPSession)])
    (check-true (and (lookup name) #t)
                (format "expected session ~a to be registered" name))))

(test-case "protocols: each entry is a session-entry struct"
  (for ([name '(Handshake QuestionAnswer PipelinedQuestion ListenProtocol
                GcExport GiftWithdraw GiftDeposit CapTPSession)])
    (check-true (session-entry? (lookup name))
                (format "expected session-entry for ~a; got ~v" name (lookup name)))))

;; ========================================
;; Group 2: dual round-trip (dual ∘ dual = id)
;; ========================================

(define (session-type name)
  (session-entry-session-type (lookup name)))

(test-case "protocols: dual round-trip for Handshake"
  (define s (session-type 'Handshake))
  (check-equal? (dual (dual s)) s))

(test-case "protocols: dual round-trip for QuestionAnswer"
  (define s (session-type 'QuestionAnswer))
  (check-equal? (dual (dual s)) s))

(test-case "protocols: dual round-trip for PipelinedQuestion"
  (define s (session-type 'PipelinedQuestion))
  (check-equal? (dual (dual s)) s))

(test-case "protocols: dual round-trip for ListenProtocol"
  (define s (session-type 'ListenProtocol))
  (check-equal? (dual (dual s)) s))

(test-case "protocols: dual round-trip for GcExport"
  (define s (session-type 'GcExport))
  (check-equal? (dual (dual s)) s))

(test-case "protocols: dual round-trip for GiftWithdraw"
  (define s (session-type 'GiftWithdraw))
  (check-equal? (dual (dual s)) s))

(test-case "protocols: dual round-trip for GiftDeposit"
  (define s (session-type 'GiftDeposit))
  (check-equal? (dual (dual s)) s))

(test-case "protocols: dual round-trip for CapTPSession"
  (define s (session-type 'CapTPSession))
  (check-equal? (dual (dual s)) s))

;; ========================================
;; Group 3: structural sanity
;; ========================================

(test-case "Handshake: ! ? end shape"
  (define s (session-type 'Handshake))
  (check-true (sess-send? s) "Handshake starts with Send")
  (define s2 (sess-send-cont s))
  (check-true (sess-recv? s2) "Handshake then Recv")
  (check-true (sess-end? (sess-recv-cont s2)) "Handshake ends after Recv"))

(test-case "Handshake: dual is ? ! end (peer's view)"
  (define s (session-type 'Handshake))
  (define peer (dual s))
  (check-true (sess-recv? peer) "peer-side starts with Recv")
  (check-true (sess-send? (sess-recv-cont peer)) "peer-side then Send")
  (check-true (sess-end? (sess-send-cont (sess-recv-cont peer)))))

(test-case "QuestionAnswer: ! ? end shape"
  (define s (session-type 'QuestionAnswer))
  (check-true (sess-send? s))
  (check-true (sess-recv? (sess-send-cont s)))
  (check-true (sess-end? (sess-recv-cont (sess-send-cont s)))))

(test-case "PipelinedQuestion: starts with Send, then Mu(Choice)"
  (define s (session-type 'PipelinedQuestion))
  (check-true (sess-send? s) "PipelinedQuestion starts with !")
  (define rec-body (sess-send-cont s))
  (check-true (sess-mu? rec-body) "after the initial !, body is mu(...)")
  (check-true (sess-choice? (sess-mu-body rec-body))
              "mu's body is a Choice (we drive the pipelining loop)"))

(test-case "PipelinedQuestion: choice has :pipeline and :await branches"
  (define s (session-type 'PipelinedQuestion))
  (define choice (sess-mu-body (sess-send-cont s)))
  (define branches (sess-choice-branches choice))
  (check-true (and (assq ':pipeline branches) #t) "Choice has :pipeline branch")
  (check-true (and (assq ':await branches) #t) "Choice has :await branch")
  ;; :pipeline → Send String SVar(0)
  (define p (cdr (assq ':pipeline branches)))
  (check-true (sess-send? p))
  (check-true (sess-svar? (sess-send-cont p)))
  ;; :await → Recv String End
  (define a (cdr (assq ':await branches)))
  (check-true (sess-recv? a))
  (check-true (sess-end? (sess-recv-cont a))))

(test-case "ListenProtocol: ! ? end shape"
  (define s (session-type 'ListenProtocol))
  (check-true (sess-send? s))
  (check-true (sess-recv? (sess-send-cont s)))
  (check-true (sess-end? (sess-recv-cont (sess-send-cont s)))))

(test-case "GcExport: ! end (one-way)"
  (define s (session-type 'GcExport))
  (check-true (sess-send? s))
  (check-true (sess-end? (sess-send-cont s))))

(test-case "GiftDeposit: ! end (one-way)"
  (define s (session-type 'GiftDeposit))
  (check-true (sess-send? s))
  (check-true (sess-end? (sess-send-cont s))))

(test-case "GiftWithdraw: ! ? end"
  (define s (session-type 'GiftWithdraw))
  (check-true (sess-send? s))
  (check-true (sess-recv? (sess-send-cont s)))
  (check-true (sess-end? (sess-recv-cont (sess-send-cont s)))))

(test-case "CapTPSession: ? ! rec(Offer) shape (responder)"
  (define s (session-type 'CapTPSession))
  (check-true (sess-recv? s) "CapTPSession receives peer's start-session first")
  (define after-recv (sess-recv-cont s))
  (check-true (sess-send? after-recv) "then sends our start-session")
  (define main-loop (sess-send-cont after-recv))
  (check-true (sess-mu? main-loop) "main loop is mu(...)")
  (check-true (sess-offer? (sess-mu-body main-loop))
              "loop body is an Offer (we accept inbound ops)"))

(test-case "CapTPSession: offers all 7 op variants"
  (define s (session-type 'CapTPSession))
  (define offer (sess-mu-body (sess-send-cont (sess-recv-cont s))))
  (define branches (sess-offer-branches offer))
  (for ([label '(:deliver :deliver-to-answer :deliver-only
                 :listen :gc-export :gc-answer :abort)])
    (check-true (and (assq label branches) #t)
                (format "expected CapTPSession to offer ~a; branches: ~v"
                        label (map car branches)))))

(test-case "CapTPSession: only :abort branch ends (others recurse)"
  (define s (session-type 'CapTPSession))
  (define offer (sess-mu-body (sess-send-cont (sess-recv-cont s))))
  (define branches (sess-offer-branches offer))
  ;; :abort: ? String -> end (so cont after recv is sess-end)
  (define abort-step (cdr (assq ':abort branches)))
  (check-true (sess-recv? abort-step))
  (check-true (sess-end? (sess-recv-cont abort-step)))
  ;; :deliver: ? String -> rec (cont after recv is sess-svar 0)
  (define deliver-step (cdr (assq ':deliver branches)))
  (check-true (sess-recv? deliver-step))
  (check-true (sess-svar? (sess-recv-cont deliver-step))
              "non-abort branches recurse via svar"))

;; ========================================
;; Group 4: composition sanity — dual of pipelined-question
;; ========================================
;;
;; Pipelining seen from peer's view: receive deliver, then loop
;; offering :pipeline (Recv) or :await (Send). The dual of
;; an internal choice is an external offer.

(test-case "PipelinedQuestion peer view: Recv-Mu(Offer)"
  (define s (dual (session-type 'PipelinedQuestion)))
  (check-true (sess-recv? s))
  (define rec-body (sess-recv-cont s))
  (check-true (sess-mu? rec-body))
  (check-true (sess-offer? (sess-mu-body rec-body))
              "peer offers what we choose"))
