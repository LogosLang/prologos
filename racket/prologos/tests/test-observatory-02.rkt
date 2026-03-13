#lang racket/base

;;;
;;; test-observatory-02.rkt — Serialization tests for Propagator Observatory
;;;
;;; Tests JSON serialization of cell-meta, net-capture, cross-net-link, observatory.
;;;

(require rackunit
         json
         "../prop-observatory.rkt"
         "../observatory-serialize.rkt"
         "../propagator.rkt"
         "../champ.rkt")

;; ========================================
;; Test Helpers
;; ========================================

(define (findf pred lst)
  (cond [(null? lst) #f]
        [(pred (car lst)) (car lst)]
        [else (findf pred (cdr lst))]))

(define (flat-merge old new)
  (cond [(eq? old 'bot) new]
        [(eq? new 'bot) old]
        [(equal? old new) old]
        [else 'top]))

;; Build a small test network: 2 cells + 1 propagator, run to quiescence
(define (make-quiesced-network)
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 pid)
    (net-add-propagator net2
      (list ca) (list cb)
      (lambda (n)
        (net-cell-write n cb (net-cell-read n ca)))))
  (define net4 (net-cell-write net3 ca 42))
  (define net5 (run-to-quiescence net4))
  (values net5 ca cb))

;; ========================================
;; 1. serialize-cell-meta
;; ========================================

(test-case "serialize-cell-meta: basic fields"
  (define cm (cell-meta 'session "self" #f 'session-protocol (hasheq)))
  (define json (serialize-cell-meta cm))
  (check-equal? (hash-ref json 'subsystem) "session")
  (check-equal? (hash-ref json 'label) "self")
  (check-equal? (hash-ref json 'domain) "session-protocol")
  (check-equal? (hash-ref json 'sourceLoc) (json-null)))

(test-case "serialize-cell-meta: with extra fields"
  (define cm (cell-meta 'user "cell-0" #f 'lattice (hasheq 'merge-fn "flat-merge")))
  (define json (serialize-cell-meta cm))
  (check-equal? (hash-ref (hash-ref json 'extra) 'merge-fn) "flat-merge"))

;; ========================================
;; 2. serialize-net-capture
;; ========================================

(test-case "serialize-net-capture: complete capture with network"
  (define-values (net ca cb) (make-quiesced-network))
  (define metas (build-cell-metas-from-network net 'test 'lattice))
  (define cap (net-capture 'test-cap-1 'session "session:test"
                           net metas #f
                           'complete #f
                           1000.0 0 #f))
  (define json (serialize-net-capture cap))
  ;; Top-level fields
  (check-equal? (hash-ref json 'id) "test-cap-1")
  (check-equal? (hash-ref json 'subsystem) "session")
  (check-equal? (hash-ref json 'label) "session:test")
  (check-equal? (hash-ref json 'status) "complete")
  (check-equal? (hash-ref json 'statusDetail) (json-null))
  (check-equal? (hash-ref json 'parentId) (json-null))
  (check-equal? (hash-ref json 'sequenceNumber) 0)
  (check-equal? (hash-ref json 'timestampMs) 1000.0)
  ;; Network should have cells
  (define net-json (hash-ref json 'network))
  (define cells (hash-ref net-json 'cells))
  (check-true (>= (length cells) 2))
  ;; Cells should be enriched with cell-meta
  (define cell-0 (findf (lambda (c) (= (hash-ref c 'id) 0)) cells))
  (check-not-false cell-0)
  (check-equal? (hash-ref cell-0 'label) "cell-0")
  (check-equal? (hash-ref cell-0 'domain) "lattice")
  ;; No trace
  (check-equal? (hash-ref json 'trace) (json-null)))

(test-case "serialize-net-capture: with parent-id"
  (define net (make-prop-network))
  (define cap (net-capture 'child-1 'test "child"
                           net champ-empty #f
                           'complete #f
                           2000.0 1 'parent-1))
  (define json (serialize-net-capture cap))
  (check-equal? (hash-ref json 'parentId) "parent-1"))

(test-case "serialize-net-capture: exception status"
  (define net (make-prop-network))
  (define cap (net-capture 'fail-1 'type-inference "elab:failed"
                           net champ-empty #f
                           'exception "fuel exhausted"
                           3000.0 2 #f))
  (define json (serialize-net-capture cap))
  (check-equal? (hash-ref json 'status) "exception")
  (check-equal? (hash-ref json 'statusDetail) "fuel exhausted"))

;; ========================================
;; 3. serialize-cross-net-link
;; ========================================

(test-case "serialize-cross-net-link: basic fields"
  (define link (cross-net-link 'cap-a (cell-id 0) 'cap-b (cell-id 3) 'type-of))
  (define json (serialize-cross-net-link link))
  (check-equal? (hash-ref json 'fromCapture) "cap-a")
  (check-equal? (hash-ref json 'fromCell) 0)
  (check-equal? (hash-ref json 'toCapture) "cap-b")
  (check-equal? (hash-ref json 'toCell) 3)
  (check-equal? (hash-ref json 'relation) "type-of"))

;; ========================================
;; 4. serialize-observatory
;; ========================================

(test-case "serialize-observatory: empty observatory"
  (define obs (make-observatory (hasheq 'file "test.prologos")))
  (define json (serialize-observatory obs))
  (check-equal? (hash-ref json 'version) 2)
  (define obs-json (hash-ref json 'observatory))
  (check-equal? (hash-ref obs-json 'captures) '())
  (check-equal? (hash-ref obs-json 'links) '())
  (define meta (hash-ref obs-json 'metadata))
  (check-equal? (hash-ref meta 'totalCaptures) 0)
  (check-equal? (hash-ref meta 'subsystems) '()))

(test-case "serialize-observatory: with captures and links"
  (define obs (make-observatory (hasheq 'file "test.prologos")))
  (define-values (net ca cb) (make-quiesced-network))
  (define metas (build-cell-metas-from-network net 'session 'session-protocol))
  ;; Register two captures
  (observatory-register-capture! obs
    (net-capture 'cap-1 'session "s1" net metas #f
                 'complete #f 100.0
                 (observatory-next-sequence! obs) #f))
  (observatory-register-capture! obs
    (net-capture 'cap-2 'capability "c1" net champ-empty #f
                 'complete #f 200.0
                 (observatory-next-sequence! obs) #f))
  ;; Register a link
  (observatory-register-link! obs
    (cross-net-link 'cap-1 (cell-id 0) 'cap-2 (cell-id 0) 'type-of))
  ;; Serialize
  (define json (serialize-observatory obs))
  (check-equal? (hash-ref json 'version) 2)
  (define obs-json (hash-ref json 'observatory))
  (check-equal? (length (hash-ref obs-json 'captures)) 2)
  (check-equal? (length (hash-ref obs-json 'links)) 1)
  (define meta (hash-ref obs-json 'metadata))
  (check-equal? (hash-ref meta 'totalCaptures) 2)
  (check-equal? (hash-ref meta 'file) "test.prologos")
  ;; Subsystems deduped
  (define subsystems (hash-ref meta 'subsystems))
  (check-not-false (member "session" subsystems))
  (check-not-false (member "capability" subsystems)))

;; ========================================
;; 5. Round-trip: observatory → JSON string → parse
;; ========================================

(test-case "observatory->json-string: produces valid JSON"
  (define obs (make-observatory))
  (define-values (net ca cb) (make-quiesced-network))
  (observatory-register-capture! obs
    (net-capture 'cap-1 'session "s1" net champ-empty #f
                 'complete #f 100.0
                 (observatory-next-sequence! obs) #f))
  (define json-str (observatory->json-string obs))
  ;; Should be a valid JSON string
  (check-true (string? json-str))
  ;; Should parse back
  (define parsed (string->jsexpr json-str))
  (check-equal? (hash-ref parsed 'version) 2)
  (define obs-json (hash-ref parsed 'observatory))
  (check-equal? (length (hash-ref obs-json 'captures)) 1))

;; ========================================
;; 6. Capture with trace serializes BSP rounds
;; ========================================

(test-case "serialize-net-capture: with trace includes rounds"
  (define obs (make-observatory))
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 _pid)
    (net-add-propagator net2
      (list ca) (list cb)
      (lambda (n) (net-cell-write n cb (net-cell-read n ca)))))
  (define net4 (net-cell-write net3 ca 42))
  ;; Capture with tracing
  (parameterize ([current-observatory obs])
    (capture-network net4 'test "test" champ-empty #:trace? #t))
  (define cap (car (observatory-captures obs)))
  (define json (serialize-net-capture cap))
  (define trace-json (hash-ref json 'trace))
  (check-not-equal? trace-json (json-null))
  (check-true (hash? trace-json))
  ;; Should have rounds
  (define rounds (hash-ref trace-json 'rounds))
  (check-true (> (length rounds) 0)))
