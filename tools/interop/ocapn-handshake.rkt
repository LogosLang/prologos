#lang racket/base

;;;
;;; ocapn-handshake.rkt — Phase 58 helper.
;;;
;;; Builds the 4-field signed op:start-session bytes that the
;;; upstream ocapn-test-suite (Python) and @endo/ocapn expect.
;;;
;;; Wire shape:
;;;   <op:start-session ver+string pubkey-syrup location-syrup sig-syrup>
;;;
;;; pubkey-syrup is the gcrypt s-expression:
;;;   [public-key [ecc [curve Ed25519] [flags eddsa] [q PUBKEY_BYTES]]]
;;;
;;; sig-syrup is:
;;;   [sig-val [eddsa [r R_BYTES] [s S_BYTES]]]
;;;
;;; location-syrup is the OCapN locator record:
;;;   <ocapn-peer 'tcp-testing-only "address" {"host" "..." "port" "..."}>
;;;
;;; The signature is over the syrup-encoded
;;;   <my-location <ocapn-peer ...>>
;;; payload.

(require racket/base
         racket/string
         "ocapn-crypto.rkt")

(provide make-signed-start-session-bytes
         make-our-location)

;; ========================================
;; Minimal Syrup encoder
;; ========================================
;;
;; The wire form for each kind:
;;   bool         — "t" / "f"
;;   nat          — digits "+"
;;   int-pos      — digits "+" (negatives use "-", we don't need them)
;;   bytes        — LEN ":" bytes
;;   string       — LEN '"' bytes
;;   symbol       — LEN "'" bytes
;;   list         — "[" items "]"
;;   record       — "<" label items ">"
;;   dict         — "{" key value key value ... "}" (sorted by key bytes)
;;
;; We represent values as a small ADT in S-expression form:
;;   #t / #f                       — bools
;;   exact-nonnegative-integer?    — naturals (encoded with "+" suffix)
;;   bytes?                        — bytes
;;   string?                       — string (NB: not bytes — JS distinguishes)
;;   (cons 'sym name)              — symbol
;;   (cons 'list items)            — list
;;   (cons 'rec  (cons label args)) — record
;;   (cons 'dict pairs)            — dictionary

(define (syrup-encode v)
  (cond
    [(boolean? v) (if v #"t" #"f")]
    [(exact-nonnegative-integer? v)
     (bytes-append (string->bytes/utf-8 (number->string v)) #"+")]
    [(bytes? v)
     (bytes-append (string->bytes/utf-8 (number->string (bytes-length v))) #":" v)]
    [(string? v)
     (define b (string->bytes/utf-8 v))
     (bytes-append (string->bytes/utf-8 (number->string (bytes-length b))) #"\"" b)]
    [(and (pair? v) (eq? (car v) 'sym))
     (define b (string->bytes/utf-8 (cdr v)))
     (bytes-append (string->bytes/utf-8 (number->string (bytes-length b))) #"'" b)]
    [(and (pair? v) (eq? (car v) 'list))
     (bytes-append #"[" (apply bytes-append (map syrup-encode (cdr v))) #"]")]
    [(and (pair? v) (eq? (car v) 'rec))
     (define label+args (cdr v))
     (define label (car label+args))
     (define args (cdr label+args))
     (bytes-append #"<" (syrup-encode label)
                   (apply bytes-append (map syrup-encode args))
                   #">")]
    [(and (pair? v) (eq? (car v) 'dict))
     (define pairs (cdr v))
     ;; Sort by encoded-key bytes (Syrup canonical-form requirement).
     (define encoded-pairs
       (for/list ([p (in-list pairs)])
         (define k-enc (syrup-encode (car p)))
         (define v-enc (syrup-encode (cdr p)))
         (cons k-enc v-enc)))
     (define sorted (sort encoded-pairs (lambda (a b) (bytes<? (car a) (car b)))))
     (bytes-append #"{"
                   (apply bytes-append
                          (for/list ([p (in-list sorted)])
                            (bytes-append (car p) (cdr p))))
                   #"}")]
    [else (error 'syrup-encode "unknown value: ~v" v)]))

(define (bytes<? a b)
  (let loop ([i 0])
    (cond
      [(and (= i (bytes-length a)) (= i (bytes-length b))) #f]
      [(= i (bytes-length a)) #t]
      [(= i (bytes-length b)) #f]
      [(< (bytes-ref a i) (bytes-ref b i)) #t]
      [(> (bytes-ref a i) (bytes-ref b i)) #f]
      [else (loop (+ i 1))])))

;; ========================================
;; Our location
;; ========================================

(define (make-our-location host port-num)
  "Build the OCapN locator for our peer.
   Returns the Syrup-encodable record:
     <ocapn-peer 'tcp-testing-only ADDRESS {host=HOST port=PORT}>"
  ;; The address field is a unique designator (the Python test suite
  ;; uses uuid4 hex; we use a fixed string so test runs are
  ;; reproducible).
  (define addr "0123456789abcdef0123456789abcdef")
  (cons 'rec
        (list (cons 'sym "ocapn-peer")
              (cons 'sym "tcp-testing-only")
              addr
              (cons 'dict
                    (list (cons (cons 'sym "host") host)
                          (cons (cons 'sym "port")
                                (number->string port-num)))))))

;; ========================================
;; gcrypt-style s-expressions
;; ========================================

(define (gcrypt-pubkey-sexpr pubkey-bytes)
  "Build the canonical pubkey s-expression:
     [public-key [ecc [curve Ed25519] [flags eddsa] [q PUBKEY_BYTES]]]"
  (cons 'list
        (list (cons 'sym "public-key")
              (cons 'list
                    (list (cons 'sym "ecc")
                          (cons 'list (list (cons 'sym "curve")
                                            (cons 'sym "Ed25519")))
                          (cons 'list (list (cons 'sym "flags")
                                            (cons 'sym "eddsa")))
                          (cons 'list (list (cons 'sym "q")
                                            pubkey-bytes)))))))

(define (gcrypt-sig-sexpr sig-bytes)
  "Build the canonical signature s-expression:
     [sig-val [eddsa [r R_BYTES] [s S_BYTES]]]"
  (unless (= (bytes-length sig-bytes) 64)
    (error 'gcrypt-sig-sexpr "expected 64-byte sig; got ~a" (bytes-length sig-bytes)))
  (define r (subbytes sig-bytes 0 32))
  (define s (subbytes sig-bytes 32 64))
  (cons 'list
        (list (cons 'sym "sig-val")
              (cons 'list
                    (list (cons 'sym "eddsa")
                          (cons 'list (list (cons 'sym "r") r))
                          (cons 'list (list (cons 'sym "s") s)))))))

;; ========================================
;; Build the signed op:start-session
;; ========================================

(define (make-signed-start-session-bytes captp-version host port-num)
  "Return (bytes, keypair, pubkey-bytes) for a fresh signed
   op:start-session. The caller can stash the keypair for later
   signing or verify operations."
  (define kp (make-ed25519-keypair))
  (define pubkey (ed25519-pubkey-bytes kp))
  (define location (make-our-location host port-num))
  ;; Per spec: sign the syrup-encoded <my-location LOC>.
  (define my-location
    (cons 'rec (list (cons 'sym "my-location") location)))
  (define payload (syrup-encode my-location))
  (define sig (ed25519-sign kp payload))
  (define start-session
    (cons 'rec
          (list (cons 'sym "op:start-session")
                captp-version
                (gcrypt-pubkey-sexpr pubkey)
                location
                (gcrypt-sig-sexpr sig))))
  (values (syrup-encode start-session) kp pubkey))
