#lang racket/base
;; PCE/1 — Prologos Canonical Encoding, version 1.
;;
;; PReduce Track 1 (D.3 §2, owner-signed identity package; autonomy ledger iter 7).
;; THE single-hasher module: pce.rkt owns canonical encoding + hashing; the
;; golden-vector generator IS this library (two-producer hazard rule). Every
;; content-address KEY in PReduce (hashcons, e-class cells, .pnet fragments, the
;; question-keyed store) derives from THIS module and nothing else.
;;
;; Determinism contract (the freeze): explicit little-endian lengths; sorted hash
;; iteration (by encoded-key bytes); INTERNED symbols only (uninterned = admission
;; ERROR); exact integers as sign+magnitude (bignum-safe); floats/inexact EXCLUDED
;; in v1 (admission ERROR — byte rules defined with a future vector round, D.3 §2);
;; struct encoding = stable struct NAME bytes + arity + fields (all core expr-*
;; structs are #:transparent, loc-free, de Bruijn — verified 2026-06-10).
;; KIND-BYTE DOMAIN SEPARATION prefixes every digest; the session-local effectful
;; domain (kind 2) is STRUCTURALLY EXCLUDED from the persisted hash domain
;; (pce-persistable-digest errors — D.3 §2 key-space closure iv).
(require racket/list)

(provide PCE-VERSION
         PCE-KIND-GROUND-TERM
         PCE-KIND-EFFECTFUL-SESSION
         pce-encode
         pce-digest
         pce-persistable-digest
         pce-hex)

(define PCE-VERSION 1)
(define PCE-KIND-GROUND-TERM 1)
(define PCE-KIND-EFFECTFUL-SESSION 2)

;; --- byte helpers (explicit little-endian, length-prefixed) ---

(define (len-bytes n)  ;; u32 LE length prefix
  (integer->integer-bytes n 4 #f #f))

(define (tagged tag . chunks)
  (apply bytes-append (bytes tag) chunks))

;; --- the canonical encoder ---
;; v1 value domain: exact integers, exact rationals, interned symbols, strings,
;; bytes, booleans, null, pairs, vectors, immutable hashes, transparent structs.
;; Everything else = admission ERROR (closed domain; extend by version, never
;; silently).

(define (pce-encode v)
  (cond
    [(exact-integer? v)
     (define neg? (negative? v))
     (define mag (abs v))
     (define mag-bytes
       (if (zero? mag)
           (bytes 0)
           (let loop ([m mag] [acc '()])
             (if (zero? m)
                 (apply bytes (reverse acc))
                 (loop (arithmetic-shift m -8) (cons (bitwise-and m 255) acc))))))
     (tagged #x01 (bytes (if neg? 1 0)) (len-bytes (bytes-length mag-bytes)) mag-bytes)]
    [(and (rational? v) (exact? v))  ;; exact non-integer rational
     (tagged #x0A (pce-encode (numerator v)) (pce-encode (denominator v)))]
    [(symbol? v)
     (unless (symbol-interned? v)
       (error 'pce-encode "uninterned symbol excluded from PCE/1 domain (admission guard): ~a" v))
     (define b (string->bytes/utf-8 (symbol->string v)))
     (tagged #x02 (len-bytes (bytes-length b)) b)]
    [(string? v)
     (define b (string->bytes/utf-8 v))
     (tagged #x03 (len-bytes (bytes-length b)) b)]
    [(bytes? v) (tagged #x04 (len-bytes (bytes-length v)) v)]
    [(null? v) (tagged #x05)]
    [(boolean? v) (tagged #x07 (bytes (if v 1 0)))]
    [(pair? v) (tagged #x06 (pce-encode (car v)) (pce-encode (cdr v)))]
    [(vector? v)
     (apply bytes-append (bytes #x0B) (len-bytes (vector-length v))
            (for/list ([x (in-vector v)]) (pce-encode x)))]
    [(and (hash? v) (immutable? v))
     ;; sorted by encoded-key bytes — iteration-order independence
     (define entries
       (sort (for/list ([(k val) (in-hash v)])
               (cons (pce-encode k) (pce-encode val)))
             bytes<? #:key car))
     (apply bytes-append (bytes #x09) (len-bytes (length entries))
            (for/list ([e (in-list entries)]) (bytes-append (car e) (cdr e))))]
    [(struct? v)
     (define sv (struct->vector v))
     (define name (vector-ref sv 0))  ;; 'struct:NAME — stable identifier
     (define name-b (string->bytes/utf-8 (symbol->string name)))
     (apply bytes-append (bytes #x08)
            (len-bytes (bytes-length name-b)) name-b
            (len-bytes (sub1 (vector-length sv)))
            (for/list ([i (in-range 1 (vector-length sv))])
              (pce-encode (vector-ref sv i))))]
    [(and (real? v) (inexact? v))
     (error 'pce-encode "inexact/float excluded from PCE/1 domain (admission guard; byte rules deferred per D.3 §2): ~a" v)]
    [else
     (error 'pce-encode "value outside the PCE/1 closed domain (admission guard): ~e" v)]))

;; --- digests ---

(define (pce-digest kind v)
  (unless (memv kind (list PCE-KIND-GROUND-TERM PCE-KIND-EFFECTFUL-SESSION))
    (error 'pce-digest "unknown PCE kind byte: ~a" kind))
  (sha256-bytes (bytes-append (bytes PCE-VERSION kind) (pce-encode v))))

;; The persisted-domain guard (D.3 §2 closure iv): session-local effectful
;; digests are STRUCTURALLY excluded from anything that persists.
(define (pce-persistable-digest kind v)
  (when (eqv? kind PCE-KIND-EFFECTFUL-SESSION)
    (error 'pce-persistable-digest
           "ADMISSION GUARD: effectful-session digests (kind 2) are session-local and never persist (D.3 §2)"))
  (pce-digest kind v))

(define (pce-hex d)
  (apply string-append (for/list ([b (in-bytes d)])
                         (if (< b 16)
                             (string-append "0" (number->string b 16))
                             (number->string b 16)))))

;; --- golden-vector generator (the cross-language conformance artifact) ---

(module+ main
  (require (file "syntax.rkt"))
  (define vectors
    (list (cons "int-42"        (expr-int 42))
          (cons "int-neg-7"     (expr-int -7))
          (cons "bignum"        (expr-int 340282366920938463463374607431768211456))
          (cons "bvar-0"        (expr-bvar 0))
          (cons "lam-id"        (expr-lam 'm1 (expr-Int) (expr-bvar 0)))
          (cons "app"           (expr-app (expr-bvar 0) (expr-int 42)))
          (cons "nested"        (expr-app (expr-lam 'mw (expr-Int) (expr-bvar 0))
                                          (expr-app (expr-bvar 1) (expr-int 3))))
          (cons "symbol"        'hello)
          (cons "string"        "prologos")
          (cons "list"          (list 1 2 3))
          (cons "hash"          (hasheq 'b 2 'a 1))
          (cons "rational"      22/7)
          (cons "bool-pair"     (cons #t #f))))
  (with-output-to-file "data/pce-golden-vectors-v1.txt" #:exists 'replace
    (lambda ()
      (printf "PCE/1 golden vectors — version ~a, kind ~a (ground term)\n"
              PCE-VERSION PCE-KIND-GROUND-TERM)
      (printf ";; Regenerate ONLY via `racket pce.rkt` (the single-hasher rule).\n")
      (for ([v (in-list vectors)])
        (printf "~a ~a\n" (car v)
                (pce-hex (pce-digest PCE-KIND-GROUND-TERM (cdr v)))))))
  (displayln "golden vectors written to data/pce-golden-vectors-v1.txt"))
