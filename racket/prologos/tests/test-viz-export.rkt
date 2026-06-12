#lang racket/base

;;;
;;; test-viz-export.rkt — PTF Track 2 Phase 2c golden test
;;;
;;; Runs the exporter end-to-end on a tiny fixture and pins the vizTrace 1
;;; envelope: schema keys, capture/command parity, epoch-bucketed timestamped
;;; rounds, identity coverage stats (D4), bounded value detail (D7), and the
;;; validation block. Schema regression gate for the Phase 3 viewer.
;;;

(require rackunit
         racket/file
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

(test-case "envelope: version + top-level keys"
  (check-equal? (hash-ref env 'vizTrace) 1)
  (for ([k (in-list '(file wallMs commands errors captures finalTopology
                      epochs rounds roundsTruncated validation))])
    (check-true (hash-has-key? env k) (format "missing key ~a" k))))

(test-case "fixture runs clean: 0 errors, captures == commands"
  (check-equal? (hash-ref env 'errors) 0
                (format "errors: ~a" (hash-ref env 'errorMessages)))
  (define v (hash-ref env 'validation))
  (check-true (hash-ref v 'capturesMatchCommands))
  (check-true (> (hash-ref env 'commands) 0)))

(test-case "rounds: timestamped, epoch-tagged, monotone"
  (define v (hash-ref env 'validation))
  (check-true (hash-ref v 'roundTimestampsMonotone))
  (check-true (> (hash-ref v 'roundsTotal) 0) "at least one observed round")
  (for ([r (in-list (hash-ref env 'rounds))])
    (check-true (hash-has-key? r 'timestampMs))
    (check-true (hash-has-key? r 'epoch))))

(test-case "captures: topology + identity sections with coverage stats"
  (define caps (hash-ref env 'captures))
  (check-true (pair? caps))
  (for ([c (in-list caps)])
    (define topo (hash-ref c 'topology))
    (check-true (hash-has-key? topo 'cells))
    (check-true (hash-has-key? topo 'propagators))
    (define cov (hash-ref (hash-ref c 'identity) 'coverage))
    (check-true (<= (hash-ref cov 'cellsWithDomain)
                    (hash-ref cov 'totalCells)))))

(test-case "epochs: solver free-path — some epoch has propagators"
  (define epochs (hash-ref env 'epochs))
  (check-true (pair? epochs))
  (check-true
   (for/or ([e (in-list epochs)])
     (> (hash-ref (hash-ref (hash-ref e 'topology) 'stats) 'totalPropagators) 0))
   "at least one epoch's last-snapshot network carries propagators"))

(test-case "value detail (D7): bounded key lists"
  (for ([c (in-list (hash-ref env 'captures))])
    (for ([(_ d) (in-hash (hash-ref c 'valueDetail))])
      (check-true (<= (length (hash-ref d 'keys)) 8)))))

(test-case "envelope is valid jsexpr (serializes to JSON)"
  (check-true (string? (jsexpr->string env))))
