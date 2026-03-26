#lang racket/base

;;;
;;; Tests for PPN Track 1: Propagator-Based Reader
;;;

(require rackunit
         racket/set
         "../rrb.rkt"
         "../propagator.rkt"
         "../parse-lattice.rkt"
         "../parse-reader.rkt")

;; ============================================================
;; Phase 1a: Character RRB
;; ============================================================

(test-case "char-rrb: build from simple string"
  (define rrb (make-char-rrb-from-string "hello"))
  (check-equal? (rrb-size rrb) 5)
  (check-equal? (rrb-get rrb 0) #\h)
  (check-equal? (rrb-get rrb 4) #\o))

(test-case "char-rrb: handles newlines"
  (define rrb (make-char-rrb-from-string "a\nb\nc"))
  (check-equal? (rrb-size rrb) 5)
  (check-equal? (rrb-get rrb 0) #\a)
  (check-equal? (rrb-get rrb 1) #\newline)
  (check-equal? (rrb-get rrb 2) #\b))

(test-case "char-rrb: empty string"
  (define rrb (make-char-rrb-from-string ""))
  (check-equal? (rrb-size rrb) 0))

(test-case "char-rrb: unicode characters"
  (define rrb (make-char-rrb-from-string "café"))
  (check-equal? (rrb-size rrb) 4)
  (check-equal? (rrb-get rrb 3) #\é))


;; ============================================================
;; Phase 1a: Content line classification
;; ============================================================

(test-case "content-line?: regular code"
  (check-true (content-line? "def x := 42"))
  (check-true (content-line? "  [f x y]"))
  (check-true (content-line? "spec foo Int -> Int")))

(test-case "content-line?: blank line"
  (check-false (content-line? ""))
  (check-false (content-line? "   "))
  (check-false (content-line? "\t  ")))

(test-case "content-line?: comment-only"
  (check-false (content-line? ";; this is a comment"))
  (check-false (content-line? "  ;; indented comment")))

(test-case "content-line?: code with trailing comment"
  ;; Line has content before the comment — it IS a content line
  (check-true (content-line? "def x := 42 ;; inline comment")))


;; ============================================================
;; Phase 1a: Indent measurement
;; ============================================================

(test-case "measure-indent: no indent"
  (check-equal? (measure-indent "def x := 42") 0))

(test-case "measure-indent: 2 spaces"
  (check-equal? (measure-indent "  where") 2))

(test-case "measure-indent: 4 spaces"
  (check-equal? (measure-indent "    [Eq x]") 4))

(test-case "measure-indent: empty string"
  (check-equal? (measure-indent "") 0))


;; ============================================================
;; Phase 1a: Indent RRB from character RRB
;; ============================================================

(test-case "indent-rrb: simple multi-line"
  (define char-rrb (make-char-rrb-from-string
    "def x := 42\n  where\n    [Eq x]\n"))
  (define-values (indent-rrb line-indices) (make-indent-rrb-from-char-rrb char-rrb))
  ;; 3 content lines: "def x := 42" (indent 0), "  where" (indent 2), "    [Eq x]" (indent 4)
  (check-equal? (rrb-size indent-rrb) 3)
  (check-equal? (rrb-get indent-rrb 0) 0)
  (check-equal? (rrb-get indent-rrb 1) 2)
  (check-equal? (rrb-get indent-rrb 2) 4)
  ;; Source line indices: 0, 1, 2
  (check-equal? (rrb-size line-indices) 3)
  (check-equal? (rrb-get line-indices 0) 0)
  (check-equal? (rrb-get line-indices 1) 1)
  (check-equal? (rrb-get line-indices 2) 2))

(test-case "indent-rrb: skips blank lines"
  (define char-rrb (make-char-rrb-from-string
    "def x := 42\n\n  where\n\n    [Eq x]\n"))
  (define-values (indent-rrb line-indices) (make-indent-rrb-from-char-rrb char-rrb))
  ;; Same 3 content lines, blank lines skipped
  (check-equal? (rrb-size indent-rrb) 3)
  (check-equal? (rrb-get indent-rrb 0) 0)
  (check-equal? (rrb-get indent-rrb 1) 2)
  (check-equal? (rrb-get indent-rrb 2) 4)
  ;; Source line indices: 0, 2, 4 (blanks at 1 and 3 skipped)
  (check-equal? (rrb-get line-indices 0) 0)
  (check-equal? (rrb-get line-indices 1) 2)
  (check-equal? (rrb-get line-indices 2) 4))

(test-case "indent-rrb: skips comment-only lines"
  (define char-rrb (make-char-rrb-from-string
    ";; header comment\ndef x := 42\n;; mid comment\n  where\n"))
  (define-values (indent-rrb line-indices) (make-indent-rrb-from-char-rrb char-rrb))
  ;; 2 content lines: "def x := 42" (indent 0), "  where" (indent 2)
  (check-equal? (rrb-size indent-rrb) 2)
  (check-equal? (rrb-get indent-rrb 0) 0)
  (check-equal? (rrb-get indent-rrb 1) 2))

(test-case "indent-rrb: no trailing newline"
  (define char-rrb (make-char-rrb-from-string "def x := 42"))
  (define-values (indent-rrb line-indices) (make-indent-rrb-from-char-rrb char-rrb))
  (check-equal? (rrb-size indent-rrb) 1)
  (check-equal? (rrb-get indent-rrb 0) 0))


;; ============================================================
;; Phase 1a: Parse cells on propagator network
;; ============================================================

(test-case "create-parse-cells: 5 cells on network"
  (define net0 (make-prop-network))
  (define-values (net1 cells) (create-parse-cells net0))
  ;; All 5 cell IDs are distinct
  (define ids (list (parse-cells-char-cell-id cells)
                    (parse-cells-indent-cell-id cells)
                    (parse-cells-token-cell-id cells)
                    (parse-cells-bracket-cell-id cells)
                    (parse-cells-tree-cell-id cells)))
  (check-equal? (set-count (list->seteq ids)) 5))

(test-case "parse-cells: write char RRB to char cell"
  (define net0 (make-prop-network))
  (define-values (net1 cells) (create-parse-cells net0))
  (define char-rrb (make-char-rrb-from-string "hello"))
  (define net2 (net-cell-write net1 (parse-cells-char-cell-id cells) char-rrb))
  (define val (net-cell-read net2 (parse-cells-char-cell-id cells)))
  (check-equal? (rrb-size val) 5)
  (check-equal? (rrb-get val 0) #\h))

(test-case "parse-cells: write indent RRB to indent cell"
  (define net0 (make-prop-network))
  (define-values (net1 cells) (create-parse-cells net0))
  (define char-rrb (make-char-rrb-from-string "def x\n  where\n"))
  (define-values (indent-rrb _) (make-indent-rrb-from-char-rrb char-rrb))
  (define net2 (net-cell-write net1 (parse-cells-indent-cell-id cells) indent-rrb))
  (define val (net-cell-read net2 (parse-cells-indent-cell-id cells)))
  (check-equal? (rrb-size val) 2)
  (check-equal? (rrb-get val 0) 0)
  (check-equal? (rrb-get val 1) 2))

(test-case "parse-cells: RRB merge — bot + value = value"
  (define net0 (make-prop-network))
  (define-values (net1 cells) (create-parse-cells net0))
  ;; Cell starts at bot (rrb-empty)
  (define val0 (net-cell-read net1 (parse-cells-char-cell-id cells)))
  (check-true (rrb-empty? val0))
  ;; Write value
  (define char-rrb (make-char-rrb-from-string "x"))
  (define net2 (net-cell-write net1 (parse-cells-char-cell-id cells) char-rrb))
  (define val1 (net-cell-read net2 (parse-cells-char-cell-id cells)))
  (check-equal? (rrb-size val1) 1))

(test-case "parse-cells: tree cell starts at parse-bot"
  (define net0 (make-prop-network))
  (define-values (net1 cells) (create-parse-cells net0))
  (define val (net-cell-read net1 (parse-cells-tree-cell-id cells)))
  (check-true (parse-bot? val)))
