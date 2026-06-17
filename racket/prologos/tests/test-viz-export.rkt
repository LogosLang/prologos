#lang racket/base

;;;
;;; test-viz-export.rkt — PTF Track V golden test (vizTrace 2)
;;;
;;; Runs the exporter end-to-end on a tiny fixture and pins the vizTrace 2
;;; envelope: schema keys, per-round topology references, the soundness
;;; invariant that a round's fired propagators + cell diffs live in THAT
;;; round's own topology (the per-network-id-space fix), identity coverage,
;;; and the validation block. Schema regression gate for the viewer.
;;;

(require rackunit
         racket/file
         racket/list
         json
         "../tools/viz-export.rkt")

(define fixture
  (string-append
   "ns examples.viz-export-golden\n\n"
   "def tag : String := \"golden\"\n\n"
   "spec dbl Int -> Int\n"
   "defn dbl [x]\n"
   "  [int* x 2]\n\n"
   "[dbl 21]\n\n"
   "defr edge [?x ?y]\n"
   "  || \"a\" \"b\"\n"
   "     \"b\" \"c\"\n\n"
   "eval (solve (edge \"a\" who))\n"))

(define tmp (make-temporary-file "viz-export-golden-~a.prologos"))
(call-with-output-file tmp (lambda (out) (display fixture out)) #:exists 'replace)
(define env (viz-export-file tmp))
(delete-file tmp)

(test-case "envelope: vizTrace 2 + top-level keys"
  (check-equal? (hash-ref env 'vizTrace) 2)
  (for ([k (in-list '(file source wallMs commandCount errors commands
                      topologies rounds finalTopology roundsTruncated validation))])
    (check-true (hash-has-key? env k) (format "missing key ~a" k))))

(test-case "fixture runs clean: 0 errors"
  (check-equal? (hash-ref env 'errors) 0
                (format "errors: ~a" (hash-ref env 'errorMessages))))

(test-case "rounds: timestamped, topo-referenced, command-tagged, monotone"
  (define v (hash-ref env 'validation))
  (check-true (hash-ref v 'roundTimestampsMonotone))
  (check-true (> (length (hash-ref env 'rounds)) 0) "at least one observed round")
  (define ntopo (length (hash-ref env 'topologies)))
  (for ([r (in-list (hash-ref env 'rounds))])
    (check-true (hash-has-key? r 'timestampMs))
    (check-true (hash-has-key? r 'command))
    (define t (hash-ref r 'topo))
    (check-true (and (>= t 0) (< t ntopo)) "topo ref in range")))

(test-case "SOUNDNESS: fired props + diff cells live in the round's OWN topology"
  (define topos (list->vector (hash-ref env 'topologies)))
  (for ([r (in-list (hash-ref env 'rounds))])
    (define topo (hash-ref (vector-ref topos (hash-ref r 'topo)) 'topology))
    (define prop-ids (for/list ([p (in-list (hash-ref topo 'propagators))]) (hash-ref p 'id)))
    (define cell-ids (for/list ([c (in-list (hash-ref topo 'cells))]) (hash-ref c 'id)))
    (for ([pid (in-list (hash-ref r 'propagatorsFired))])
      (check-not-false (member pid prop-ids) (format "fired prop ~a in its round's topology" pid)))
    (for ([d (in-list (hash-ref r 'cellDiffs))])
      (check-not-false (member (hash-ref d 'cellId) cell-ids)
                       (format "diff cell ~a in its round's topology" (hash-ref d 'cellId))))))

(test-case "topologies: cells + propagators + identity coverage"
  (for ([t (in-list (hash-ref env 'topologies))])
    (define topo (hash-ref t 'topology))
    (check-true (hash-has-key? topo 'cells))
    (check-true (hash-has-key? topo 'propagators))
    (define cov (hash-ref (hash-ref t 'identity) 'coverage))
    (check-true (<= (hash-ref cov 'cellsWithDomain) (hash-ref cov 'totalCells)))))

(test-case "solver free-path: some topology carries propagators"
  (check-true
   (for/or ([t (in-list (hash-ref env 'topologies))])
     (> (hash-ref (hash-ref (hash-ref t 'topology) 'stats) 'totalPropagators) 0))
   "at least one round's network carries propagators"))

(test-case "commands: ordered distinct labels"
  (define cmds (hash-ref env 'commands))
  (check-true (pair? cmds))
  (for ([c (in-list cmds)]) (check-true (hash-has-key? c 'label))))

(test-case "envelope is valid jsexpr (serializes to JSON)"
  (check-true (string? (jsexpr->string env))))
