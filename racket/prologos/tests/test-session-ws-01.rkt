#lang racket/base

;;;
;;; WS-2: Session declaration WS integration tests
;;; Validates the full path: WS reader → preparse → parser → elaborator
;;; for session type declarations written in .prologos WS syntax.
;;;

(require rackunit
         racket/list
         racket/string
         "../driver.rkt"
         "../errors.rkt"
         "../sessions.rkt"
         "../macros.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt")

;; Helper: run WS-mode string through the full pipeline, return last result
(define (run-ws s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (define results (process-string-ws s))
    (if (list? results)
        (last results)
        results)))

;; Helper: run WS-mode string and return the session-entry from the registry
(define (run-ws-get-session s name)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (process-string-ws s)
    (lookup-session name)))

;; ========================================
;; WS-2a: Basic session declarations
;; ========================================

(test-case "ws-session: basic Send/End"
  (check-equal? (run-ws "session Greeting\n  ! String\n  end\n")
                "session Greeting defined."))

(test-case "ws-session: Send/End registry entry"
  (define entry (run-ws-get-session "session Greeting\n  ! String\n  end\n" 'Greeting))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  (check-true (sess-send? st))
  (check-true (sess-end? (sess-send-cont st))))

(test-case "ws-session: multi-step Send/Recv/End"
  (define entry (run-ws-get-session
    "session Echo\n  ! String\n  ? String\n  end\n" 'Echo))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  ;; Send -> Recv -> End
  (check-true (sess-send? st))
  (define recv (sess-send-cont st))
  (check-true (sess-recv? recv))
  (check-true (sess-end? (sess-recv-cont recv))))

(test-case "ws-session: Recv/End"
  (check-equal? (run-ws "session Listener\n  ? Nat\n  end\n")
                "session Listener defined."))

;; ========================================
;; WS-2b: Choice and Offer
;; ========================================

(test-case "ws-session: Choice with branches"
  (define entry (run-ws-get-session
    (string-append
      "session Counter\n"
      "  rec\n"
      "    +>\n"
      "      | :inc -> ! Nat -> rec\n"
      "      | :done -> end\n")
    'Counter))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  ;; Top-level is Mu (rec)
  (check-true (sess-mu? st))
  (define body (sess-mu-body st))
  ;; Body is Choice
  (check-true (sess-choice? body))
  (define branches (sess-choice-branches body))
  (check-equal? (length branches) 2)
  ;; :inc branch has Send inside
  (define inc-branch (cdr (assq ':inc branches)))
  (check-true (sess-send? inc-branch))
  ;; :done branch is End
  (define done-branch (cdr (assq ':done branches)))
  (check-true (sess-end? done-branch)))

(test-case "ws-session: Offer with branches"
  (define entry (run-ws-get-session
    (string-append
      "session Server\n"
      "  &>\n"
      "    | :get -> ! String -> end\n"
      "    | :put -> ? String -> end\n")
    'Server))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  ;; Top-level is Offer
  (check-true (sess-offer? st))
  (define branches (sess-offer-branches st))
  (check-equal? (length branches) 2)
  ;; :get branch sends String then ends
  (define get-branch (cdr (assq ':get branches)))
  (check-true (sess-send? get-branch))
  (check-true (sess-end? (sess-send-cont get-branch)))
  ;; :put branch receives String then ends
  (define put-branch (cdr (assq ':put branches)))
  (check-true (sess-recv? put-branch))
  (check-true (sess-end? (sess-recv-cont put-branch))))

;; ========================================
;; WS-2c: Dependent send/recv
;; ========================================

(test-case "ws-session: dependent send"
  (define entry (run-ws-get-session
    "session DepSend\n  !: n Nat\n  end\n" 'DepSend))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  ;; Should be DSend
  (check-true (sess-dsend? st))
  (check-true (sess-end? (sess-dsend-cont st))))

(test-case "ws-session: dependent recv"
  (define entry (run-ws-get-session
    "session DepRecv\n  ?: x Bool\n  end\n" 'DepRecv))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  ;; Should be DRecv
  (check-true (sess-drecv? st)))

;; ========================================
;; WS-2d: Named recursion
;; ========================================

(test-case "ws-session: named recursion"
  (define entry (run-ws-get-session
    "session Loop\n  rec Again\n    ! Nat\n    Again\n" 'Loop))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  ;; Top-level is Mu with name Again
  (check-true (sess-mu? st)))

;; ========================================
;; WS-2e: Throws metadata
;; ========================================

(test-case "ws-session: throws metadata defines"
  (check-equal? (run-ws
    "session FileAccess :throws String\n  ! String\n  ? String\n  end\n")
    "session FileAccess defined."))

(test-case "ws-session: throws wraps protocol steps"
  (define entry (run-ws-get-session
    "session FileAccess :throws String\n  ! String\n  ? String\n  end\n"
    'FileAccess))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  ;; Top-level should be sess-offer (wrapping first Send in :ok/:error)
  (check-true (sess-offer? st))
  (define ok (cdr (assq ':ok (sess-offer-branches st))))
  (check-true (sess-send? ok)))

;; ========================================
;; WS-2f: Bare End
;; ========================================

(test-case "ws-session: bare End session"
  (check-equal? (run-ws "session Done\n  end\n")
                "session Done defined."))

(test-case "ws-session: bare End produces sess-end"
  (define entry (run-ws-get-session "session Done\n  end\n" 'Done))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  (check-true (sess-end? st)))
