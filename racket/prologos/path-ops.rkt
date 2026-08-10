#lang racket/base

;;;
;;; PROLOGOS PATH OPERATIONS
;;; Racket-side implementations for first-class path introspection.
;;; These functions operate on Prologos IR values directly (passthrough marshalling).
;;;

(require racket/string
         "syntax.rkt")

(provide path-segments
         path-from-segments
         path-branch-count
         path-depth
         path-head
         path-tail)

;; (cons-name? / nil-name? removed 2026-08-04 — they existed only for the
;; Prologos cons-chain walker in path-from-segments, which the FFI boundary
;; never actually hands a cons chain. Dead with it.)

;; path-segments : expr-path -> (List Keyword)
;; Extract the first branch's segments as a Prologos list.
(define (path-segments p)
  (unless (expr-path? p)
    (error 'path-segments "expected a Path value, got ~a" p))
  (define segs (if (pair? (expr-path-branches p))
                   (car (expr-path-branches p))
                   '()))
  ;; D4.P4b-i: segments are bare SYMBOLS internally (the step encoding), so
  ;; the FFI boundary marshals them back to Prologos keyword VALUES here.
  ;;
  ;; ✅ FIXED 2026-08-04. This used to build a Prologos CONS-CHAIN, while
  ;; `marshal-racket->prologos` for a `(List T)` return type wants a **Racket
  ;; list** whose elements it marshals individually (`foreign.rkt:304-309`) —
  ;; so the declared `Path -> [List Keyword]` raised "Cannot marshal to List —
  ;; expected Racket list" and took the whole file down with it. The comment
  ;; here recorded that and left it; `from-segments` and `path-append` were
  ;; dead alongside.
  ;;
  ;; A Racket list it is. `Keyword` is a PASSTHROUGH type in the marshaller
  ;; (`:326`), i.e. the element must ALREADY be a Prologos IR value — hence
  ;; `expr-keyword` per element rather than a bare symbol.
  (map expr-keyword segs))

;; path-from-segments : (List Keyword) -> expr-path
;; Build a single-branch path from a list of keywords.
;;
;; ✅ FIXED 2026-08-04, the inbound twin of the defect above. This walked a
;; Prologos CONS-CHAIN (expr-nil / curried `cons` applications, with arms for
;; the type-arg-carrying spellings) — but `marshal-prologos->racket` for a
;; `(List T)` PARAMETER hands the shim a plain **Racket list**
;; (`foreign.rkt:214-217`), so every call died in the `[else]` arm with
;; "expected a List, got (#(struct:expr-keyword a) …)" — the Racket list it was
;; already being given, reported as if it were the wrong thing.
;;
;; The cons-chain walker is gone rather than kept as a fallback: the marshaller
;; is the only caller, it always passes a Racket list, and a second accepted
;; shape here would just hide the next boundary mismatch.
(define (path-from-segments lst)
  (define segs
    (cond
      [(list? lst) lst]
      [else (error 'path-from-segments
                   "expected a Racket list from the FFI boundary, got ~a" lst)]))
  ;; D4.P4b-i: the inverse boundary — Prologos keyword VALUES in, bare symbols
  ;; (the step encoding) out. A non-keyword segment is refused rather than
  ;; coerced: coercing an unrecognized segment into a key is precisely the
  ;; silent-catch-all that made `#p(a.*)` fabricate `<error>` values (Q_U11).
  (expr-path
   (list (for/list ([seg (in-list segs)])
           (cond
             [(expr-keyword? seg) (expr-keyword-name seg)]
             [(symbol? seg) seg]
             [else (error 'path-from-segments
                          "path segments must be keywords, got ~a" seg)])))
   ;; D4.P4b-ii-1: the FFI builds a `#p(…)`-equivalent value, so `'path`.
   'path))

;; path-branch-count : expr-path -> Int
;; Number of branches in a path (usually 1 unless branching).
(define (path-branch-count p)
  (unless (expr-path? p)
    (error 'path-branch-count "expected a Path value, got ~a" p))
  (length (expr-path-branches p)))

;; path-depth : expr-path -> Int
;; Number of segments in the first branch.
(define (path-depth p)
  (unless (expr-path? p)
    (error 'path-depth "expected a Path value, got ~a" p))
  (define segs (if (pair? (expr-path-branches p))
                   (car (expr-path-branches p))
                   '()))
  (length segs))

;; path-head : expr-path -> Keyword
;; First segment of the first branch.
(define (path-head p)
  (unless (expr-path? p)
    (error 'path-head "expected a Path value, got ~a" p))
  (define segs (if (pair? (expr-path-branches p))
                   (car (expr-path-branches p))
                   '()))
  ;; D4.P4b-i: marshal the internal symbol out as a Prologos keyword VALUE
  (if (pair? segs)
      (expr-keyword (car segs))
      (error 'path-head "empty path has no head")))

;; path-tail : expr-path -> Path
;; Path without the first segment.
(define (path-tail p)
  (unless (expr-path? p)
    (error 'path-tail "expected a Path value, got ~a" p))
  (define segs (if (pair? (expr-path-branches p))
                   (car (expr-path-branches p))
                   '()))
  (if (pair? segs)
      ;; D4.P4b-ii-1: the tail of a selector is the SAME sort — preserve it
      ;; rather than defaulting, so a future `'block` carrier reaching here
      ;; cannot be silently re-sorted.
      (expr-path (list (cdr segs)) (expr-path-sort p))
      (error 'path-tail "empty path has no tail")))
