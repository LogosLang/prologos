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
         "pce.rkt"
         "propagator.rkt")

(provide preduce-project-sections
         preduce-write-pnetx!
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
  (unless (net-quiescent? net)
    (error 'preduce-project-sections
           "ASSERT quiescent-at-serialize (Track 5 design §7): the projection reads the FIXPOINT"))
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
             (cons (list (pce-hex dig) (cdr best) (car best) 'ground) acc)]
            [else acc]))
        '()))
  (define store (and store-cid (net-cell-read net store-cid)))
  (define rewrite-entries
    (if (hash? store)
        (for/list ([(k v) (in-hash store)]
                   #:when (eq? (hash-ref v 'regime #f) 'ground))
          (list (pce-hex (car k)) (cadr k) (hash-ref v 'cost) (hash-ref v 'form)))
        '()))
  (list (cons SECTION-ECLASSES eclass-entries)
        (cons SECTION-REWRITES rewrite-entries)))

(define (preduce-write-pnetx! path net hashcons-cid store-cid origin)
  (pnet2-write-sections path
                        (preduce-project-sections net hashcons-cid store-cid origin)))
