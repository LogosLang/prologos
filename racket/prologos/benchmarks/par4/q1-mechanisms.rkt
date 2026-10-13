#lang racket/base
;; PAR 4 P0 — Q1 audit, MECHANISM probes (turn the static audit's judgements into measurements).
;;
;;   M3  undeclared writes are applied by direct set (bypass the merge) → lost update in ONE BSP
;;       round when two propagators write the same cell undeclared. (audit §1 M3, §7.1)
;;   G   the relational guard's shape: AND-NOT read-modify-write on an LWW cell (cell-1 merge is
;;       replacement). Does DECLARING the output fix it (the audit's follow-up #1)? Or is the
;;       lattice the problem? Compare with the "invalidated-bits grows by ior" lattice.
;;   M4  a fire-once propagator installed INSIDE a fire is re-installed by the BSP scheduler from
;;       (inputs outputs fire-fn) only — does it lose PROP-FIRE-ONCE? (audit §1 M4)
;;
;; Run: racket benchmarks/par4/q1-mechanisms.rkt     (prints one line per row)
(require "../../propagator.rkt")

(define (run net bsp?)
  (parameterize ([current-use-bsp-scheduler? bsp?]) (run-to-quiescence net)))

;; Two writers of cell C, both triggered by the same source S (so they fire in the SAME round).
;;   declared?  : are C's writes declared outputs?
;;   merge      : C's merge
;;   init       : C's initial value
;;   step       : (old-C writer-index) -> new C value the writer computes (read-modify-write)
(define (two-writers declared? merge init step bsp?)
  (define net0 (make-prop-network 100000))
  (define-values (net1 s) (net-new-cell net0 0 (λ (a b) (max a b))))
  (define-values (net2 c) (net-new-cell net1 init merge))
  (define (writer i)
    (λ (n) (if (zero? (net-cell-read n s)) n
               (net-cell-write n c (step (net-cell-read n c) i)))))
  (define-values (net3 _p1) (net-add-propagator net2 (list s) (if declared? (list c) '()) (writer 1)))
  (define-values (net4 _p2) (net-add-propagator net3 (list s) (if declared? (list c) '()) (writer 2)))
  (net-cell-read (run (net-cell-write net4 s 1) bsp?) c))

(define (row label declared? merge init step expect)
  (define b (two-writers declared? merge init step #t))
  (define q (two-writers declared? merge init step #f))
  (printf "~a  BSP=~a  SEQ=~a  expected(both updates)=~a  ~a\n" label b q expect
          (cond [(and (equal? b expect) (equal? q expect)) "OK"]
                [(equal? q expect) "LOST UPDATE under BSP"]
                [(equal? b expect) "LOST UPDATE under SEQ"]
                [else "LOST UPDATE under both"])))

(define ior-merge (λ (a b) (bitwise-ior a b)))
(define lww-merge (λ (old new) (if (= old new) old new)))      ; = worldview-cache-merge
(define set-bit (λ (old i) (bitwise-ior old (arithmetic-shift 1 i))))
(define clear-bit (λ (old i) (bitwise-and old (bitwise-not (arithmetic-shift 1 i)))))

(printf "== M3: two writers, ior-merge cell, read-modify-write (set own bit)\n")
(row "  undeclared outputs, ior merge          " #f ior-merge 0 set-bit 6)
(row "  declared outputs,   ior merge          " #t ior-merge 0 set-bit 6)
(printf "== G: the guard shape — clear own bit of a worldview (bits 1,2 set = 6)\n")
(row "  undeclared, LWW merge (as relations.rkt:2353)" #f lww-merge 6 clear-bit 0)
(row "  DECLARED,   LWW merge (audit follow-up #1)   " #t lww-merge 6 clear-bit 0)
(printf "== G': the lattice fix — an INVALIDATED-bits cell that only grows (ior); worldview = committed AND NOT invalidated\n")
(row "  declared,   ior merge on invalidated bits     " #t ior-merge 0 set-bit 6)

;; ---- M4: fire-once installed inside a fire ----
(define (m4 inside? bsp?)
  (define fires (box 0))
  (define installs (box 0))
  (define net0 (make-prop-network 100000))
  (define-values (net1 s) (net-new-cell net0 0 (λ (a b) (max a b))))
  (define-values (net2 t) (net-new-cell net1 0 (λ (a b) (max a b))))
  (define-values (net3 c) (net-new-cell net2 0 (λ (a b) (max a b))))
  (define (inner-fire n) (set-box! fires (add1 (unbox fires)))
                         (net-cell-write n c (net-cell-read n t)))
  (define (install n)
    (set-box! installs (add1 (unbox installs)))
    (define-values (n* _p) (net-add-fire-once-propagator n (list t) (list c) inner-fire)) n*)
  (define net4
    (if inside?
        (let-values ([(n _p) (net-add-propagator net3 (list s) '()
                                                 (λ (n) (if (zero? (net-cell-read n s)) n (install n))))])
          n)
        (install net3)))
  ;; trigger install (if inside), then raise T three times, quiescing between.
  (define n1 (run (net-cell-write net4 s 1) bsp?))
  (define n2 (run (net-cell-write n1 t 1) bsp?))
  (define n3 (run (net-cell-write n2 t 2) bsp?))
  (define n4 (run (net-cell-write n3 t 3) bsp?))
  (list 'fires (unbox fires) 'C (net-cell-read n4 c) 'installs (unbox installs)))

(printf "== M4: a fire-once propagator, T raised 1→2→3 (fire-once ⇒ 1 productive fire, C stays 1)\n")
(printf "  installed at top level   BSP ~a  SEQ ~a\n" (m4 #f #t) (m4 #f #f))
(printf "  installed INSIDE a fire  BSP ~a  SEQ ~a\n" (m4 #t #t) (m4 #t #f))
