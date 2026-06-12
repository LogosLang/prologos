#lang racket/base

;;;
;;; viz-capture-probe.rkt — PTF Track 2 Phase 0.5 empirical capture probe
;;;
;;; Runs a .prologos file with the BSP observer + observatory armed and reports
;;; the magnitudes a browser visualization must handle: topology size (cells,
;;; propagators, edge-bearing propagators), round count, diff volume, fired-
;;; propagator counts. Dumps trace JSON for inspection.
;;;
;;; This is the Phase 0.5 instrument behind the findings recorded in
;;; docs/tracking/2026-06-12_PTF_TRACK2_BROWSER_VIZ_DESIGN.md. Phase 2's
;;; tools/viz-export.rkt supersedes it as the production exporter.
;;;
;;; Usage: racket tools/viz-capture-probe.rkt FILE.prologos [OUT.json]
;;;

(require json
         racket/list
         "../driver.rkt"
         "../errors.rkt"
         "../propagator.rkt"
         "../prop-observatory.rkt"
         "../elaborator-network.rkt"
         "../trace-serialize.rkt")

(define args (current-command-line-arguments))
(when (zero? (vector-length args))
  (eprintf "usage: racket tools/viz-capture-probe.rkt FILE.prologos [OUT.json]\n")
  (exit 1))
(define src-path (vector-ref args 0))
(define out-path (if (> (vector-length args) 1) (vector-ref args 1) #f))

;; Arm the production capture surfaces (mirrors lsp/server.rkt:505-566, minus
;; the post-unwind net-box read defect: we capture the elab-network through
;; current-network-capture-box, which set-box!es per command INSIDE
;; process-file's parameterize — surviving the unwind).
(define-values (bsp-observe bsp-get-rounds) (make-trace-accumulator))
(define obs (make-observatory (hasheq 'file src-path)))
(define cap-box (box #f))

(define t0 (current-inexact-milliseconds))
(define results
  (parameterize ([current-bsp-observer bsp-observe]
                 [current-observatory obs]
                 [current-network-capture-box cap-box])
    (process-file src-path)))
(define t1 (current-inexact-milliseconds))

(define rounds (bsp-get-rounds))
(define enet (unbox cap-box))

(printf "=== viz-capture-probe: ~a ===\n" src-path)
(printf "wall: ~ams  commands: ~a  errors: ~a\n"
        (round (- t1 t0))
        (length results)
        (length (filter prologos-error? results)))

;; --- Topology from the last command's elab-network ---
(define topo
  (and enet
       (serialize-network-topology (elab-network-prop-net enet)
                                   (elab-network-cell-info enet))))
(cond
  [topo
   (define stats (hash-ref topo 'stats))
   (define props (hash-ref topo 'propagators))
   (define edge-bearing
     (filter (lambda (p) (and (pair? (hash-ref p 'inputs))
                              (pair? (hash-ref p 'outputs))))
             props))
   (define cells (hash-ref topo 'cells))
   (define by-subsystem
     (for/fold ([h (hash)]) ([c (in-list cells)])
       (hash-update h (hash-ref c 'subsystem) add1 0)))
   (printf "topology (last command's elab-network):\n")
   (printf "  cells: ~a  propagators: ~a  with-both-edges: ~a\n"
           (hash-ref stats 'totalCells)
           (hash-ref stats 'totalPropagators)
           (length edge-bearing))
   (printf "  cells by subsystem: ~a\n" by-subsystem)]
  [else
   (printf "topology: NO elab-network captured (cap-box empty)\n")])

;; --- Rounds (accumulated across ALL BSP runs under process-file, including
;;     module loading — the accumulator re-stamps round numbers globally) ---
(define total-diffs
  (for/sum ([r (in-list rounds)]) (length (bsp-round-cell-diffs r))))
(define total-fired
  (for/sum ([r (in-list rounds)]) (length (bsp-round-propagators-fired r))))
(printf "rounds: ~a  total cell-diffs: ~a  total fires: ~a\n"
        (length rounds) total-diffs total-fired)
(when (pair? rounds)
  (define last-r (last rounds))
  (define last-topo (serialize-network-topology
                     (bsp-round-network-snapshot last-r)))
  (define ls (hash-ref last-topo 'stats))
  (printf "last round's snapshot network: cells ~a, propagators ~a\n"
          (hash-ref ls 'totalCells) (hash-ref ls 'totalPropagators)))

;; --- Observatory captures ---
(define caps (observatory-captures obs))
(printf "observatory captures: ~a\n" (length caps))

;; --- JSON dump (summary-only above 50k diffs to avoid multi-MB artifacts) ---
(when out-path
  (define payload
    (hasheq 'topology (or topo (json-null))
            'rounds (if (<= total-diffs 50000)
                        (map serialize-bsp-round rounds)
                        (for/list ([r (in-list rounds)])
                          (hasheq 'roundNumber (bsp-round-round-number r)
                                  'diffCount (length (bsp-round-cell-diffs r))
                                  'firedCount (length (bsp-round-propagators-fired r)))))
            'metadata (hasheq 'file src-path
                              'wallMs (- t1 t0)
                              'roundsTruncated (> total-diffs 50000))))
  (call-with-output-file out-path
    (lambda (out) (write-json payload out))
    #:exists 'replace)
  (printf "JSON written: ~a (~a bytes)\n" out-path (file-size out-path)))
