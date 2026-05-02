#lang racket/base

;;;
;;; Tests for PVec Int-indexed helpers (eigentrust pitfalls doc #12)
;;;
;;; Covers the pvec-nth-int / pvec-length-int / pvec-take-int /
;;; pvec-drop-int quartet that mirrors the List Int-indexed helpers.
;;; See racket/prologos/lib/prologos/core/pvec.prologos for the
;;; implementation.
;;;
;;; All test cases use Int indices/lengths so an algorithm written
;;; against a budget compared via int-le doesn't have to maintain a
;;; parallel Nat counter just to index a PVec.
;;;

(require racket/string
         rackunit
         "test-support.rkt")

(define (run s) (run-ns-last s))

;; ========================================
;; pvec-length-int : PVec A → Int
;; ========================================

(test-case "pvec-length-int: empty pvec returns 0"
  (let ([result (run "(ns pvec-int-len-1)\n(eval (pvec-length-int (pvec-empty Nat)))")])
    (check-true (string-contains? result "0 : Int"))))

(test-case "pvec-length-int: singleton returns 1"
  (let ([result (run "(ns pvec-int-len-2)\n(eval (pvec-length-int (pvec-push (pvec-empty Nat) zero)))")])
    (check-true (string-contains? result "1 : Int"))))

(test-case "pvec-length-int: two elements returns 2"
  (let ([result (run "(ns pvec-int-len-3)\n(eval (pvec-length-int (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero))))")])
    (check-true (string-contains? result "2 : Int"))))

;; ========================================
;; pvec-nth-int : PVec A → Int → Option A
;; ========================================

(test-case "pvec-nth-int: index 0 of singleton"
  ;; vec [zero], index 0 → some 0N
  (let ([result (run "(ns pvec-int-nth-1)\n(eval (pvec-nth-int (pvec-push (pvec-empty Nat) zero) 0))")])
    (check-true (string-contains? result "0N"))))

(test-case "pvec-nth-int: index 1 of two-element vec"
  ;; vec [zero, suc zero], index 1 → some 1N
  (let ([result (run "(ns pvec-int-nth-2)\n(eval (pvec-nth-int (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero)) 1))")])
    (check-true (string-contains? result "1N"))))

(test-case "pvec-nth-int: last index of three-element vec"
  ;; vec [zero, suc zero, suc (suc zero)], index 2 → some 2N
  (let ([result (run "(ns pvec-int-nth-3)\n(eval (pvec-nth-int (pvec-push (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero)) (suc (suc zero))) 2))")])
    (check-true (string-contains? result "2N"))))

(test-case "pvec-nth-int: negative index returns none (mirrors List nth-int)"
  ;; vec [zero], index -1 → none
  (let ([result (run "(ns pvec-int-nth-4)\n(eval (pvec-nth-int (pvec-push (pvec-empty Nat) zero) (int-neg 1)))")])
    (check-true (string-contains? result "none"))))

(test-case "pvec-nth-int: out-of-bounds index returns none"
  ;; vec [zero], index 5 → none
  (let ([result (run "(ns pvec-int-nth-5)\n(eval (pvec-nth-int (pvec-push (pvec-empty Nat) zero) 5))")])
    (check-true (string-contains? result "none"))))

(test-case "pvec-nth-int: empty pvec at index 0 returns none"
  (let ([result (run "(ns pvec-int-nth-6)\n(eval (pvec-nth-int (pvec-empty Nat) 0))")])
    (check-true (string-contains? result "none"))))

;; ========================================
;; pvec-take-int : Int → PVec A → PVec A
;; ========================================

(test-case "pvec-take-int: take 1 from two-element vec yields length 1"
  ;; take 1 from [zero, suc zero] → length 1
  (let ([result (run "(ns pvec-int-take-1)\n(eval (pvec-length-int (pvec-take-int 1 (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero)))))")])
    (check-true (string-contains? result "1 : Int"))))

(test-case "pvec-take-int: take 0 yields empty vec"
  (let ([result (run "(ns pvec-int-take-2)\n(eval (pvec-length-int (pvec-take-int 0 (pvec-push (pvec-empty Nat) zero))))")])
    (check-true (string-contains? result "0 : Int"))))

(test-case "pvec-take-int: take negative yields empty vec (mirrors List take-int)"
  (let ([result (run "(ns pvec-int-take-3)\n(eval (pvec-length-int (pvec-take-int (int-neg 5) (pvec-push (pvec-empty Nat) zero))))")])
    (check-true (string-contains? result "0 : Int"))))

(test-case "pvec-take-int: take more than length yields whole vec"
  ;; take 100 from a 2-element vec → length 2
  (let ([result (run "(ns pvec-int-take-4)\n(eval (pvec-length-int (pvec-take-int 100 (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero)))))")])
    (check-true (string-contains? result "2 : Int"))))

;; ========================================
;; pvec-drop-int : Int → PVec A → PVec A
;; ========================================

(test-case "pvec-drop-int: drop 1 from two-element vec yields length 1"
  ;; drop 1 from [zero, suc zero] → length 1
  (let ([result (run "(ns pvec-int-drop-1)\n(eval (pvec-length-int (pvec-drop-int 1 (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero)))))")])
    (check-true (string-contains? result "1 : Int"))))

(test-case "pvec-drop-int: drop 0 returns vec unchanged"
  (let ([result (run "(ns pvec-int-drop-2)\n(eval (pvec-length-int (pvec-drop-int 0 (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero)))))")])
    (check-true (string-contains? result "2 : Int"))))

(test-case "pvec-drop-int: drop negative returns vec unchanged (mirrors List drop-int)"
  (let ([result (run "(ns pvec-int-drop-3)\n(eval (pvec-length-int (pvec-drop-int (int-neg 5) (pvec-push (pvec-empty Nat) zero))))")])
    (check-true (string-contains? result "1 : Int"))))

(test-case "pvec-drop-int: drop more than length yields empty vec"
  (let ([result (run "(ns pvec-int-drop-4)\n(eval (pvec-length-int (pvec-drop-int 100 (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero)))))")])
    (check-true (string-contains? result "0 : Int"))))

;; ========================================
;; Round-trip property: take + drop reconstruct length
;; ========================================

(test-case "pvec-take-int + pvec-drop-int: lengths sum to original"
  ;; |take 1 v| + |drop 1 v| = |v| for a 3-element vec
  (let ([take-len (run "(ns pvec-int-rt-1)\n(eval (pvec-length-int (pvec-take-int 1 (pvec-push (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero)) (suc (suc zero))))))")]
        [drop-len (run "(ns pvec-int-rt-2)\n(eval (pvec-length-int (pvec-drop-int 1 (pvec-push (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero)) (suc (suc zero))))))")])
    (check-true (string-contains? take-len "1 : Int"))
    (check-true (string-contains? drop-len "2 : Int"))))
