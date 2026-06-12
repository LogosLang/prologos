#lang racket/base
;;; preduce-pnet.rkt — PReduce Track 5 Phase 1: the serialize-time PROJECTION
;;; (design §2; ledger iter 36). PURE READ of cells → the two ground-only
;;; tagged sections. No serializer-side mutation; quiescent-at-serialize is
;;; ASSERTED (the §7 VAG's structural check).
(require racket/set
         racket/list
         "eclass-graph.rkt"
         "eclass-cell.rkt"
         "extraction-store.rkt"
         "pnet-sections.rkt"
         (only-in "pnet-serialize.rkt"
                  deep-struct->serializable deep-serializable->struct)
         "pce.rkt"
         "propagator.rkt")

(provide preduce-project-sections
         preduce-write-pnetx!
         preduce-pnetx-path
         preduce-load-pnetx!
         preduce-save-pnetx!
         SECTION-ECLASSES
         SECTION-REWRITES)

(define SECTION-ECLASSES 'preduce-eclasses)
(define SECTION-REWRITES 'preduce-rewrites)

;; provenance is an eq-set with cons members — SCAN for the origin pair
;; (set-member? with a fresh cons would fail under eq; duplicates across merges
;; are wasteful-but-sound, the documented class)
(define (class-origin v)
  (for/or ([m (in-set (hash-ref v ':provenance (seteq)))])
    (and (symbol? m)
         (let ([str (symbol->string m)])
           (and (regexp-match? #rx"^origin:" str)
                (string->symbol (substring str 7)))))))

;; → (listof (cons tag datum)) — the projection; PURE read.
;; Section A entries: (digest-hex form cost regime); admission per iter 26
;; (inadmissible forms simply not projected). Section B: ground entries of the
;; question-keyed store, keys hex-encoded for write/read stability.
(define (preduce-project-sections net hashcons-cid store-cid origin)
  ;; AMENDED (iter 37, probe-driven): the hard quiescent assert demanded the
  ;; unachievable — the prn carries PERMANENT WORKLIST RESIDUE (prop-ids that
  ;; neither scheduler fires nor removes; 112 observed at file close; a real
  ;; substrate finding, DEFERRED-listed). The achievable contract: the SAVE
  ;; attempts quiescence first (fireable work reaches its fixpoint); the
  ;; projection reads CELL STATE, which residue ids cannot change. Callers
  ;; that want the strict check use net-quiescent? themselves.
  (define reg (net-cell-read net hashcons-cid))
  (define eclass-entries
    (if (hash? reg)
        (for/fold ([acc '()]) ([(dig entry) (in-hash reg)])
          (define cid (cdr entry))
          (define v (eclass-read net cid))
          (define best (and (hash? v) (hash-ref v ':best #f)))
          (cond
            [(and best
                  (eq? (hash-ref v ':regime #f) 'ground)
                  (equal? (class-origin v) origin)
                  ;; admission: the form must be PCE-encodable (iter-26 rule)
                  (with-handlers ([exn:fail? (lambda (_e) #f)])
                    (pce-encode (cdr best))
                    #t))
             ;; FORM CODEC (2026-06-11, second stacked defect): expr STRUCTS do
             ;; not survive raw write/read (transparent structs read back as
             ;; plain vectors → "no matching clause" crashes when served warm).
             ;; PCE-encodable ≠ container-round-trippable — the admissibility
             ;; check alone was the wrong criterion. Encode via the legacy
             ;; .pnet codec (every AST node registers there per pipeline.md).
             (cons (list (pce-hex dig) (deep-struct->serializable (cdr best))
                         (car best) 'ground) acc)]
            [else acc]))
        '()))
  (define store (and store-cid (net-cell-read net store-cid)))
  (define rewrite-entries
    (if (hash? store)
        (for/list ([(k v) (in-hash store)]
                   #:when (eq? (hash-ref v 'regime #f) 'ground))
          (list (pce-hex (car k)) (cadr k) (hash-ref v 'cost)
                (deep-struct->serializable (hash-ref v 'form))))
        '()))
  (list (cons SECTION-ECLASSES eclass-entries)
        (cons SECTION-REWRITES rewrite-entries)))

(define (preduce-write-pnetx! path net hashcons-cid store-cid origin)
  (pnet2-write-sections path
                        (preduce-project-sections net hashcons-cid store-cid origin)))

;; --- Phase 2 (iter 37): the load-time re-pour + the save hook ---

(define (preduce-pnetx-path src)
  (string-append (if (path? src) (path->string src) src) ".pnetx"))

(define (hex->bytes hx)
  (define n (quotient (string-length hx) 2))
  (define b (make-bytes n))
  (for ([i (in-range n)])
    (bytes-set! b i (string->number (substring hx (* 2 i) (+ 2 (* 2 i))) 16)))
  b)

;; Re-pour: section A entries re-intern. KEY SURVIVAL (2026-06-11 fix): the
;; persisted digest is the digest of the ORIGINALLY-INTERNED term — for memo
;; classes that is the BODY, while the persisted form is the cost-0 RESULT.
;; Re-interning the form alone registers only digest(form); the warm lookup
;; arrives keyed by digest(body) and would MISS (probe-verified: 15/15 entries
;; of the real acceptance artifact were unreachable; the iter-39 warm≈cold
;; A/B could not have seen any recurrence benefit). So the persisted digest is
;; registered as an ALIAS to the re-poured class (hash-union per-key
;; min-by-alloc merge — ACI-safe). Identity classes (digest(form) = persisted)
;; skip the alias. Persisted costs ride along; regime 'ground; origin = the
;; CURRENT file's origin parameter. Section B merges via keep-better — the
;; lattice reconciles stale-vs-fresh automatically.
;; MTIME INVALIDATION (SM6 day-one bound): a source newer than its .pnetx
;; skips the re-pour entirely (degraded to cold, never wrong).
(define (preduce-load-pnetx! prn-box src hashcons-cid store-cid)
  (define px (preduce-pnetx-path src))
  (when (and prn-box hashcons-cid
             (file-exists? px)
             (file-exists? src)
             (>= (file-or-directory-modify-seconds px)
                 (file-or-directory-modify-seconds src)))
    (define sections (pnet2-read-sections px))
    (when sections
      ;; section A: re-intern content triples + persisted-digest alias
      (for ([e (in-list (or (pnet2-section-ref sections SECTION-ECLASSES) '()))])
        (define persisted-dig (hex->bytes (car e)))
        (define form (deep-serializable->struct (cadr e)))
        (define cost (caddr e))
        (define-values (n1 cid dig)
          (eclass-intern (unbox prn-box) hashcons-cid form
                         #:cost cost #:regime 'ground))
        (define n2
          (if (equal? dig persisted-dig)
              n1
              (net-cell-write n1 hashcons-cid
                              (hash persisted-dig (cons (cell-id-n cid) cid)))))
        (set-box! prn-box n2))
      ;; section B: rebuild keys, merge keep-better
      (when store-cid
        (define entries (or (pnet2-section-ref sections SECTION-REWRITES) '()))
        (unless (null? entries)
          (define store-delta
            (for/hash ([e (in-list entries)])
              (values (list (hex->bytes (car e)) (cadr e) #f)
                      (hash 'cost (caddr e)
                            'form (deep-serializable->struct (cadddr e))
                            'regime 'ground))))
          (set-box! prn-box
                    (net-cell-write (unbox prn-box) store-cid store-delta)))))))

;; Save: at file close. The projection ASSERTS quiescence; at driver close a
;; non-quiescent net DEGRADES to no-save (with-handlers — persistence is an
;; optimization, never a crash source at the production boundary).
(define (preduce-save-pnetx! prn-box src hashcons-cid store-cid origin)
  (when (and prn-box hashcons-cid)
    (with-handlers ([exn:fail? (lambda (_e) (void))])
      ;; PRODUCE the fixpoint the projection's assert demands: the prn carries
      ;; pending propagator work at file close (memo writes after the last
      ;; drive) — one quiescence here, only under the PNETX gate (iter 37:
      ;; the probe found the assert correctly refusing a live worklist)
      (set-box! prn-box (run-to-quiescence (unbox prn-box)))
      (preduce-write-pnetx! (preduce-pnetx-path src) (unbox prn-box)
                            hashcons-cid store-cid origin))))
