#lang racket/base

;;; test-pnet-vec-fin.rkt — the Vec/Fin family survives a .pnet round trip.
;;;
;;; QTT P5 residual 2: the nine Vec/Fin nodes had ZERO `pnet-serialize`
;;; registrations. That was harmless only while no cached module contained one,
;;; and P5 is exactly what changed the odds — it made Vec/Fin defs pass the QTT
;;; gate for the first time, so they can now reach a library body and be cached.
;;;
;;; The failure a missing registration produces is the one `pipeline.md` item 6
;;; documents, and it is MISLEADING rather than loud: an unregistered tag does
;;; not error at cache read. The reader's unknown-tag fallback returns a raw
;;; VECTOR, which then fails the first struct `match` to touch it — arbitrarily
;;; far away, with an error that PRINTS like the real struct
;;; (`#(struct:expr-vcons …)`).
;;;
;;; So the assertion is `struct?` FIRST and `equal?` second. Checking only
;;; `equal?` would pass a vector against a vector if both sides degraded, and
;;; checking only that no exception was raised would pass with the bug in
;;; place, since the read itself never raises.

(require rackunit
         racket/list
         "../syntax.rkt"
         (only-in "../pnet-serialize.rkt"
                  deep-struct->serializable
                  deep-serializable->struct
                  make-tag-constructor-table))

(define (round-trip v) (deep-serializable->struct (deep-struct->serializable v)))

;; One sample per node, with nested Vec/Fin payloads so a failure in a CHILD
;; shows up too — a parent can reconstruct while its unregistered child stays a
;; vector, and that is the harder case to notice.
(define samples
  (list (cons 'expr-Vec    (expr-Vec (expr-Nat) (expr-zero)))
        (cons 'expr-Fin    (expr-Fin (expr-zero)))
        (cons 'expr-vnil   (expr-vnil (expr-Nat)))
        (cons 'expr-vcons  (expr-vcons (expr-Nat) (expr-zero)
                                       (expr-int 7) (expr-vnil (expr-Nat))))
        (cons 'expr-fzero  (expr-fzero (expr-zero)))
        (cons 'expr-fsuc   (expr-fsuc (expr-zero) (expr-fzero (expr-zero))))
        (cons 'expr-vhead  (expr-vhead (expr-Nat) (expr-zero) (expr-vnil (expr-Nat))))
        (cons 'expr-vtail  (expr-vtail (expr-Nat) (expr-zero) (expr-vnil (expr-Nat))))
        (cons 'expr-vindex (expr-vindex (expr-Nat) (expr-zero)
                                        (expr-fzero (expr-zero))
                                        (expr-vnil (expr-Nat))))))

(test-case "pnet-vec/every Vec-Fin node reconstructs as a STRUCT, not a vector"
  (for ([s (in-list samples)])
    (define name (car s))
    (define v (cdr s))
    (define r (round-trip v))
    (check-true (struct? r)
                (format "~a came back as a vector impostor: ~v" name r))
    (check-equal? r v (format "~a round-tripped to a different value" name))))

(test-case "pnet-vec/a Vec nested inside an ordinary node survives"
  ;; The realistic shape: a Vec term inside a def body, inside a lambda.
  (define v (expr-lam 'mw (expr-Vec (expr-Nat) (expr-zero))
                      (expr-vhead (expr-Nat) (expr-zero) (expr-bvar 0))))
  (define r (round-trip v))
  (check-true (struct? r) (format "~v" r))
  (check-equal? r v))

(test-case "pnet-vec/the registrations are in the STATIC table"
  ;; Belt on the mechanism as well as the behaviour: the round-trip above could
  ;; also be satisfied by the dynamic-ctor-cache fallback, and the static table
  ;; is where these were declared. If a later refactor moves them, this says so
  ;; rather than leaving the move silent.
  (define tbl (make-tag-constructor-table))
  (for ([s (in-list samples)])
    (define tag (string->symbol (string-append "struct:" (symbol->string (car s)))))
    (check-true (and (hash-ref tbl tag #f) #t)
                (format "~a is not in the static tag table" (car s)))))

;; ---------------------------------------------------------------------------
;; The sibling gap: families where the member that DETONATED got registered and
;; the ones next to it did not.
;; ---------------------------------------------------------------------------
;;
;; `pipeline.md` names this shape explicitly — "a fix applied to one member of
;; a container family but not its siblings" — and it is what these are.
;; `expr-generic-from-rat` / `-from-int` were registered because they bit (the
;; Q11 Posit→Float instances); the twelve arithmetic and comparison nodes
;; beside them were not, and those are the ones a user actually writes: every
;; generic `+ - * / < <= > >= = mod`, `negate`, `abs` elaborates to one.
;; Likewise `expr-int-lt`/`-eq` were registered while `-le`/`-mod` were not,
;; and the Float lists carry `sqrt` while the Posit lists do not.
;;
;; Enumerated per family rather than spot-checked, because the defect IS the
;; per-member gap — a test that sampled one member of each family would have
;; passed against every one of these.

(define d (expr-zero))

(define sibling-samples
  (append
   (list (cons 'expr-generic-add    (expr-generic-add d d))
         (cons 'expr-generic-sub    (expr-generic-sub d d))
         (cons 'expr-generic-mul    (expr-generic-mul d d))
         (cons 'expr-generic-div    (expr-generic-div d d))
         (cons 'expr-generic-lt     (expr-generic-lt d d))
         (cons 'expr-generic-le     (expr-generic-le d d))
         (cons 'expr-generic-gt     (expr-generic-gt d d))
         (cons 'expr-generic-ge     (expr-generic-ge d d))
         (cons 'expr-generic-eq     (expr-generic-eq d d))
         (cons 'expr-generic-mod    (expr-generic-mod d d))
         (cons 'expr-generic-negate (expr-generic-negate d))
         (cons 'expr-generic-abs    (expr-generic-abs d))
         ;; the two that were already registered — pinned so a refactor that
         ;; rewrites this block cannot drop them on the way past
         (cons 'expr-generic-from-int (expr-generic-from-int d d))
         (cons 'expr-generic-from-rat (expr-generic-from-rat d d))
         (cons 'expr-int-le  (expr-int-le d d))
         (cons 'expr-int-mod (expr-int-mod d d)))
   (list (cons 'expr-p8-sqrt  (expr-p8-sqrt d))
         (cons 'expr-p16-sqrt (expr-p16-sqrt d))
         (cons 'expr-p32-sqrt (expr-p32-sqrt d))
         (cons 'expr-p64-sqrt (expr-p64-sqrt d))
         (cons 'expr-p8-from-nat  (expr-p8-from-nat d))
         (cons 'expr-p16-from-nat (expr-p16-from-nat d))
         (cons 'expr-p32-from-nat (expr-p32-from-nat d))
         (cons 'expr-p64-from-nat (expr-p64-from-nat d)))))

(test-case "pnet-vec/generic + int + posit siblings all reconstruct"
  (for ([s (in-list sibling-samples)])
    (define r (round-trip (cdr s)))
    (check-true (struct? r)
                (format "~a came back as a vector impostor: ~v" (car s) r))
    (check-equal? r (cdr s) (format "~a round-tripped to a different value" (car s)))))
