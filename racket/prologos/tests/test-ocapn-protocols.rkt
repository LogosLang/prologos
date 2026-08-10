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
         "../syntax.rkt"
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
  (parameterize ([current-file-module-network-ref (make-module-network)]
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

;; Phase 53.d: protocols that can produce a broken-promise outcome
;; are wrapped in `:throws SyrupValue`, which makes the top-level
;; shape `sess-offer((:ok step)(:error Send SyrupValue End))`. The
;; `unwrap-ok` helper steps past the :throws wrap to inspect the
;; underlying protocol structure.

(define (unwrap-ok s)
  ;; If s is sess-offer with :ok + :error branches, return the :ok
  ;; step. Otherwise return s unchanged.
  (cond
    [(and (sess-offer? s)
          (assq ':ok (sess-offer-branches s)))
     (cdr (assq ':ok (sess-offer-branches s)))]
    [else s]))

(test-case "QuestionAnswer: :throws wrapping + ! ? end shape (Phase 53.d)"
  (define s (session-type 'QuestionAnswer))
  ;; Top-level should be the :throws wrapper.
  (check-true (sess-offer? s) "QuestionAnswer top-level is :throws Offer")
  (define inner (unwrap-ok s))
  ;; Under :ok, the original ! step. EVERY step is also wrapped, so
  ;; unwrap again at each level.
  (check-true (sess-send? inner))
  (define after-send (unwrap-ok (sess-send-cont inner)))
  (check-true (sess-recv? after-send))
  (check-true (sess-end? (sess-recv-cont after-send))))

(test-case "PipelinedQuestion: :throws wrap + Send-Mu(Choice) shape (Phase 53.d)"
  (define s (session-type 'PipelinedQuestion))
  (check-true (sess-offer? s) "PipelinedQuestion top-level is :throws Offer")
  (define inner (unwrap-ok s))
  (check-true (sess-send? inner) "under :ok, starts with !")
  (define rec-body (sess-send-cont inner))
  (check-true (sess-mu? rec-body) "after the initial !, body is mu(...)")
  (check-true (sess-choice? (sess-mu-body rec-body))
              "mu's body is a Choice (we drive the pipelining loop)"))

(test-case "PipelinedQuestion: choice has :pipeline and :await branches (Phase 53.d)"
  (define s (session-type 'PipelinedQuestion))
  (define inner (unwrap-ok s))
  (define choice (sess-mu-body (sess-send-cont inner)))
  (define branches (sess-choice-branches choice))
  (check-true (and (assq ':pipeline branches) #t) "Choice has :pipeline branch")
  (check-true (and (assq ':await branches) #t) "Choice has :await branch")
  ;; :pipeline step is itself :throws-wrapped (every step gets wrapped).
  (define p-step (unwrap-ok (cdr (assq ':pipeline branches))))
  (check-true (sess-send? p-step))
  (check-true (sess-svar? (sess-send-cont p-step)))
  ;; :await step also :throws-wrapped.
  (define a-step (unwrap-ok (cdr (assq ':await branches))))
  (check-true (sess-recv? a-step))
  (check-true (sess-end? (sess-recv-cont a-step))))

(test-case "ListenProtocol: :throws wrap + ! ? end shape (Phase 53.d)"
  (define s (session-type 'ListenProtocol))
  (check-true (sess-offer? s) "ListenProtocol top-level is :throws Offer")
  (define inner (unwrap-ok s))
  (check-true (sess-send? inner))
  (define after-send (unwrap-ok (sess-send-cont inner)))
  (check-true (sess-recv? after-send))
  (check-true (sess-end? (sess-recv-cont after-send))))

(test-case "GcExport: ! end (one-way)"
  (define s (session-type 'GcExport))
  (check-true (sess-send? s))
  (check-true (sess-end? (sess-send-cont s))))

(test-case "GiftDeposit: ! end (one-way)"
  (define s (session-type 'GiftDeposit))
  (check-true (sess-send? s))
  (check-true (sess-end? (sess-send-cont s))))

(test-case "GiftWithdraw: :throws wrap + ! ? end (Phase 53.d)"
  (define s (session-type 'GiftWithdraw))
  (check-true (sess-offer? s) "GiftWithdraw top-level is :throws Offer")
  (define inner (unwrap-ok s))
  (check-true (sess-send? inner))
  (define after-send (unwrap-ok (sess-send-cont inner)))
  (check-true (sess-recv? after-send))
  (check-true (sess-end? (sess-recv-cont after-send))))

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

(test-case "PipelinedQuestion peer view: dual of :throws-wrapped (Phase 53.d)"
  ;; PipelinedQuestion is :throws-wrapped. Its dual flips the top
  ;; Offer to a Choice (the peer's side of the :ok/:error split).
  (define s (dual (session-type 'PipelinedQuestion)))
  (check-true (sess-choice? s) "peer-view top is Choice (dual of :throws Offer)")
  ;; Under :ok (the peer's :ok branch == OUR :ok wrap dualled), the
  ;; original peer-view shape: Recv-Mu(Offer).
  (define ok-branch (assq ':ok (sess-choice-branches s)))
  (check-not-false ok-branch)
  (define inner (cdr ok-branch))
  (check-true (sess-recv? inner))
  (define rec-body (sess-recv-cont inner))
  (check-true (sess-mu? rec-body))
  (check-true (sess-offer? (sess-mu-body rec-body))
              "peer offers what we choose"))

;; ========================================
;; Group 5: payload type refinement (Phase 53.a)
;; ========================================
;;
;; Phase 53 used `String` as the payload (the wire-byte
;; representation). Phase 53.a refines to `CapTPOp` (the semantic
;; type from prologos::ocapn::message). These tests verify the
;; refinement landed: each session's Send / Recv payload should now
;; be the CapTPOp type, not String.

(test-case "Handshake payload is CapTPOp (Phase 53.a)"
  ;; Handshake: ! CapTPOp -> ? CapTPOp -> end
  ;; Check that the sent-type and recv-type are NOT expr-String.
  (define s (session-type 'Handshake))
  (define send-ty (sess-send-type s))
  (define recv-ty (sess-recv-type (sess-send-cont s)))
  (check-false (expr-String? send-ty)
               (format "expected CapTPOp payload (not String); got ~v" send-ty))
  (check-false (expr-String? recv-ty)
               (format "expected CapTPOp recv payload (not String); got ~v" recv-ty)))

(test-case "QuestionAnswer payload is CapTPOp (Phase 53.a)"
  (define s (unwrap-ok (session-type 'QuestionAnswer)))
  (define send-ty (sess-send-type s))
  (check-false (expr-String? send-ty)
               (format "expected CapTPOp payload; got ~v" send-ty)))

(test-case "ListenProtocol payload is CapTPOp (Phase 53.a)"
  (define s (unwrap-ok (session-type 'ListenProtocol)))
  (define send-ty (sess-send-type s))
  (check-false (expr-String? send-ty)
               (format "expected CapTPOp payload; got ~v" send-ty)))

(test-case "GcExport payload is CapTPOp (Phase 53.a)"
  (define s (session-type 'GcExport))
  (check-false (expr-String? (sess-send-type s))
               (format "expected CapTPOp payload; got ~v" (sess-send-type s))))

(test-case "GiftWithdraw payload is CapTPOp (Phase 53.a)"
  (define s (unwrap-ok (session-type 'GiftWithdraw)))
  (check-false (expr-String? (sess-send-type s))
               (format "expected CapTPOp payload; got ~v" (sess-send-type s))))

(test-case "GiftDeposit payload is CapTPOp (Phase 53.a)"
  (define s (session-type 'GiftDeposit))
  (check-false (expr-String? (sess-send-type s))
               (format "expected CapTPOp payload; got ~v" (sess-send-type s))))

;; ========================================
;; Group 6: :throws-wrapped protocols carry SyrupValue error type (Phase 53.d)
;; ========================================
;;
;; QuestionAnswer / PipelinedQuestion / ListenProtocol /
;; GiftWithdraw all carry an error path via `:throws SyrupValue`.
;; Each protocol step wraps to `Offer((:ok step)(:error Send
;; SyrupValue End))`. These tests verify the :error branch's
;; payload type is the expected error type, not something else.

(define (error-payload-type s)
  ;; s is sess-offer with :ok + :error. Extract :error → sess-send
  ;; whose type field is the error type.
  (define branches (sess-offer-branches s))
  (define err-step (cdr (assq ':error branches)))
  (sess-send-type err-step))

(test-case "QuestionAnswer :error branch carries SyrupValue (Phase 53.d)"
  (define s (session-type 'QuestionAnswer))
  (define err-ty (error-payload-type s))
  (check-false (expr-String? err-ty)
               (format "expected SyrupValue (not String) error payload; got ~v" err-ty)))

(test-case "PipelinedQuestion :error branch carries SyrupValue (Phase 53.d)"
  (define s (session-type 'PipelinedQuestion))
  (check-true (sess-offer? s))
  (define err-ty (error-payload-type s))
  (check-false (expr-String? err-ty)))

(test-case "ListenProtocol :error branch carries SyrupValue (Phase 53.d)"
  (define s (session-type 'ListenProtocol))
  (check-true (sess-offer? s))
  (define err-ty (error-payload-type s))
  (check-false (expr-String? err-ty)))

(test-case "GiftWithdraw :error branch carries SyrupValue (Phase 53.d)"
  (define s (session-type 'GiftWithdraw))
  (check-true (sess-offer? s))
  (define err-ty (error-payload-type s))
  (check-false (expr-String? err-ty)))

(test-case "non-throws protocols stay non-Offer at top (Phase 53.d regression)"
  ;; Sanity: protocols WITHOUT :throws keep their original top-level
  ;; shape. Phase 53.d should NOT have added :throws to handshake,
  ;; gc-export, gift-deposit, or captp-session.
  (check-true (sess-send? (session-type 'Handshake)))
  (check-true (sess-send? (session-type 'GcExport)))
  (check-true (sess-send? (session-type 'GiftDeposit)))
  (check-true (sess-recv? (session-type 'CapTPSession))))
