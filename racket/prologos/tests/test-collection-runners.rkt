#lang racket/base

;;; test-collection-runners.rkt — the `into-*` runners are reachable and work.
;;;
;;; DEFERRED (Collections, "Stage I: Transducer Runners for Non-List") listed
;;; `into-vec` / `into-set` as work to be done, "blocked on transient types not
;;; exposed at Prologos type level".
;;;
;;; They exist and are importable from `prologos::core::collections` — a real
;;; module with an `ns` — and have since commit 7c04a89f. What is blocked is the
;;; transducer-PROTOCOL form of them and pipe fusion, not the runners.
;;;
;;; I got this wrong once already this session: a first probe imported them from
;;; `prologos::book::collection-functions`, which is a chapter file with no `ns`
;;; and therefore not importable, and I concluded from that failure that the
;;; functions were unreachable. They were reachable from the other module all
;;; along. Hence this file: the claim is now pinned rather than re-derived.

(require rackunit
         racket/string
         "test-support.rkt"
         "../errors.rkt")

(define pre
  (string-append
   "ns cr\n"
   "require [prologos::core::collections :refer [into-vec into-list]]\n"
   "require [prologos::data::lseq-ops :refer [list-to-lseq]]\n"
   "require [prologos::data::list :refer [List nil cons]]\n"
   "def xs := [cons 1 [cons 2 [cons 3 nil]]]\n"))

(define (run s) (run-ns-ws-last (string-append pre s)))

(test-case "collections/into-vec turns a lazy sequence into a PVec"
  (define r (run "[into-vec [list-to-lseq Int xs]]\n"))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (define text (format "~a" r))
  (check-true (string-contains? text "PVec") (format "not a PVec: ~v" r))
  ;; Contents, not just the type — a runner that produced an EMPTY PVec would
  ;; satisfy the type check.
  (check-true (string-contains? text "1") (format "got: ~v" r))
  (check-true (string-contains? text "3") (format "got: ~v" r)))

(test-case "collections/into-list round-trips"
  (define r (run "[into-list [list-to-lseq Int xs]]\n"))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (check-true (string-contains? (format "~a" r) "1 2 3") (format "got: ~v" r)))
