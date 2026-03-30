#lang racket/base

;;;
;;; Tests for dot-access syntax: rewrite-dot-access unit tests + reader tokenization
;;;
;;; Sections A-B of dot-access tests.
;;; A: rewrite-dot-access macro rewriting (postfix, chained, prefix, lambda, passthrough)
;;; B: Reader tokenization (.field, .:kw, chained, ..., ...args, :: qualified)
;;;

(require rackunit
         racket/list
         "../macros.rkt"
         "../parse-reader.rkt")

;; ========================================
;; A. Unit tests: rewrite-dot-access
;; ========================================

(test-case "rewrite-dot-access: basic postfix"
  (check-equal?
   (rewrite-dot-access '(user ($dot-access name)))
   '(map-get user :name)))

(test-case "rewrite-dot-access: chained postfix"
  (check-equal?
   (rewrite-dot-access '(user ($dot-access address) ($dot-access city)))
   '(map-get (map-get user :address) :city)))

(test-case "rewrite-dot-access: dot-key prefix"
  (check-equal?
   (rewrite-dot-access '(($dot-key :name) user))
   '(map-get user :name)))

(test-case "rewrite-dot-access: in larger form"
  (check-equal?
   (rewrite-dot-access '(f user ($dot-access name) x))
   '(f (map-get user :name) x)))

(test-case "rewrite-dot-access: no sentinels passthrough"
  (check-equal?
   (rewrite-dot-access '(f x y))
   '(f x y)))

(test-case "rewrite-dot-access: standalone dot-key → lambda"
  (check-equal?
   (rewrite-dot-access '(($dot-key :name)))
   '(fn ($x : _) (map-get $x :name))))

(test-case "rewrite-dot-access: non-list passthrough"
  (check-equal? (rewrite-dot-access 'x) 'x)
  (check-equal? (rewrite-dot-access 42) 42))

;; ========================================
;; B. Reader tokenization tests
;; ========================================

;; Helper: filter out newline/eof tokens to get just content tokens
(define (content-tokens s)
  (filter (lambda (t)
            (not (memq (token-type t) '(newline eof))))
          (tokenize-string s)))

(test-case "reader: .field produces dot-access token"
  (define toks (content-tokens ".name"))
  (check-equal? (length toks) 1)
  (check-equal? (token-type (car toks)) 'dot-access)
  (check-equal? (token-value (car toks)) 'name))

(test-case "reader: .:kw produces dot-key token"
  (define toks (content-tokens ".:name"))
  (check-equal? (length toks) 1)
  (check-equal? (token-type (car toks)) 'dot-key)
  (check-equal? (token-value (car toks)) ':name))

(test-case "reader: user.name splits into two tokens"
  (define toks (content-tokens "user.name"))
  (check-equal? (length toks) 2)
  (check-equal? (token-type (car toks)) 'symbol)
  (check-equal? (token-value (car toks)) 'user)
  (check-equal? (token-type (cadr toks)) 'dot-access)
  (check-equal? (token-value (cadr toks)) 'name))

(test-case "reader: chained user.addr.city splits into three tokens"
  (define toks (content-tokens "user.addr.city"))
  (check-equal? (length toks) 3)
  (check-equal? (token-type (car toks)) 'symbol)
  (check-equal? (token-value (car toks)) 'user)
  (check-equal? (token-type (cadr toks)) 'dot-access)
  (check-equal? (token-value (cadr toks)) 'addr)
  (check-equal? (token-type (caddr toks)) 'dot-access)
  (check-equal? (token-value (caddr toks)) 'city))

(test-case "reader: ... still works"
  (define toks (content-tokens "..."))
  (check-equal? (token-type (car toks)) 'symbol)
  (check-equal? (token-value (car toks)) '$rest))

(test-case "reader: ...args still works"
  (define toks (content-tokens "...args"))
  (check-equal? (token-type (car toks)) 'rest-param)
  (check-equal? (token-value (car toks)) 'args))

(test-case "reader: :: qualified names still work"
  (define toks (content-tokens "nat::add"))
  (check-equal? (length toks) 1)
  (check-equal? (token-type (car toks)) 'symbol)
  (check-equal? (token-value (car toks)) 'nat::add))
