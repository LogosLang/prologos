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

;; Check if a symbol is a cons-like name (bare or module-qualified)
(define (cons-name? name)
  (let ([s (symbol->string name)])
    (or (string=? s "cons")
        (let ([len (string-length s)])
          (and (>= len 6) (string=? (substring s (- len 6)) "::cons"))))))

;; Check if a symbol is a nil-like name
(define (nil-name? name)
  (let ([s (symbol->string name)])
    (or (string=? s "nil")
        (let ([len (string-length s)])
          (and (>= len 5) (string=? (substring s (- len 5)) "::nil"))))))

;; path-segments : expr-path -> (List Keyword)
;; Extract the first branch's segments as a Prologos list.
(define (path-segments p)
  (unless (expr-path? p)
    (error 'path-segments "expected a Path value, got ~a" p))
  (define segs (if (pair? (expr-path-branches p))
                   (car (expr-path-branches p))
                   '()))
  (foldr (lambda (seg acc) (expr-app (expr-app (expr-fvar 'cons) seg) acc))
         (expr-nil) segs))

;; path-from-segments : (List Keyword) -> expr-path
;; Build a single-branch path from a Prologos list of keywords.
(define (path-from-segments lst)
  (define segs
    (let loop ([l lst] [acc '()])
      (cond
        ;; expr-nil — end of list
        [(expr-nil? l) (reverse acc)]
        ;; nil fvar — legacy nil form
        [(and (expr-fvar? l) (nil-name? (expr-fvar-name l))) (reverse acc)]
        ;; (nil A) — nil applied to type arg
        [(and (expr-app? l)
              (let ([f (expr-app-func l)])
                (and (expr-fvar? f) (nil-name? (expr-fvar-name f)))))
         (reverse acc)]
        ;; ((cons x) xs) or (((cons A) x) xs) — curried constructor, possibly with type arg
        [(and (expr-app? l)
              (expr-app? (expr-app-func l))
              (let ([inner (expr-app-func (expr-app-func l))])
                (or (and (expr-fvar? inner) (cons-name? (expr-fvar-name inner)))
                    ;; (((cons A) x) xs) — cons applied to type arg first
                    (and (expr-app? inner)
                         (let ([innermost (expr-app-func inner)])
                           (and (expr-fvar? innermost) (cons-name? (expr-fvar-name innermost))))))))
         (define xs (expr-app-arg l))
         (define head-app (expr-app-func l))
         ;; Head extraction: skip type arg if present
         (define head
           (if (and (expr-app? (expr-app-func head-app))
                    (let ([f (expr-app-func (expr-app-func head-app))])
                      (and (expr-fvar? f) (cons-name? (expr-fvar-name f)))))
               ;; (((cons A) x) xs) — head = x (skip type arg A)
               (expr-app-arg head-app)
               ;; ((cons x) xs) — head = x
               (expr-app-arg head-app)))
         (loop xs (cons head acc))]
        [else (error 'path-from-segments "expected a List, got ~a" l)])))
  (expr-path (list segs)))

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
  (if (pair? segs)
      (car segs)
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
      (expr-path (list (cdr segs)))
      (error 'path-tail "empty path has no tail")))
